import SwiftUI

/// Calm exercise details: optional licensed demo, muscles, equipment, and concise cues.
/// Used from the Exercise Library and optionally via an info icon during workouts.
///
/// Demonstrations appear only when a bundled licensed loop exists for the exercise ID.
/// No AI animations, placeholders, or inaccurate substitutes.
struct ExerciseDetailsView: View {
    @Environment(LocalizationStore.self) private var l10n

    let exercise: Exercise
    /// When true, offers a link into progression / unit settings for this exercise.
    var showsSettingsLink: Bool = false

    private var formCopy: ExerciseDemonstrationLocalizations.FormCopy? {
        ExerciseDemonstrationLocalizations.formCopy(for: exercise.id, language: l10n.language)
    }

    private var showsDemonstration: Bool {
        exercise.demonstration.demonstrationAvailable
    }

    private var equipmentLabel: String {
        if exercise.requiredEquipment.isEmpty {
            return exercise.equipment.label
        }
        let detail = exercise.requiredEquipment.map(\.label).joined(separator: ", ")
        return detail.isEmpty ? exercise.equipment.label : detail
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(exercise.localizedName(using: l10n))
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if showsDemonstration {
                    ExerciseDemonstrationView(exercise: exercise)
                }

                metadataSection

                if let formCopy, !formCopy.cues.isEmpty {
                    cuesSection(formCopy)
                }

                if showsSettingsLink {
                    NavigationLink {
                        ExerciseDetailSettingsView(exercise: exercise)
                    } label: {
                        Text(l10n.t(.exercise_details_progression_link))
                            .font(SheLiftsFont.bodyMedium)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, showsDemonstration ? 20 : 16)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(IronHerTheme.background.ignoresSafeArea())
        .navigationTitle(l10n.t(.exercise_details_title))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailRow(l10n.t(.exercise_details_primary_muscle), exercise.primaryMuscleGroup.label)

            if !exercise.secondaryMuscleGroups.isEmpty {
                detailRow(
                    l10n.t(.exercise_details_secondary_muscles),
                    exercise.secondaryMuscleGroups.map(\.label).joined(separator: ", ")
                )
            }

            detailRow(l10n.t(.exercise_details_equipment), equipmentLabel)
        }
    }

    private func cuesSection(_ copy: ExerciseDemonstrationLocalizations.FormCopy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l10n.t(.exercise_details_technique))
                .font(SheLiftsFont.section)
                .foregroundStyle(IronHerTheme.primaryText)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(copy.cues.enumerated()), id: \.offset) { _, cue in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(IronHerTheme.secondaryText.opacity(0.45))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(cue)
                            .font(SheLiftsFont.body)
                            .foregroundStyle(IronHerTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let mistake = copy.commonMistake {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n.t(.exercise_details_common_mistake))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                    Text(mistake)
                        .font(SheLiftsFont.body)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
            Text(value)
                .font(SheLiftsFont.body)
                .foregroundStyle(IronHerTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("With / without demo") {
    NavigationStack {
        ExerciseDetailsView(
            exercise: ExerciseCatalog.exercise(id: "dumbbell-shoulder-press")
                ?? ExerciseDatabase.all[0],
            showsSettingsLink: true
        )
    }
    .environment(LocalizationStore())
}
