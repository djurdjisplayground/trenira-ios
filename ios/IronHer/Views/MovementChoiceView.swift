import Combine
import SwiftUI

struct ChosenMovement: Identifiable, Hashable {
    var category: MovementFormat
    var minutes: Int
    var id: String { "\(category.rawValue)-\(minutes)" }
}

/// Categories the person can pick. Selecting one does not record anything.
struct MovementChoiceView: View {
    var ownerId: String
    var onFinished: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.stack) {
                Text("I'll choose my movement")
                    .font(TreniraType.title)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text("Pick what you feel like doing. Nothing is saved until you choose to record it.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(MovementFormat.choosable) { category in
                    NavigationLink {
                        MovementSelfStartView(category: category, ownerId: ownerId, onFinished: onFinished)
                    } label: {
                        categoryRow(category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.canvas)
        .navigationTitle("Choose")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryRow(_ category: MovementFormat) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: category.symbolName)
                .font(.body.weight(.medium))
                .foregroundStyle(TreniraColor.action)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(TreniraType.bodyMedium)
                    .foregroundStyle(TreniraColor.label)
                Text(category.summary)
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(TreniraSpace.cardPadding)
        .background(TreniraColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TreniraSpace.controlRadius, style: .continuous)
                .stroke(TreniraColor.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MovementSelfStartView: View {
    var category: MovementFormat
    var ownerId: String
    var plannedMinutes: Int?
    var onFinished: () -> Void

    @State private var minutes: Int
    @State private var showRecord = false
    @State private var showWalk = false

    init(category: MovementFormat, ownerId: String, plannedMinutes: Int? = nil, onFinished: @escaping () -> Void) {
        self.category = category
        self.ownerId = ownerId
        self.plannedMinutes = plannedMinutes
        self.onFinished = onFinished
        _minutes = State(initialValue: max(2, plannedMinutes ?? WeeklyMovementPlan.defaultMinutes))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text(category.title)
                    .font(TreniraType.title)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text(category.summary)
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if category == .withBaby {
                    Text(BabyMovementCopy.notice)
                        .font(TreniraType.caption)
                        .foregroundStyle(TreniraColor.label)
                        .fixedSize(horizontal: false, vertical: true)
                        .treniraCard()
                }
                Stepper(value: $minutes, in: 2...180) {
                    Text("\(minutes) minutes")
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.label)
                }
                .accessibilityLabel("Minutes you want")
                actions
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.canvas)
        .navigationTitle("Your choice")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showWalk) {
            MovementWalkView(plannedMinutes: minutes, ownerId: ownerId, onFinished: onFinished)
        }
        .navigationDestination(isPresented: $showRecord) {
            recordDestination
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch category {
        case .walking:
            Button("Start a walk") { showWalk = true }
                .buttonStyle(TreniraPrimaryButtonStyle())
            Button("I already walked") { showRecord = true }
                .buttonStyle(TreniraSecondaryButtonStyle())
        case .strength:
            Text("Saved strength sessions stay on this device. This screen does not open a training plan.")
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
        case .videos:
            NavigationLink {
                SavedVideosView(ownerId: ownerId)
            } label: {
                Text("Open saved videos")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TreniraPrimaryButtonStyle())
            Button("Record your movement") { showRecord = true }
                .buttonStyle(TreniraSecondaryButtonStyle())
            Text("Opening a video does not mark it done.")
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
        default:
            NavigationLink {
                MovementManualTimerView(category: category, minutes: minutes, ownerId: ownerId, onFinished: onFinished)
            } label: {
                Text("Start a timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TreniraSecondaryButtonStyle())
            Button("Record your movement") { showRecord = true }
                .buttonStyle(TreniraPrimaryButtonStyle())
        }
    }

    private var recordDestination: some View {
        MovementCompletionView(
            title: category.recordKind?.recordTitle ?? category.title,
            kind: category.recordKind ?? .other,
            plannedMinutes: minutes,
            initialActualMinutes: minutes,
            ownerId: ownerId,
            onSaved: onFinished
        )
    }
}

/// Optional timer. Nothing is stored until the person saves on the next screen.
struct MovementManualTimerView: View {
    var category: MovementFormat
    var minutes: Int
    var ownerId: String
    var onFinished: () -> Void

    @State private var startedAt: Date?
    @State private var elapsed = 0
    @State private var showRecord = false
    @State private var actual = 1

    var body: some View {
        VStack(alignment: .leading, spacing: TreniraSpace.section) {
            Text("Record your movement")
                .font(TreniraType.title)
                .foregroundStyle(TreniraColor.label)
                .accessibilityAddTraits(.isHeader)
            Text("\(category.title). About \(minutes) minutes, or stop whenever you need to.")
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)
            Text(startedAt == nil ? "Ready when you are" : "\(elapsed) min")
                .font(TreniraType.largeTitle)
                .foregroundStyle(TreniraColor.label)
                .accessibilityLabel(startedAt == nil ? "Timer not started" : "Elapsed \(elapsed) minutes")
            if startedAt == nil {
                Button("Start") { startedAt = .now }
                    .buttonStyle(TreniraPrimaryButtonStyle())
            } else {
                Button("I'm done") {
                    actual = max(1, elapsed == 0 ? 1 : elapsed)
                    showRecord = true
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
            }
            Spacer()
        }
        .padding(TreniraSpace.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TreniraColor.canvas)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            guard let startedAt else { return }
            elapsed = max(0, Int(Date().timeIntervalSince(startedAt) / 60))
        }
        .navigationDestination(isPresented: $showRecord) {
            MovementCompletionView(
                title: category.recordKind?.recordTitle ?? category.title,
                kind: category.recordKind ?? .other,
                plannedMinutes: minutes,
                initialActualMinutes: actual,
                ownerId: ownerId,
                onSaved: onFinished
            )
        }
    }
}

struct WeekIdeasSection: View {
    var ownerId: String
    var preferences: [MovementFormat]
    var records: [MovementRecord]
    var onRecord: (MovementFormat, Int) -> Void
    var onOpenStrength: () -> Void
    var onOpenVideos: () -> Void

    @State private var plan: StoredWeekPlan?
    @State private var swapIdea: WeekIdea?

    var body: some View {
        VStack(alignment: .leading, spacing: TreniraSpace.stack) {
            Text("Ideas for this week")
                .font(TreniraType.section)
                .foregroundStyle(TreniraColor.label)
            Text("Use one, swap it, or ignore it. Nothing here is missed.")
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
            ForEach(plan?.ideas ?? []) { idea in
                ideaCard(idea)
            }
        }
        .onAppear { reload() }
        .confirmationDialog(
            "Swap to another kind of movement",
            isPresented: Binding(get: { swapIdea != nil }, set: { if !$0 { swapIdea = nil } }),
            titleVisibility: .visible
        ) {
            if let idea = swapIdea {
                ForEach(MovementFormat.choosable.filter { $0 != idea.category }) { category in
                    Button(category.title) {
                        WeekPlanStore.swap(ownerId: ownerId, ideaID: idea.id, to: category, records: records)
                        swapIdea = nil
                        reload()
                    }
                }
            }
            Button("Cancel", role: .cancel) { swapIdea = nil }
        } message: {
            Text("The original idea stays off your history. Only what you record is saved.")
        }
    }

    private func ideaCard(_ idea: WeekIdea) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(idea.category.title, systemImage: idea.category.symbolName)
                .font(TreniraType.bodyMedium)
                .foregroundStyle(TreniraColor.label)
            if idea.isUntimedStrength {
                Text("About \(idea.recommendedMinutes) minutes if you have them, or \(idea.shorterMinutes). Your workout length is not timed.")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
            } else {
                Text("About \(idea.recommendedMinutes) minutes, or \(idea.shorterMinutes) if that fits better.")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
            }
            if idea.wasSwapped {
                Text("Swapped. The earlier idea is not marked missed.")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
            }
            if idea.category == .strength {
                Button("Open your workouts") { onOpenStrength() }
                    .buttonStyle(TreniraSecondaryButtonStyle())
            } else if idea.category == .videos {
                Button("Open saved videos") { onOpenVideos() }
                    .buttonStyle(TreniraSecondaryButtonStyle())
                Button("Record what you did") {
                    onRecord(idea.category, idea.recommendedMinutes)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
            } else {
                Button("Record what you did") {
                    onRecord(idea.category, idea.recommendedMinutes)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
                Button("Use \(idea.shorterMinutes) minutes") {
                    onRecord(idea.category, idea.shorterMinutes)
                }
                .buttonStyle(TreniraSecondaryButtonStyle())
            }
            Button("Swap") { swapIdea = idea }
                .buttonStyle(TreniraSecondaryButtonStyle())
        }
        .treniraCard()
    }

    private func reload() {
        plan = WeekPlanStore.resolve(ownerId: ownerId, preferences: preferences, records: records)
    }
}
