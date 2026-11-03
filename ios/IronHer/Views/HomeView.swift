import SwiftUI

/// Supportive home for the movement companion. Strength workouts stay one step away.
struct HomeView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(UserDataCoordinator.self) private var dataCoordinator
    @Environment(AppTabRouter.self) private var tabRouter
    @Environment(WorkoutSessionStore.self) private var sessionStore

    @State private var showSignOutConfirm = false
    @State private var showCompanionSetup = false
    @State private var showToday = false
    @State private var showWalk = false
    @State private var profile = CompanionProfileStore.load()
    @State private var historyRevision = 0

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
                if profile == nil || profile?.hasAnswers != true {
                    setupCard
                }
                findMovement
                weekCard
                links
                strengthCard
            }
            .padding(.horizontal, TreniraSpace.screen)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(TreniraColor.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BrandLogoMark(size: 24)
            }
            ToolbarItem(placement: .topBarTrailing) {
                authToolbarButton
            }
        }
        .sheet(isPresented: $showToday, onDismiss: { historyRevision += 1 }) {
            NavigationStack {
                MovementCheckInView {
                    showToday = false
                    historyRevision += 1
                }
            }
        }
        .sheet(isPresented: $showWalk, onDismiss: { historyRevision += 1 }) {
            NavigationStack {
                MovementWalkView(ownerId: dataCoordinator.currentOwner.rawValue) {
                    showWalk = false
                    historyRevision += 1
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
            Text("Your workouts stay on this device.")
        }
        .onAppear {
            profile = CompanionProfileStore.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(TreniraType.largeTitle)
                .foregroundStyle(TreniraColor.label)
                .accessibilityAddTraits(.isHeader)
            Text(profile?.goal?.homeLine ?? "Movement can fit the day you have.")
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
            Text("A few answers help trenira choose a realistic next step. You can skip or change them later.")
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)
            Button("Answer a few questions") {
                showCompanionSetup = true
            }
            .buttonStyle(TreniraSecondaryButtonStyle())
        }
        .treniraCard()
    }

    private var findMovement: some View {
        Button {
            showToday = true
        } label: {
            Text("Find movement for today")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(TreniraPrimaryButtonStyle())
        .accessibilityHint("Opens a short check-in for time, energy, and place")
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This week")
                .font(TreniraType.section)
                .foregroundStyle(TreniraColor.label)
            HStack(spacing: 8) {
                ForEach(weekdays, id: \.title) { day in
                    VStack(spacing: 6) {
                        Text(day.title)
                            .font(TreniraType.caption)
                            .foregroundStyle(TreniraColor.labelSecondary)
                        Circle()
                            .fill(day.isToday ? TreniraColor.action : TreniraColor.surface)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if day.isToday {
                                    Circle().stroke(TreniraColor.action, lineWidth: 0)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(day.isToday ? "\(day.title), today" : day.title)
                }
            }
            Text(weekLine)
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .treniraCard()
        .accessibilityElement(children: .combine)
    }

    private var links: some View {
        VStack(alignment: .leading, spacing: TreniraSpace.stack) {
            NavigationLink {
                MovementHistoryView(
                    ownerId: dataCoordinator.currentOwner.rawValue,
                    strengthLogs: strengthSnapshots
                )
            } label: {
                Text("Movement history")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TreniraSecondaryButtonStyle())

            NavigationLink {
                SavedVideosView(ownerId: dataCoordinator.currentOwner.rawValue)
            } label: {
                Text("Saved videos")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TreniraSecondaryButtonStyle())

            Button("Record a walk") { showWalk = true }
                .buttonStyle(TreniraSecondaryButtonStyle())
        }
        .id(historyRevision)
    }

    private var strengthSnapshots: [StrengthHistorySnapshot] {
        sessionStore.performanceLogs.map {
            StrengthHistorySnapshot(id: $0.id, title: $0.workoutName, completedAt: $0.completedAt)
        }
    }

    private var weekLine: String {
        let summary = MovementJournal.weekSummary(items: MovementJournal.items(
            records: MovementRecordStore.load(ownerId: dataCoordinator.currentOwner.rawValue),
            strengthLogs: strengthSnapshots
        ))
        return MovementJournal.weekLine(summary)
    }

    private var strengthCard: some View {
        Button {
            tabRouter.openMyWorkouts()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your strength workouts")
                    .font(TreniraType.section)
                    .foregroundStyle(TreniraColor.label)
                Text(strengthDetail)
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .treniraCard()
        .accessibilityHint("Opens your saved strength workouts")
    }

    private var strengthDetail: String {
        if sessionStore.activeSession != nil {
            return "A session is still open. You can continue it whenever you want."
        }
        return "Your saved workouts, history, and equipment are still here."
    }

    private var weekdays: [(title: String, isToday: Bool)] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let today = calendar.component(.weekday, from: .now)
        return symbols.enumerated().map { index, symbol in
            (title: symbol, isToday: index + 1 == today)
        }
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
