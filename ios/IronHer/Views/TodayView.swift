import SwiftUI

struct ProfileToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BrandLogoMark(size: 32)
                    .accessibilityLabel("trenira")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22))
                        .accessibilityLabel("Profile")
                }
            }
        }
    }
}

extension View {
    func profileToolbar() -> some View {
        modifier(ProfileToolbar())
    }
}

/// Today: a short check-in, then choices. Energy and equipment never block the next step.
struct TodayView: View {
    @Environment(UserDataCoordinator.self) private var dataCoordinator

    @State private var minutes = PilotTimeChoice.five.rawValue
    @State private var energy: MovementEnergy = .okay
    @State private var choice: TodayEquipmentChoice = .focused(.none)
    @State private var showSuggestions = false
    @State private var showLog = false
    @State private var showResume = false
    @State private var revision = 0

    private var ownerId: String { dataCoordinator.currentOwner.rawValue }

    private var profile: CompanionProfile {
        CompanionProfileStore.load() ?? CompanionProfile(skipped: true)
    }

    private var query: RecommendationQuery {
        let selection: EquipmentSelection
        switch choice {
        case .focused(let equipment):
            selection = .focused(equipment)
        case .surprise:
            selection = .surprise(profile.availableEquipment)
        }
        return RecommendationQuery(
            minutes: minutes,
            energy: energy,
            selection: selection,
            preferred: profile.catalogPreferences,
            avoidFloor: profile.avoidsFloor
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                header
                if showsWelcomeBack {
                    Text(DiaryReflection.welcomeBack)
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let draft = PausedMovementDraftStore.load(ownerId: ownerId) {
                    resumeCard(draft)
                }
                choices
            }
            .padding(.horizontal, TreniraSpace.screen)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .profileToolbar()
        .onAppear(perform: restoreMemory)
        .navigationDestination(isPresented: $showSuggestions) {
            MovementSuggestionListView(query: query, ownerId: ownerId, source: .guided) {
                showSuggestions = false
                revision += 1
            }
        }
        .navigationDestination(isPresented: $showLog) {
            AddMovementView(ownerId: ownerId, onFinished: {
                showLog = false
                revision += 1
            })
        }
        .navigationDestination(isPresented: $showResume) {
            if let draft = PausedMovementDraftStore.load(ownerId: ownerId) {
                ActiveMovementView(
                    activity: MovementCatalog.activity(id: draft.catalogID ?? "") ?? MovementCatalog.activity(id: "easy-walk")!,
                    minutes: draft.plannedMinutes,
                    ownerId: ownerId,
                    source: .guided,
                    restoredSeconds: draft.accumulatedSeconds,
                    query: query,
                    onFinished: {
                        showResume = false
                        revision += 1
                    }
                )
            }
        }
        .id(revision)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A LITTLE TIME FOR YOU")
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.orchid)
                .accessibilityAddTraits(.isHeader)
            Text("How much time do you have today?")
                .font(TreniraType.display)
                .foregroundStyle(TreniraColor.label)
                .fixedSize(horizontal: false, vertical: true)
            Text("Even a few minutes can make a difference.")
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: 14) {
            chipRow(title: "How much time do you have?", choices: PilotTimeChoice.allCases.map { ($0.title, $0.rawValue == minutes, $0.accessibilityTitle) }) { index in
                minutes = PilotTimeChoice.allCases[index].rawValue
                remember()
            }
            chipRow(title: "How's your energy?", choices: MovementEnergy.allCases.map { ($0.title, energy == $0, $0.title) }) { index in
                energy = MovementEnergy.allCases[index]
                remember()
            }
            EquipmentSelector(choice: $choice)
                .onChange(of: choice) { _, _ in remember() }
            Button("Find my movement") {
                remember()
                showSuggestions = true
            }
            .buttonStyle(TreniraPrimaryButtonStyle())
            .accessibilityHint("Shows three movement choices. Energy is already filled in and can be changed.")
            Button("Log movement") { showLog = true }
                .buttonStyle(TreniraSecondaryButtonStyle())
                .accessibilityHint("Records movement you already did, including a past day")
        }
    }

    private func chipRow(
        title: String,
        choices: [(String, Bool, String)],
        onTap: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
            HStack(spacing: 8) {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                    TimeChoiceChip(title: choice.0, isSelected: choice.1) { onTap(index) }
                        .accessibilityLabel(choice.2)
                }
            }
        }
    }

    private func resumeCard(_ draft: PausedMovementDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(DiaryReflection.interrupted)
                .font(TreniraType.section)
                .foregroundStyle(TreniraColor.label)
            Text("\(draft.title) · \(MovementDurationFormat.exact(draft.accumulatedSeconds)) so far.")
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
            Button("Resume") { showResume = true }
                .buttonStyle(TreniraSecondaryButtonStyle())
            Button("Let it go") {
                PausedMovementDraftStore.clear(ownerId: ownerId)
                revision += 1
            }
            .buttonStyle(TreniraSecondaryButtonStyle())
        }
        .treniraCard()
    }

    private var showsWelcomeBack: Bool {
        let records = MovementRecordStore.load(ownerId: ownerId)
        guard let latest = records.map(\.activityDate).max() else { return false }
        let days = Calendar.current.dateComponents([.day], from: latest, to: .now).day ?? 0
        return days >= 7
    }

    private func restoreMemory() {
        choice = .focused(.none)
        if let memory = TodayCheckInStore.load() {
            if PilotTimeChoice(rawValue: memory.minutes) != nil {
                minutes = memory.minutes
            }
            if let storedEnergy = MovementEnergy(rawValue: memory.energy) {
                energy = storedEnergy
            }
            if let selection = memory.selection {
                choice = TodayEquipmentChoice(storageValue: selection)
            } else if memory.equipment.count == 1, let only = memory.equipment.first {
                choice = TodayEquipmentChoice(storageValue: only)
            }
        }
    }

    private func remember() {
        let storedEquipment: [String]
        switch choice {
        case .focused(let equipment):
            storedEquipment = [equipment.rawValue]
        case .surprise:
            storedEquipment = profile.availableEquipment.map(\.rawValue).sorted()
        }
        TodayCheckInStore.save(TodayCheckInMemory(
            minutes: minutes,
            energy: energy.rawValue,
            equipment: storedEquipment,
            selection: choice.storageValue
        ))
    }
}
