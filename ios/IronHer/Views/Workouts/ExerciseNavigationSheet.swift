import SwiftUI

struct ExerciseNavigationSheet: View {
    let hasNextExercise: Bool
    var nextProgressionSummary: String? = nil
    let onNext: () -> Void
    let onChoose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("Exercise complete")
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.primaryText)

                if let nextProgressionSummary {
                    Text(nextProgressionSummary)
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .multilineTextAlignment(.center)
                }

                Text("Continue in order, or pick another movement if equipment is busy.")
                    .font(SheLiftsFont.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                if hasNextExercise {
                    Button("Next Exercise", action: onNext)
                        .buttonStyle(PrimaryButtonStyle())

                    Button("Choose Another Exercise", action: onChoose)
                        .buttonStyle(OutlineButtonStyle())
                } else {
                    Button("Choose Another Exercise", action: onChoose)
                        .buttonStyle(PrimaryButtonStyle())
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
