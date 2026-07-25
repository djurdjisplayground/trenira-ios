import SwiftUI

struct DraftExerciseRow: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore

    let draft: DraftWorkoutExercise
    var onTap: (() -> Void)? = nil
    let onDelete: () -> Void

    private var resolvedUnit: WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: draft.exercise.id,
            defaultUnit: settingsStore.weightUnit
        )
    }

    var body: some View {
        HStack(spacing: 14) {
            if draft.exercise.hasVisualAsset {
                ExerciseThumbnailView(exercise: draft.exercise, size: 52)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.exercise.name)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(
                    ExerciseTrackingFormatter.summary(
                        exercise: draft.exercise,
                        sets: draft.sets,
                        reps: draft.reps,
                        weightKg: draft.startingWeight,
                        durationSeconds: draft.durationSeconds,
                        distanceMeters: draft.distanceMeters,
                        weightUnit: resolvedUnit
                    )
                )
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

                Text(draft.exercise.listSubtitle)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Spacer(minLength: 0)

            if onTap != nil {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(IronHerTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .onTapGesture {
            onTap?()
        }
    }
}

#Preview {
    DraftExerciseRow(
        draft: DraftWorkoutExercise(
            exercise: ExerciseCatalog.all[0],
            sets: 3,
            reps: 10,
            startingWeight: 40
        ),
        onDelete: {}
    )
    .padding()
    .environment(UserSettingsStore())
    .environment(GlobalExerciseProgressStore())
}
