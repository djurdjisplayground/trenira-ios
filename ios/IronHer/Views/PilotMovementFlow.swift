import SwiftUI
import UIKit

extension MovementHistoryKind {
    var momentLabel: String {
        switch self {
        case .strength: "Strength"
        case .walking: "Walk"
        case .externalVideo: "Video"
        case .yoga: "Yoga"
        case .dancing: "Dancing"
        case .withBaby: "Movement with baby"
        case .other: "Other movement"
        case .guided: "Gentle guided movement"
        case .stretching: "Dance or stretch"
        }
    }
}

struct CompanionIllustrationView: View {
    var assetName: String
    var title: String
    var instruction: String

    var body: some View {
        Group {
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 310)
        .accessibilityLabel("\(title). \(instruction)")
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(TreniraColor.ivory)
            VStack(spacing: 12) {
                botanical
                Text("Illustration coming")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
                Text(title)
                    .font(TreniraType.displayTitle)
                    .foregroundStyle(TreniraColor.label)
            }
            .padding(24)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(TreniraColor.mauve, lineWidth: 1)
        }
    }

    private var botanical: some View {
        ZStack {
            Circle()
                .fill(TreniraColor.mauve.opacity(0.7))
                .frame(width: 92, height: 92)
                .offset(x: -18, y: 8)
            Ellipse()
                .fill(TreniraColor.orchid.opacity(0.85))
                .frame(width: 36, height: 64)
                .rotationEffect(.degrees(-28))
                .offset(x: 16, y: -6)
            Ellipse()
                .fill(TreniraColor.surface)
                .frame(width: 22, height: 40)
                .rotationEffect(.degrees(24))
                .offset(x: 34, y: 10)
        }
        .frame(height: 110)
        .accessibilityHidden(true)
    }
}

struct PoseSequenceView: View {
    let movement: GuidedMovement
    @Binding var poseIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $poseIndex) {
                ForEach(Array(movement.poses.enumerated()), id: \.element.id) { index, pose in
                    VStack(spacing: 14) {
                        CompanionIllustrationView(
                            assetName: pose.assetName,
                            title: pose.title,
                            instruction: pose.instruction
                        )
                        Text(pose.title)
                            .font(TreniraType.section)
                            .foregroundStyle(TreniraColor.label)
                        Text(pose.instruction)
                            .font(TreniraType.body)
                            .foregroundStyle(TreniraColor.labelSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 430)
            HStack(spacing: 12) {
                Button("Repeat") { showPose(0) }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                Button("Next picture") { showPose(min(poseIndex + 1, movement.poses.count - 1)) }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                    .disabled(poseIndex >= movement.poses.count - 1)
            }
        }
    }

    private func showPose(_ index: Int) {
        if reduceMotion {
            poseIndex = index
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { poseIndex = index }
        }
    }
}

struct TimeChoiceChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TreniraType.bodyMedium)
                .foregroundStyle(isSelected ? TreniraColor.onAction : TreniraColor.label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? TreniraColor.action : TreniraColor.ivory)
                .clipShape(Capsule())
                .overlay { Capsule().stroke(TreniraColor.mauve, lineWidth: isSelected ? 0 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SuggestionCard: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(TreniraType.displayTitle)
                .foregroundStyle(TreniraColor.label)
            Text(detail)
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TreniraSpace.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreniraColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous)
                .stroke(TreniraColor.mauve, lineWidth: 1)
        }
    }
}

struct MovementSuggestionsView: View {
    var minutes: Int
    var energy: MovementEnergy?
    var ownerId: String
    var onFinished: () -> Void

    private var suggestions: [PilotSuggestion] {
        PilotSuggestions.make(minutes: minutes, energy: energy)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.stack) {
                Text("Choices for this moment")
                    .font(TreniraType.display)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text("About \(minutes) minutes. Any of these counts.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                ForEach(suggestions) { suggestion in
                    NavigationLink {
                        destination(suggestion)
                    } label: {
                        SuggestionCard(title: suggestion.title, detail: suggestion.detail)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens \(suggestion.title)")
                }
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Choices")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(_ suggestion: PilotSuggestion) -> some View {
        switch suggestion.action {
        case .guided:
            GuidedBreakOverviewView(minutes: minutes, ownerId: ownerId, onFinished: onFinished)
        case .walk:
            MomentTimerView(kind: .walking, title: "Walk", minutes: minutes, ownerId: ownerId, onFinished: onFinished)
        case .danceStretch:
            MomentTimerView(kind: .stretching, title: "Dance or stretch", minutes: minutes, ownerId: ownerId, onFinished: onFinished)
        case .manual:
            ManualMovementEntryView(minutes: minutes, ownerId: ownerId, onFinished: onFinished)
        }
    }
}

struct GuidedBreakOverviewView: View {
    var minutes: Int
    var ownerId: String
    var onFinished: () -> Void

    @State private var included: Set<String> = Set(PilotMovementCatalog.movements.map(\.id))

    private var selected: [GuidedMovement] {
        PilotMovementCatalog.movements.filter { included.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("A gentle break")
                    .font(TreniraType.display)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text(PilotMovementCatalog.safetyNote)
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(PilotMovementCatalog.movements) { movement in
                    Toggle(isOn: binding(movement.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(movement.title)
                                .font(TreniraType.section)
                            Text(movement.summary)
                                .font(TreniraType.caption)
                                .foregroundStyle(TreniraColor.labelSecondary)
                        }
                    }
                    .tint(TreniraColor.action)
                    .padding(TreniraSpace.cardPadding)
                    .background(TreniraColor.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous))
                }
                NavigationLink {
                    MovementPoseGuideView(movements: selected, minutes: minutes, ownerId: ownerId, onFinished: onFinished)
                } label: {
                    Text(selected.isEmpty ? "Choose one to begin" : "Begin")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
                .disabled(selected.isEmpty)
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Gentle break")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { included.contains(id) },
            set: { isOn in
                if isOn { included.insert(id) } else { included.remove(id) }
            }
        )
    }
}

struct MovementPoseGuideView: View {
    var movements: [GuidedMovement]
    var minutes: Int
    var ownerId: String
    var restoredSeconds: TimeInterval = 0
    var onFinished: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = MovementSessionClock()
    @State private var movementIndex = 0
    @State private var poseIndex = 0
    @State private var elapsed: TimeInterval = 0
    @State private var showCompletion = false
    @State private var leftForCompletion = false
    @State private var didRestore = false

    private var movement: GuidedMovement? {
        guard movements.indices.contains(movementIndex) else { return nil }
        return movements[movementIndex]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let movement {
                    Text(movement.title)
                        .font(TreniraType.display)
                        .foregroundStyle(TreniraColor.label)
                        .accessibilityAddTraits(.isHeader)
                    PoseSequenceView(movement: movement, poseIndex: $poseIndex)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(MovementDurationFormat.exact(clock.elapsed(at: context.date)))
                        .font(TreniraType.section)
                        .foregroundStyle(TreniraColor.label)
                        .accessibilityLabel("Active time \(MovementDurationFormat.exact(clock.elapsed(at: context.date)))")
                }
                Button(clock.isRunning ? "Pause" : "Resume") {
                    let now = Date()
                    if clock.isRunning {
                        clock.pause(at: now)
                        saveDraft()
                    } else {
                        clock.resume(at: now)
                    }
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
                Button("Skip movement") { skip() }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                Button("Finish early") { finish() }
                    .buttonStyle(TreniraPrimaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Movement")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if restoredSeconds > 0, !didRestore {
                clock = MovementSessionClock(accumulated: restoredSeconds)
                didRestore = true
                return
            }
            if !clock.isRunning, clock.elapsed(at: .now) == 0 {
                clock.start(at: .now)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background || phase == .inactive else { return }
            clock.pause(at: .now)
            saveDraft()
        }
        .onDisappear {
            guard !leftForCompletion else { return }
            clock.pause(at: .now)
            saveDraft()
        }
        .navigationDestination(isPresented: $showCompletion) {
            MomentCompletionView(
                kind: .guided,
                title: "Gentle guided movement",
                elapsed: elapsed,
                plannedMinutes: minutes,
                ownerId: ownerId,
                onFinished: onFinished
            )
        }
    }

    private func skip() {
        poseIndex = 0
        if movementIndex + 1 < movements.count {
            movementIndex += 1
        } else {
            finish()
        }
    }

    private func finish() {
        clock.pause(at: .now)
        elapsed = clock.elapsed(at: .now)
        leftForCompletion = true
        PausedMovementDraftStore.clear(ownerId: ownerId)
        showCompletion = true
    }

    private func saveDraft() {
        guard !leftForCompletion else { return }
        PausedMovementDraftStore.save(PausedMovementDraft(
            ownerId: ownerId,
            kind: .guided,
            title: "Gentle guided movement",
            plannedMinutes: minutes,
            movementIDs: movements.map(\.id),
            movementIndex: movementIndex,
            accumulatedSeconds: clock.elapsed(at: .now)
        ))
    }
}

struct MomentTimerView: View {
    var kind: MovementRecordKind
    var title: String
    var minutes: Int
    var ownerId: String
    var restoredSeconds: TimeInterval = 0
    var onFinished: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = MovementSessionClock()
    @State private var elapsed: TimeInterval = 0
    @State private var showCompletion = false
    @State private var leftForCompletion = false
    @State private var didRestore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text(title)
                    .font(TreniraType.display)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text("About \(minutes) minutes, or stop whenever you need to. Time pauses when you pause.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(MovementDurationFormat.exact(clock.elapsed(at: context.date)))
                        .font(TreniraType.display)
                        .foregroundStyle(TreniraColor.label)
                        .accessibilityLabel("Active time \(MovementDurationFormat.exact(clock.elapsed(at: context.date)))")
                }
                Button(clock.isRunning ? "Pause" : (clock.elapsed(at: .now) == 0 ? "Start" : "Resume")) {
                    let now = Date()
                    if clock.isRunning {
                        clock.pause(at: now)
                        saveDraft()
                    } else if clock.elapsed(at: now) == 0 {
                        clock.start(at: now)
                    } else {
                        clock.resume(at: now)
                    }
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
                Button("Finish") { finish() }
                    .buttonStyle(TreniraSecondaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if restoredSeconds > 0, !didRestore {
                clock = MovementSessionClock(accumulated: restoredSeconds)
                didRestore = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background || phase == .inactive else { return }
            clock.pause(at: .now)
            saveDraft()
        }
        .onDisappear {
            guard !leftForCompletion else { return }
            if clock.elapsed(at: .now) > 0 {
                clock.pause(at: .now)
                saveDraft()
            }
        }
        .navigationDestination(isPresented: $showCompletion) {
            MomentCompletionView(
                kind: kind,
                title: title,
                elapsed: elapsed,
                plannedMinutes: minutes,
                ownerId: ownerId,
                onFinished: onFinished
            )
        }
    }

    private func finish() {
        clock.pause(at: .now)
        elapsed = clock.elapsed(at: .now)
        leftForCompletion = true
        PausedMovementDraftStore.clear(ownerId: ownerId)
        showCompletion = true
    }

    private func saveDraft() {
        guard !leftForCompletion else { return }
        PausedMovementDraftStore.save(PausedMovementDraft(
            ownerId: ownerId,
            kind: kind,
            title: title,
            plannedMinutes: minutes,
            movementIDs: [],
            movementIndex: 0,
            accumulatedSeconds: clock.elapsed(at: .now)
        ))
    }
}

struct ManualMovementEntryView: View {
    var minutes: Int
    var ownerId: String
    var onFinished: () -> Void

    private let kinds: [MovementRecordKind] = [.walking, .dancing, .stretching, .yoga, .other]
    @State private var kind: MovementRecordKind = .other
    @State private var minutePart = 0
    @State private var secondPart = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("Something else")
                    .font(TreniraType.display)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text("This is a full choice, not a backup. Record what you did, for as long as you actually moved.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Kind of movement", selection: $kind) {
                    ForEach(kinds, id: \.rawValue) { item in
                        Text(item.recordTitle).tag(item)
                    }
                }
                .pickerStyle(.menu)
                Stepper("\(minutePart) min", value: $minutePart, in: 0...180)
                Stepper("\(secondPart) sec", value: $secondPart, in: 0...59)
                NavigationLink {
                    MomentTimerView(kind: kind, title: kind.recordTitle, minutes: minutes, ownerId: ownerId, onFinished: onFinished)
                } label: {
                    Text("Time it here")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
                NavigationLink {
                    MomentCompletionView(
                        kind: kind,
                        title: kind.recordTitle,
                        elapsed: TimeInterval(minutePart * 60 + secondPart),
                        plannedMinutes: minutes,
                        ownerId: ownerId,
                        onFinished: onFinished
                    )
                } label: {
                    Text("I already moved")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Your movement")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MomentCompletionView: View {
    var kind: MovementRecordKind
    var title: String
    var elapsed: TimeInterval
    var plannedMinutes: Int
    var ownerId: String
    var onFinished: () -> Void

    @State private var didSave = false

    private var finishedEarly: Bool {
        elapsed < TimeInterval(plannedMinutes * 60)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("A little movement, a little moment for yourself. That counts. 💜")
                    .font(TreniraType.displayTitle)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if finishedEarly {
                    Text("What you did still counts.")
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.label)
                }
                Text("\(title) · \(MovementDurationFormat.exact(elapsed))")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                Button("Save this moment") { save() }
                    .buttonStyle(TreniraPrimaryButtonStyle())
                    .disabled(didSave)
                Button("Back to Today") { onFinished() }
                    .buttonStyle(TreniraSecondaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Moment")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func save() {
        guard !didSave else { return }
        didSave = true
        let record = MomentRecordBuilder.record(
            kind: kind,
            title: title,
            elapsed: elapsed,
            plannedMinutes: plannedMinutes,
            ownerId: ownerId
        )
        MovementRecordStore.add(record)
        AnalyticsService.capture(.activityCompleted, properties: ["activity_type": kind.analyticsActivityType])
        PausedMovementDraftStore.clear(ownerId: ownerId)
        onFinished()
    }
}

struct PilotResumeView: View {
    var draft: PausedMovementDraft
    var onFinished: () -> Void

    var body: some View {
        Group {
            if draft.kind == .guided {
                MovementPoseGuideView(
                    movements: restoredMovements,
                    minutes: draft.plannedMinutes,
                    ownerId: draft.ownerId,
                    restoredSeconds: draft.accumulatedSeconds,
                    onFinished: onFinished
                )
            } else {
                MomentTimerView(
                    kind: draft.kind,
                    title: draft.title,
                    minutes: draft.plannedMinutes,
                    ownerId: draft.ownerId,
                    restoredSeconds: draft.accumulatedSeconds,
                    onFinished: onFinished
                )
            }
        }
    }

    private var restoredMovements: [GuidedMovement] {
        let chosen = PilotMovementCatalog.movements.filter { draft.movementIDs.contains($0.id) }
        return chosen.isEmpty ? PilotMovementCatalog.movements : chosen
    }
}

struct MyMomentsView: View {
    var ownerId: String
    var strengthLogs: [StrengthHistorySnapshot]

    private var items: [MovementHistoryItem] {
        MovementJournal.items(
            records: MovementRecordStore.load(ownerId: ownerId),
            strengthLogs: strengthLogs
        )
    }

    private var summary: MovementWeekSummary {
        MovementJournal.weekSummary(items: items)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No moments yet",
                    systemImage: "leaf",
                    description: Text("When you save a moment, it will show up here. Nothing is overdue.")
                )
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(MovementReminderCopy.weekly)
                                .font(TreniraType.displayTitle)
                                .foregroundStyle(TreniraColor.label)
                            Text(MovementJournal.weekLine(summary))
                                .font(TreniraType.body)
                                .foregroundStyle(TreniraColor.labelSecondary)
                        }
                        .listRowBackground(TreniraColor.ivory)
                    }
                    Section("Saved moments") {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(TreniraType.bodyMedium)
                                Text(detail(item))
                                    .font(TreniraType.caption)
                                    .foregroundStyle(TreniraColor.labelSecondary)
                            }
                            .accessibilityElement(children: .combine)
                            .listRowBackground(TreniraColor.elevated)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Moments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ item: MovementHistoryItem) -> String {
        let day = item.completedAt.formatted(date: .abbreviated, time: .omitted)
        let duration = MovementDurationFormat.exactLabel(seconds: item.actualDurationSeconds, minutes: item.actualMinutes)
        return "\(item.kind.momentLabel) · \(duration) · \(day)"
    }
}
