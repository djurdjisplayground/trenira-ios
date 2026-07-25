import SwiftUI

struct ExerciseNavigationSheet: View {
    let hasNextExercise: Bool
    var nextProgressionSummary: String? = nil
    let onNext: () -> Void
    let onFinish: () -> Void
    var onChoose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("Exercise complete ✓")
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.primaryText)

                if let nextProgressionSummary {
                    Text(nextProgressionSummary)
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                if hasNextExercise {
                    Button("Next Exercise →", action: onNext)
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Finish Workout", action: onFinish)
                        .buttonStyle(PrimaryButtonStyle())
                }

                if let onChoose {
                    Button("Exercises", action: onChoose)
                        .buttonStyle(OutlineButtonStyle())
                }
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .background(IronHerTheme.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
