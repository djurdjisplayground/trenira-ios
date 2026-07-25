import SwiftUI

/// Informational full-screen after an automatic progression update.
struct ProgressionUpdateView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore

    let update: AppliedProgressionUpdate
    let onContinue: () -> Void

    @State private var contentOpacity = 0.0

    private var displayUnit: WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: update.exerciseId,
            defaultUnit: settingsStore.weightUnit
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Text(update.headline)
                    .font(SheLiftsFont.largeTitle)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(update.completedTargetLabel)
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Text("Your next workout:")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)

                    Text(nextWorkoutLine)
                        .font(SheLiftsFont.title)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text("Great work. Your progression has been updated.")
                        .font(SheLiftsFont.body)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .opacity(contentOpacity)

            Spacer()

            VStack(spacing: 12) {
                BrandTagline(size: 13)

                Button("Continue", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 40)
            .opacity(contentOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IronHerTheme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                contentOpacity = 1
            }
        }
    }

    private var nextWorkoutLine: String {
        var parts: [String] = []
        if let weight = update.nextWeightKg, weight > 0 {
            parts.append(WeightFormatter.format(kg: weight, unit: displayUnit))
        }
        parts.append("\(update.targetSets) sets")
        if let reps = update.nextReps {
            parts.append("\(reps) reps")
        }
        if let duration = update.nextDurationSeconds {
            parts.append(ExerciseTrackingFormatter.formatDuration(seconds: duration))
        }
        return parts.joined(separator: " × ")
    }
}
