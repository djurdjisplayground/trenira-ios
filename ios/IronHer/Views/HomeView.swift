import SwiftUI

/// Today: choose a little time, see choices, move or do your own thing, then save.
struct HomeView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(UserDataCoordinator.self) private var dataCoordinator

    @State private var showSignOutConfirm = false
    @State private var showCompanionSetup = false
    @State private var profile = CompanionProfileStore.load()
    @State private var historyRevision = 0
    @State private var pilotMinutes = PilotTimeChoice.five.rawValue
    @State private var pilotEnergy: MovementEnergy?
    @State private var showPilot = false
    @State private var showResume = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                header
                todayTime
                if let draft = PausedMovementDraftStore.load(ownerId: dataCoordinator.currentOwner.rawValue) {
                    resumeCard(draft)
                }
                momentsLink
                if profile == nil || profile?.hasAnswers != true {
                    setupCard
                }
            }
            .padding(.horizontal, TreniraSpace.screen)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(TreniraColor.canvas)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BrandLogoMark(size: 32)
            }
            ToolbarItem(placement: .topBarTrailing) {
                authToolbarButton
            }
        }
        .sheet(isPresented: $showPilot, onDismiss: { historyRevision += 1 }) {
            NavigationStack {
                MovementSuggestionsView(
                    minutes: pilotMinutes,
                    energy: pilotEnergy,
                    ownerId: dataCoordinator.currentOwner.rawValue
                ) {
                    showPilot = false
                    historyRevision += 1
                }
            }
        }
        .sheet(isPresented: $showResume, onDismiss: { historyRevision += 1 }) {
            NavigationStack {
                if let draft = PausedMovementDraftStore.load(ownerId: dataCoordinator.currentOwner.rawValue) {
                    PilotResumeView(draft: draft) {
                        showResume = false
                        historyRevision += 1
                    }
                }
            }
        }
        .sheet(isPresented: $showCompanionSetup, onDismiss: {
            profile = CompanionProfileStore.load()
        }) {
            NavigationStack {
                CompanionOnboardingView {
                    showCompanionSetup = false
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { showCompanionSetup = false }
                    }
                }
            }
        }
        .confirmationDialog(
            "Log out?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Log out", role: .destructive) {
                authManager.signOut(preparing: dataCoordinator)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("What you've saved stays on this device.")
        }
        .onAppear {
            profile = CompanionProfileStore.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
            Text("A little time for you.")
                .font(TreniraType.largeTitle)
                .foregroundStyle(TreniraColor.label)
                .accessibilityAddTraits(.isHeader)
            Text("Your day might be unpredictable. Your movement doesn't have to be.")
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Want suggestions that fit your life?")
                .font(TreniraType.section)
                .foregroundStyle(TreniraColor.label)
            Text("A few answers are optional. You can skip them and still choose a moment.")
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)
            Button("Answer a few questions") {
                showCompanionSetup = true
            }
            .buttonStyle(TreniraSecondaryButtonStyle())
        }
        .treniraCard()
    }

    private var todayTime: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How much time do you have?")
                .font(TreniraType.displayTitle)
                .foregroundStyle(TreniraColor.label)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                ForEach(PilotTimeChoice.allCases) { choice in
                    TimeChoiceChip(title: choice.title, isSelected: pilotMinutes == choice.rawValue) {
                        pilotMinutes = choice.rawValue
                    }
                    .accessibilityLabel(choice.accessibilityTitle)
                    .accessibilityAddTraits(pilotMinutes == choice.rawValue ? .isSelected : [])
                }
            }
            Text("Energy, if you want to say. You can skip this.")
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
            HStack(spacing: 8) {
                ForEach(MovementEnergy.allCases) { energy in
                    TimeChoiceChip(title: energy.title, isSelected: pilotEnergy == energy) {
                        pilotEnergy = pilotEnergy == energy ? nil : energy
                    }
                    .accessibilityHint("Optional. Skipping this still shows choices.")
                }
            }
            Button("See choices") { showPilot = true }
                .buttonStyle(TreniraPrimaryButtonStyle())
                .accessibilityHint("Shows movement choices for \(pilotMinutes) minutes. Energy is not required.")
        }
        .padding(TreniraSpace.cardPadding)
        .background(TreniraColor.ivory)
        .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous)
                .stroke(TreniraColor.mauve, lineWidth: 1)
        }
    }

    private func resumeCard(_ draft: PausedMovementDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A moment is paused")
                .font(TreniraType.section)
                .foregroundStyle(TreniraColor.label)
            Text("\(draft.title) · \(MovementDurationFormat.exact(draft.accumulatedSeconds)) so far. You can leave it.")
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
            Button("Resume") { showResume = true }
                .buttonStyle(TreniraSecondaryButtonStyle())
            Button("Let it go") {
                PausedMovementDraftStore.clear(ownerId: draft.ownerId)
                historyRevision += 1
            }
            .buttonStyle(TreniraSecondaryButtonStyle())
        }
        .treniraCard()
        .id(historyRevision)
    }

    private var momentsLink: some View {
        NavigationLink {
            MyMomentsView(
                ownerId: dataCoordinator.currentOwner.rawValue,
                strengthLogs: []
            )
        } label: {
            Text("Moments")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(TreniraSecondaryButtonStyle())
        .id(historyRevision)
    }

    @ViewBuilder
    private var authToolbarButton: some View {
        if authManager.authState.isGuest {
            Button("Sign in") {
                authManager.signOut(preparing: dataCoordinator)
            }
            .font(TreniraType.caption)
            .foregroundStyle(TreniraColor.labelSecondary)
        } else if authManager.authState != .signedOut {
            Button("Log out") { showSignOutConfirm = true }
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
        }
    }
}
