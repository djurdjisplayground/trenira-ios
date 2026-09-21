import SwiftUI

/// First-launch journey after Welcome / sign-in. Existing users with a stored
/// completion flag (or migrated workout data) never see this.
struct FirstLaunchOnboardingView: View {
    var onFinished: () -> Void

    @Environment(AppTabRouter.self) private var tabRouter

    @State private var step: Step = .intro

    private enum Step: Equatable {
        case intro
        case approach
        case create
        case generate
        case calibrationOffer
        case calibrationSession
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .intro:
                    OnboardingView(isPreview: true, continueTitle: "Continue") {
                        step = .approach
                    }
                case .approach:
                    trainingApproach
                case .create:
                    CreateWorkoutView(
                        onSaved: { step = .calibrationOffer },
                        onSkip: { step = .calibrationOffer },
                        onBack: { step = .approach }
                    )
                case .generate:
                    GenerateWorkoutView(
                        onSaved: { step = .calibrationOffer },
                        onSkip: { step = .calibrationOffer },
                        onBack: { step = .approach }
                    )
                case .calibrationOffer:
                    calibrationOffer
                case .calibrationSession:
                    WeightCalibrationFlowView(
                        onExit: { completed in
                            if completed {
                                finishOnboarding(openWorkouts: false)
                            } else {
                                finishOnboarding(openWorkouts: true)
                            }
                        },
                        onBackToPrevious: {
                            step = .calibrationOffer
                        }
                    )
                }
            }
        }
        .background(IronHerTheme.background.ignoresSafeArea())
    }

    private var trainingApproach: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("How do you want to train?")
                        .font(SheLiftsFont.title)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .accessibilityAddTraits(.isHeader)

                    approachCard(
                        title: "I already have a workout",
                        subtitle: "Add your existing routine and trenira will help you track and progress it."
                    ) {
                        step = .create
                    }

                    approachCard(
                        title: "Create a workout for me",
                        subtitle: "Tell trenira how you train and we’ll build your workout."
                    ) {
                        step = .generate
                    }
                }
                .padding(.horizontal, IronHerTheme.screenPadding)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }

            Button("Back") {
                step = .intro
            }
            .buttonStyle(OutlineButtonStyle())
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 28)
        }
        .background(IronHerTheme.background.ignoresSafeArea())
    }

    private func approachCard(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
                Text(subtitle)
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(IronHerTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                    .stroke(IronHerTheme.separator.opacity(0.55), lineWidth: 0.5)
            }
        }
        .buttonStyle(SheLiftsPressStyle())
    }

    private var calibrationOffer: some View {
        VStack(spacing: 0) {
            ScrollView {
                StrengthSetupPromptCard(
                    onStart: { step = .calibrationSession },
                    onMaybeLater: { finishOnboarding(openWorkouts: true) },
                    showsActions: false
                )
                .padding(.horizontal, IronHerTheme.screenPadding)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                Button("Start strength setup") {
                    step = .calibrationSession
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Maybe later") {
                    finishOnboarding(openWorkouts: true)
                }
                .buttonStyle(OutlineButtonStyle())
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 28)
        }
        .background(IronHerTheme.background.ignoresSafeArea())
    }

    private func finishOnboarding(openWorkouts: Bool) {
        OnboardingStore.markCompleted()
        if openWorkouts {
            tabRouter.openMyWorkouts()
        }
        onFinished()
    }
}

#Preview {
    FirstLaunchOnboardingView(onFinished: {})
        .environment(AppTabRouter())
        .environment(WorkoutStore())
        .environment(WeightHistoryStore())
        .environment(UserSettingsStore())
        .environment(SubscriptionStore())
        .environment(StrengthCalibrationStore())
        .environment(GlobalExerciseProgressStore())
        .environment(LocalizationStore())
        .environment(CustomExerciseStore())
}
