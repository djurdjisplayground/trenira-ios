import SwiftUI

struct MovementSuggestionListView: View {
    var query: RecommendationQuery
    var ownerId: String
    var source: MovementRecordSource
    var onFinished: () -> Void = {}

    @State private var excluded: Set<String> = []

    private var suggestions: [CatalogActivity] {
        var next = query
        next.excludeIDs = excluded
        return MovementCatalogRecommender.suggestions(for: next)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.stack) {
                Text("Choices for this moment")
                    .font(TreniraType.display)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text("About \(query.minutes >= 20 ? "20 or more" : "\(query.minutes)") minutes. Any of these counts.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                if suggestions.isEmpty {
                    Text(MovementCatalogRecommender.noMatchMessage)
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.label)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Change equipment") { onFinished() }
                        .buttonStyle(TreniraSecondaryButtonStyle())
                } else {
                    ForEach(suggestions) { activity in
                        NavigationLink {
                            MovementDetailView(activity: activity, query: query, ownerId: ownerId, source: source, onFinished: onFinished)
                        } label: {
                            SuggestionCard(
                                title: activity.name,
                                detail: "\(activity.category.title) · \(activity.durationLabel)"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens \(activity.name)")
                    }
                    Button("Another idea") {
                        excluded.formUnion(suggestions.map(\.id))
                    }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                    .accessibilityHint("Shows different choices for the same equipment, time, and energy")
                }
                NavigationLink {
                    AddMovementView(ownerId: ownerId, plannedMinutes: query.minutes, onFinished: onFinished)
                } label: {
                    Text("Something else / Do my own thing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Choices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MovementDetailView: View {
    var activity: CatalogActivity
    var query: RecommendationQuery
    var ownerId: String
    var source: MovementRecordSource
    var onFinished: () -> Void = {}

    @State private var current: CatalogActivity?
    @State private var excluded: Set<String> = []

    private var shown: CatalogActivity { current ?? activity }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text(shown.name)
                    .font(TreniraType.display)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text("\(shown.durationLabel) · \(query.energy.title) energy · \(shown.equipment.title)")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                if shown.safety == .pendingProfessionalReview {
                    Text(MovementCatalog.draftReviewLine)
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(shown.instructions.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Easier option: \(shown.easier)")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                if shown.caution != MovementCatalog.draftReviewLine {
                    Text(shown.caution)
                        .font(TreniraType.caption)
                        .foregroundStyle(TreniraColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(MovementCatalog.safetyLine)
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    ActiveMovementView(
                        activity: shown,
                        minutes: query.minutes,
                        ownerId: ownerId,
                        source: source,
                        query: query,
                        onFinished: onFinished
                    )
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
                Button("Another idea") { swap() }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                NavigationLink {
                    AddMovementView(ownerId: ownerId, plannedMinutes: query.minutes, onFinished: onFinished)
                } label: {
                    Text("Do my own thing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Movement")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func swap() {
        excluded.insert(shown.id)
        var next = query
        next.excludeIDs = excluded
        if let replacement = MovementCatalogRecommender.suggestions(for: next).first {
            current = replacement
        }
    }
}

struct ActiveMovementView: View {
    var activity: CatalogActivity
    var minutes: Int
    var ownerId: String
    var source: MovementRecordSource
    var restoredSeconds: TimeInterval = 0
    var query: RecommendationQuery
    var onFinished: () -> Void = {}

    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = MovementSessionClock()
    @State private var step = 0
    @State private var current: CatalogActivity?
    @State private var excluded: Set<String> = []
    @State private var elapsed: TimeInterval = 0
    @State private var showSave = false
    @State private var leftForSave = false
    @State private var didRestore = false

    private var shown: CatalogActivity { current ?? activity }
    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(shown.name)
                    .font(TreniraType.display)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text(currentInstruction)
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(MovementDurationFormat.exact(clock.elapsed(atUptime: ProcessInfo.processInfo.systemUptime)))
                        .font(TreniraType.section)
                        .foregroundStyle(TreniraColor.label)
                        .accessibilityLabel("Active time \(MovementDurationFormat.exact(clock.elapsed(atUptime: ProcessInfo.processInfo.systemUptime)))")
                }
                Button(clock.isRunning ? "Pause" : (clock.elapsed(atUptime: uptime) == 0 && restoredSeconds == 0 ? "Start" : "Resume")) {
                    if clock.isRunning {
                        clock.pause(atUptime: uptime)
                        saveDraft()
                    } else {
                        clock.resume(atUptime: uptime)
                    }
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
                if shown.instructions.count > 1 {
                    Button("Next") { step = min(step + 1, shown.instructions.count - 1) }
                        .buttonStyle(TreniraSecondaryButtonStyle())
                    Button("Skip") { step = min(step + 1, shown.instructions.count - 1) }
                        .buttonStyle(TreniraSecondaryButtonStyle())
                }
                Button("Swap") { swap() }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                    .accessibilityHint("Changes the movement and keeps the time already counted")
                Button("Finish for now") { finish() }
                    .buttonStyle(TreniraPrimaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Moving")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if restoredSeconds > 0, !didRestore {
                clock = MovementSessionClock(accumulated: restoredSeconds)
                didRestore = true
                return
            }
            if !clock.isRunning, clock.elapsed(atUptime: uptime) == 0 {
                clock.begin(atUptime: uptime)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background || phase == .inactive else { return }
            clock.pause(atUptime: uptime)
            saveDraft()
        }
        .onDisappear {
            guard !leftForSave else { return }
            clock.pause(atUptime: uptime)
            saveDraft()
        }
        .navigationDestination(isPresented: $showSave) {
            MomentSaveView(
                activity: shown,
                elapsed: elapsed,
                plannedMinutes: minutes,
                ownerId: ownerId,
                source: source,
                onFinished: onFinished
            )
        }
    }

    private var currentInstruction: String {
        let lines = shown.instructions
        guard lines.indices.contains(step) else { return lines.first ?? "" }
        return lines[step]
    }

    private func swap() {
        excluded.insert(shown.id)
        var next = query
        next.excludeIDs = excluded
        if let replacement = MovementCatalogRecommender.suggestions(for: next).first {
            current = replacement
            step = 0
        }
    }

    private func finish() {
        clock.pause(atUptime: uptime)
        elapsed = clock.elapsed(atUptime: uptime)
        leftForSave = true
        PausedMovementDraftStore.clear(ownerId: ownerId)
        showSave = true
    }

    private func saveDraft() {
        guard !leftForSave else { return }
        PausedMovementDraftStore.save(PausedMovementDraft(
            ownerId: ownerId,
            kind: shown.category.recordKind,
            title: shown.name,
            plannedMinutes: minutes,
            movementIDs: [shown.id],
            movementIndex: 0,
            accumulatedSeconds: clock.elapsed(atUptime: uptime),
            catalogID: shown.id,
            stepIndex: step
        ))
    }
}

struct MomentSaveView: View {
    var activity: CatalogActivity
    var elapsed: TimeInterval
    var plannedMinutes: Int
    var ownerId: String
    var source: MovementRecordSource
    var onFinished: () -> Void = {}

    @State private var minutes = 0
    @State private var seconds = 0
    @State private var saved = false
    @State private var recordID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("A little movement, a little moment for yourself. That counts. 💜")
                    .font(TreniraType.displayTitle)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                if finishedEarly {
                    Text("What you did still counts.")
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.label)
                }
                Text(activity.name)
                    .font(TreniraType.section)
                    .foregroundStyle(TreniraColor.label)
                Stepper(value: $minutes, in: 0...180) {
                    Text(minutes == 1 ? "1 minute" : "\(minutes) minutes")
                }
                .accessibilityLabel("Minutes")
                Stepper(value: $seconds, in: 0...59) {
                    Text(seconds == 1 ? "1 second" : "\(seconds) seconds")
                }
                .accessibilityLabel("Seconds")
                Text("This is the time you actually moved. A few seconds stay a few seconds.")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
                Button(saved ? "Saved" : "Save this moment") { save() }
                    .buttonStyle(TreniraPrimaryButtonStyle())
                    .disabled(saved)
                Button("Back to Today") { onFinished() }
                    .buttonStyle(TreniraSecondaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Save")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: seedDuration)
    }

    private var totalSeconds: TimeInterval { TimeInterval(minutes * 60 + seconds) }

    private var finishedEarly: Bool {
        totalSeconds < TimeInterval(plannedMinutes * 60)
    }

    private func seedDuration() {
        let whole = max(0, Int(elapsed.rounded(.down)))
        minutes = whole / 60
        seconds = whole % 60
    }

    private func save() {
        guard !saved else { return }
        let now = Date()
        let record = MovementRecord(
            id: recordID,
            kind: activity.category.recordKind,
            title: activity.name,
            completedAt: now,
            actualMinutes: 0,
            plannedMinutes: plannedMinutes,
            ownerId: ownerId,
            actualDurationSeconds: totalSeconds,
            activityAt: now,
            source: source,
            createdAt: now,
            updatedAt: now,
            catalogID: activity.id,
            sessionID: recordID,
            completionStatus: "saved"
        )
        MovementRecordStore.upsert(record)
        AnalyticsService.capture(
            .activityCompleted,
            properties: ["activity_type": record.kind.analyticsActivityType]
        )
        saved = true
        onFinished()
    }
}

struct AddMovementView: View {
    var ownerId: String
    var plannedMinutes: Int? = nil
    var existing: MovementRecord? = nil
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()
    @State private var category: CatalogCategory = .walking
    @State private var name = "Walk"
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var notes = ""
    @State private var saved = false
    @State private var confirmDelete = false
    @State private var recordID = UUID()

    var body: some View {
        Form {
            DatePicker("Day", selection: $day, in: ...Date(), displayedComponents: .date)
            Picker("Category", selection: $category) {
                ForEach(CatalogCategory.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .onChange(of: category) { _, newValue in
                if existing == nil { name = defaultName(newValue) }
            }
            TextField("Name", text: $name)
            Stepper(value: $minutes, in: 0...300) {
                Text(minutes == 1 ? "1 minute" : "\(minutes) minutes")
            }
            Stepper(value: $seconds, in: 0...59) {
                Text(seconds == 1 ? "1 second" : "\(seconds) seconds")
            }
            TextField("Notes, if you want", text: $notes, axis: .vertical)
        }
        .scrollContentBackground(.hidden)
        .background(TreniraColor.ivory)
        .navigationTitle(existing == nil ? "Log movement" : "Edit moment")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(saved ? "Saved" : "Save") { save() }
                    .buttonStyle(TreniraPrimaryButtonStyle())
                    .disabled(saved || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if existing != nil {
                    Button("Delete", role: .destructive) { confirmDelete = true }
                        .buttonStyle(TreniraSecondaryButtonStyle())
                }
            }
            .padding(TreniraSpace.screen)
            .background(TreniraColor.ivory)
        }
        .onAppear(perform: loadExisting)
        .confirmationDialog("Delete this moment?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existing {
                    MovementRecordStore.delete(id: existing.id)
                }
                onFinished()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes it from your diary and from the week it belonged to.")
        }
    }

    private func defaultName(_ category: CatalogCategory) -> String {
        switch category {
        case .walking: "Walk"
        case .dancing: "Dance"
        default: category.title
        }
    }

    private func loadExisting() {
        guard let existing else {
            if let plannedMinutes { minutes = plannedMinutes }
            return
        }
        recordID = existing.id
        day = existing.activityDate
        name = existing.title
        notes = existing.notes ?? ""
        category = CatalogCategory.allCases.first { $0.recordKind == existing.kind } ?? .walking
        let whole = max(0, Int(existing.loggedSeconds.rounded(.down)))
        minutes = whole / 60
        seconds = whole % 60
    }

    private func save() {
        guard !saved else { return }
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = 12
        let activityAt = calendar.date(from: parts) ?? day
        let now = Date()
        let record = MovementRecord(
            id: recordID,
            kind: category.recordKind,
            title: name.trimmingCharacters(in: .whitespacesAndNewlines),
            completedAt: existing?.completedAt ?? now,
            actualMinutes: 0,
            plannedMinutes: plannedMinutes,
            ownerId: ownerId,
            actualDurationSeconds: TimeInterval(minutes * 60 + seconds),
            activityAt: activityAt,
            source: .manual,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            catalogID: existing?.catalogID,
            sessionID: existing?.sessionID,
            completionStatus: "saved"
        )
        MovementRecordStore.upsert(record)
        if existing == nil {
            AnalyticsService.capture(
                .activityCompleted,
                properties: ["activity_type": record.kind.analyticsActivityType]
            )
        }
        saved = true
        onFinished()
    }
}
