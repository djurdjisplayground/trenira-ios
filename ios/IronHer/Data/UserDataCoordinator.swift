import Foundation

/// Owns guest→account migration, active ownership, and store snapshot apply/capture.
@MainActor
@Observable
final class UserDataCoordinator {
    private(set) var currentOwner: DataOwnerID
    private(set) var syncStatus: SyncStatus = .localOnly
    private(set) var lastMigrationMessage: String?
    private(set) var didShowFirstWorkoutBackupHint = false
    private(set) var conflictFlags: [String] = []

    private let workoutStore: WorkoutStore
    private let historyStore: WeightHistoryStore
    private let sessionStore: WorkoutSessionStore
    private let customExerciseStore: CustomExerciseStore
    private let progressionStore: ExerciseProgressionStore
    private let globalProgressStore: GlobalExerciseProgressStore
    private let settingsStore: UserSettingsStore
    private let syncEngine: SyncEngine

    private let firstWorkoutHintKey = "trenira.didShowFirstWorkoutBackupHint"
    private let tombstonesKey = "trenira.dataTombstones"

    init(
        workoutStore: WorkoutStore,
        historyStore: WeightHistoryStore,
        sessionStore: WorkoutSessionStore,
        customExerciseStore: CustomExerciseStore,
        progressionStore: ExerciseProgressionStore,
        globalProgressStore: GlobalExerciseProgressStore,
        settingsStore: UserSettingsStore,
        syncEngine: SyncEngine? = nil
    ) {
        self.workoutStore = workoutStore
        self.historyStore = historyStore
        self.sessionStore = sessionStore
        self.customExerciseStore = customExerciseStore
        self.progressionStore = progressionStore
        self.globalProgressStore = globalProgressStore
        self.settingsStore = settingsStore
        self.syncEngine = syncEngine ?? SyncEngine()

        let guest = DataOwnerID.guest(GuestIdentityStore.localGuestID())
        if let active = AccountDataVault.activeOwnerId {
            currentOwner = DataOwnerID(rawValue: active)
        } else if let detached = AccountDataVault.detachedAccountOwnerId {
            currentOwner = DataOwnerID(rawValue: detached)
        } else {
            currentOwner = guest
        }

        didShowFirstWorkoutBackupHint = UserDefaults.standard.bool(forKey: firstWorkoutHintKey)
        wireOwnershipProviders()
        ensureLegacyRecordsOwned()
        syncStatus = currentOwner.isGuest ? .localOnly : self.syncEngine.status
    }

    var ownershipRawValue: String { currentOwner.rawValue }

    func bootstrap(authState: AuthState) {
        let guestID = GuestIdentityStore.localGuestID()
        if let owner = authState.dataOwnerID(guestID: guestID) {
            if owner.isAccount {
                AccountDataVault.detachedAccountOwnerId = nil
            }
            currentOwner = owner
            AccountDataVault.activeOwnerId = owner.rawValue
            wireOwnershipProviders()
            ensureLegacyRecordsOwned()
            if owner.isGuest {
                syncEngine.setGuestLocalOnly()
                syncStatus = .localOnly
            }
        }
    }

    // MARK: - Auth transitions

    /// Guest (or detached) → authenticated account. Idempotent; never drops local workouts.
    func handleAuthenticatedSignIn(authState: AuthState) async {
        let guestID = GuestIdentityStore.localGuestID()
        guard let accountOwner = authState.dataOwnerID(guestID: guestID), accountOwner.isAccount else {
            return
        }

        #if DEBUG
        _ = try? LocalPersistenceBackup.exportToDocuments(label: "pre-signin-migration")
        #endif

        let previousOwner = currentOwner
        let localSnapshot = captureSnapshot(ownerId: previousOwner.rawValue)

        // Different user signing in on this device: swap to their vault; do not merge previous private data.
        if let detached = AccountDataVault.detachedAccountOwnerId,
           detached != accountOwner.rawValue,
           previousOwner.rawValue == detached {
            try? AccountDataVault.save(localSnapshot)
            if let other = AccountDataVault.load(ownerId: accountOwner.rawValue) {
                applySnapshot(other)
            } else {
                applySnapshot(.empty(ownerId: accountOwner.rawValue))
            }
            AccountDataVault.detachedAccountOwnerId = nil
            currentOwner = accountOwner
            AccountDataVault.activeOwnerId = accountOwner.rawValue
            wireOwnershipProviders()
            await pushSync(allowDownloadMerge: true)
            lastMigrationMessage = "Signed in. Your account data is ready on this device."
            return
        }

        let migrationAlreadyDone = AccountDataVault.hasCompletedMigration(
            from: previousOwner.rawValue,
            to: accountOwner.rawValue
        )

        var accountSnapshot = AccountDataVault.load(ownerId: accountOwner.rawValue)
            ?? UserDataSnapshot.empty(ownerId: accountOwner.rawValue)

        // Pull remote (mirror / future cloud) without allowing empty remote to wipe local.
        let pulled = await syncEngine.sync(
            snapshot: accountSnapshot.isEffectivelyEmpty ? localSnapshot : accountSnapshot,
            allowDownloadMerge: true
        )
        if !pulled.isEffectivelyEmpty {
            accountSnapshot = pulled
        }

        let merged: UserDataMergeEngine.Result
        if migrationAlreadyDone {
            // Second run: merge current local (already owned by account) with vault/remote only.
            let current = captureSnapshot(ownerId: accountOwner.rawValue)
            merged = UserDataMergeEngine.merge(
                local: current,
                remote: accountSnapshot,
                resultingOwnerId: accountOwner.rawValue
            )
        } else if previousOwner.isGuest || previousOwner.rawValue != accountOwner.rawValue {
            merged = UserDataMergeEngine.merge(
                local: localSnapshot,
                remote: accountSnapshot,
                resultingOwnerId: accountOwner.rawValue
            )
        } else {
            merged = UserDataMergeEngine.merge(
                local: localSnapshot,
                remote: accountSnapshot,
                resultingOwnerId: accountOwner.rawValue
            )
        }

        conflictFlags = merged.conflictFlags
        let owned = UserDataMergeEngine.transferOwnership(merged.snapshot, to: accountOwner.rawValue)
        applySnapshot(owned)
        try? AccountDataVault.save(owned)

        let uploaded = await syncEngine.sync(snapshot: owned, allowDownloadMerge: false)
        if case .failed = syncEngine.status {
            syncStatus = syncEngine.status
            // Keep guest ownership until upload verifies — but UI still shows merged data.
            // Re-apply account ownership only after successful upload when migrating from guest.
            if !previousOwner.isGuest {
                currentOwner = accountOwner
                AccountDataVault.activeOwnerId = accountOwner.rawValue
            }
        } else {
            applySnapshot(uploaded)
            try? AccountDataVault.save(uploaded)
            currentOwner = accountOwner
            AccountDataVault.activeOwnerId = accountOwner.rawValue
            AccountDataVault.markMigrationCompleted(
                from: previousOwner.rawValue,
                to: accountOwner.rawValue
            )
            AccountDataVault.detachedAccountOwnerId = nil
            wireOwnershipProviders()
            ensureLegacyRecordsOwned()
            syncStatus = syncEngine.status
            lastMigrationMessage = "Your workouts and progress are now backed up."
        }
        wireOwnershipProviders()
    }

    /// Sign-out: sync if possible, keep data visible, detach ownership from future guest merges.
    func prepareForSignOut() async {
        guard currentOwner.isAccount else { return }
        let snapshot = captureSnapshot(ownerId: currentOwner.rawValue)
        try? AccountDataVault.save(snapshot)
        _ = await syncEngine.sync(snapshot: snapshot, allowDownloadMerge: false)
        AccountDataVault.detachedAccountOwnerId = currentOwner.rawValue
        AccountDataVault.activeOwnerId = currentOwner.rawValue
        syncStatus = syncEngine.status
        // Data remains in live stores — never cleared.
    }

    func handleContinueAsGuest() {
        // If detached account data is on screen, keep it (preferred MVP) but do not start a new guest workspace merge.
        if let detached = AccountDataVault.detachedAccountOwnerId {
            currentOwner = DataOwnerID(rawValue: detached)
            AccountDataVault.activeOwnerId = detached
            syncStatus = .localOnly
            wireOwnershipProviders()
            return
        }
        let guest = DataOwnerID.guest(GuestIdentityStore.localGuestID())
        currentOwner = guest
        AccountDataVault.activeOwnerId = guest.rawValue
        syncEngine.setGuestLocalOnly()
        syncStatus = .localOnly
        wireOwnershipProviders()
        ensureLegacyRecordsOwned()
    }

    private var pendingSyncTask: Task<Void, Never>?

    // MARK: - Mutation hooks

    func noteLocalMutation() {
        syncEngine.markLocalChange()
        guard currentOwner.isAccount else { return }
        // Debounce — drafting / editing must not encode+upload the full database on every change.
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            syncStatus = .backingUp
            _ = await pushSync(allowDownloadMerge: false)
        }
    }

    func noteWorkoutCreated() {
        maybeShowFirstWorkoutHint()
    }

    func retrySync() async {
        _ = await pushSync(allowDownloadMerge: true)
    }

    func syncOnLaunchOrActive(authState: AuthState) async {
        guard case .apple = authState else {
            if case .google = authState {
                await pushSync(allowDownloadMerge: true)
            } else if case .email = authState {
                await pushSync(allowDownloadMerge: true)
            }
            return
        }
        await pushSync(allowDownloadMerge: true)
    }

    func recordTombstone(id: UUID, entityType: String) {
        var stones = loadTombstones()
        stones.removeAll { $0.id == id }
        stones.append(
            DataTombstone(id: id, entityType: entityType, ownerId: currentOwner.rawValue)
        )
        saveTombstones(stones)
        noteLocalMutation()
    }

    func clearMigrationMessage() {
        lastMigrationMessage = nil
    }

    // MARK: - Snapshot

    func captureSnapshot(ownerId: String) -> UserDataSnapshot {
        UserDataSnapshot(
            schemaVersion: UserDataSnapshot.currentSchemaVersion,
            ownerId: ownerId,
            updatedAt: .now,
            workouts: workoutStore.allRecordsForSync(),
            weightHistory: historyStore.entries,
            weeklyCompletions: sessionStore.weeklyCompletions,
            performanceLogs: sessionStore.performanceLogs,
            customExercises: customExerciseStore.exercises,
            tombstones: loadTombstones(),
            progressionBlob: progressionStore.exportSyncBlob(),
            globalProgressBlob: globalProgressStore.exportSyncBlob(),
            userSettingsBlob: settingsStore.exportSyncBlob()
        )
    }

    func applySnapshot(_ snapshot: UserDataSnapshot) {
        workoutStore.replaceAllForSync(snapshot.workouts)
        historyStore.replaceAllForSync(snapshot.weightHistory)
        sessionStore.replaceAllForSync(
            weeklyCompletions: snapshot.weeklyCompletions,
            performanceLogs: snapshot.performanceLogs
        )
        customExerciseStore.replaceAllForSync(snapshot.customExercises)
        if let blob = snapshot.progressionBlob {
            progressionStore.importSyncBlob(blob)
        }
        if let blob = snapshot.globalProgressBlob {
            globalProgressStore.importSyncBlob(blob)
        }
        if let blob = snapshot.userSettingsBlob {
            settingsStore.importSyncBlob(blob)
        }
        saveTombstones(snapshot.tombstones)
        ExerciseCatalog.syncCustomExercises(customExerciseStore.exercises)
    }

    // MARK: - Private

    private func pushSync(allowDownloadMerge: Bool) async -> UserDataSnapshot {
        let snapshot = captureSnapshot(ownerId: currentOwner.rawValue)
        guard currentOwner.isAccount else {
            syncStatus = .localOnly
            return snapshot
        }
        let result = await syncEngine.sync(snapshot: snapshot, allowDownloadMerge: allowDownloadMerge)
        conflictFlags = syncEngine.lastConflictFlags
        syncStatus = syncEngine.status
        if !result.isEffectivelyEmpty {
            // Only re-apply if sync merged remote changes in.
            if allowDownloadMerge {
                applySnapshot(result)
            }
            try? AccountDataVault.save(result)
        }
        return result
    }

    private func wireOwnershipProviders() {
        let owner = currentOwner.rawValue
        workoutStore.ownershipProvider = { owner }
        historyStore.ownershipProvider = { owner }
        sessionStore.ownershipProvider = { owner }
        customExerciseStore.ownershipProvider = { owner }
        workoutStore.onMutation = { [weak self] in self?.noteLocalMutation() }
        workoutStore.onCreate = { [weak self] in self?.noteWorkoutCreated() }
        historyStore.onMutation = { [weak self] in self?.noteLocalMutation() }
        sessionStore.onMutation = { [weak self] in self?.noteLocalMutation() }
        customExerciseStore.onMutation = { [weak self] in self?.noteLocalMutation() }
        workoutStore.onDelete = { [weak self] id in
            self?.recordTombstone(id: id, entityType: "workout")
        }
    }

    private func ensureLegacyRecordsOwned() {
        workoutStore.stampMissingOwnership(currentOwner.rawValue)
        historyStore.stampMissingOwnership(currentOwner.rawValue)
        sessionStore.stampMissingOwnership(currentOwner.rawValue)
        customExerciseStore.stampMissingOwnership(currentOwner.rawValue)
    }

    private func maybeShowFirstWorkoutHint() {
        guard currentOwner.isGuest, !didShowFirstWorkoutBackupHint else { return }
        guard workoutStore.workouts.count == 1 else { return }
        didShowFirstWorkoutBackupHint = true
        UserDefaults.standard.set(true, forKey: firstWorkoutHintKey)
        lastMigrationMessage =
            "Your workouts are currently stored on this device. Sign in to back them up and access them on other devices."
    }

    private func loadTombstones() -> [DataTombstone] {
        guard let data = UserDefaults.standard.data(forKey: tombstonesKey),
              let decoded = try? JSONDecoder().decode([DataTombstone].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveTombstones(_ stones: [DataTombstone]) {
        guard let data = try? JSONEncoder().encode(stones) else { return }
        UserDefaults.standard.set(data, forKey: tombstonesKey)
    }
}
