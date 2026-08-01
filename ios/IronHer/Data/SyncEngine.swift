import Foundation

/// Coordinates upload / download / retry without blocking the workout UI.
@MainActor
@Observable
final class SyncEngine {
    private(set) var status: SyncStatus = .localOnly
    private(set) var lastConflictFlags: [String] = []

    private let remote: any RemoteUserDataStore
    private var hasPendingChanges = false

    init(remote: (any RemoteUserDataStore)? = nil) {
        self.remote = remote ?? LocalMirrorRemoteUserDataStore()
    }

    func markLocalChange() {
        hasPendingChanges = true
        if case .synced = status {
            status = .backingUp
        } else if case .localOnly = status {
            // Stay local-only for guests; authenticated flows elevate status.
        }
    }

    func setGuestLocalOnly() {
        status = .localOnly
        hasPendingChanges = false
    }

    /// Uploads snapshot. Never treats an empty remote as authority over populated local data.
    func sync(snapshot: UserDataSnapshot, allowDownloadMerge: Bool) async -> UserDataSnapshot {
        guard remote.isConfigured else {
            status = .localOnly
            return snapshot
        }

        status = .backingUp
        do {
            var working = snapshot
            if allowDownloadMerge {
                let remoteSnapshot = try await remote.fetchSnapshot(ownerId: snapshot.ownerId)
                if let remoteSnapshot, !remoteSnapshot.isEffectivelyEmpty {
                    let merged = UserDataMergeEngine.merge(
                        local: working,
                        remote: remoteSnapshot,
                        resultingOwnerId: snapshot.ownerId
                    )
                    working = merged.snapshot
                    lastConflictFlags = merged.conflictFlags
                }
            }

            // Never upload an empty snapshot over a known non-empty remote.
            if working.isEffectivelyEmpty {
                if let remoteSnapshot = try await remote.fetchSnapshot(ownerId: snapshot.ownerId),
                   !remoteSnapshot.isEffectivelyEmpty {
                    status = .synced(.now)
                    hasPendingChanges = false
                    return remoteSnapshot
                }
            }

            try await remote.uploadSnapshot(working)
            status = .synced(.now)
            hasPendingChanges = false
            return working
        } catch {
            status = .failed(error.localizedDescription)
            hasPendingChanges = true
            return snapshot
        }
    }

    func retry(snapshot: UserDataSnapshot) async -> UserDataSnapshot {
        await sync(snapshot: snapshot, allowDownloadMerge: true)
    }

    /// Permanently removes the remote mirror for an owner. Does not touch local stores.
    func deleteRemoteData(ownerId: String) async throws {
        guard remote.isConfigured else { return }
        try await remote.deleteSnapshot(ownerId: ownerId)
    }

    var needsRetry: Bool {
        if case .failed = status { return true }
        return hasPendingChanges
    }
}
