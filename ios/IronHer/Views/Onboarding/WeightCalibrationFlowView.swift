import SwiftUI

/// Gym-session logging for starting weights. Saves each exercise immediately.
struct WeightCalibrationFlowView: View {
    /// `true` when the user finished every step; `false` when they deferred.
    var onExit: (Bool) -> Void
    /// Back from the first exercise. Defaults to deferring (`onExit(false)`).
    var onBackToPrevious: (() -> Void)? = nil

    @Environment(StrengthCalibrationStore.self) private var calibrationStore
    @Environment(UserSettingsStore.self) private var settingsStore

    @State private var step: Step = .exercise(0)
    @State private var weightText = ""
    @State private var repsText = "10"
    @State private var effort: CalibrationEffort?

    private var unit: WeightUnit { settingsStore.weightUnit }
    private var exercises: [Exercise] { StrengthCalibrationCatalog.exercises }

    private enum Step: Equatable {
        case exercise(Int)
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case .exercise(let index):
                        if exercises.indices.contains(index) {
                            exerciseContent(exercises[index], index: index)
                        }
                    case .done:
                        doneContent
                    }
                }
                .padding(.horizontal, IronHerTheme.screenPadding)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                footerButtons
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 28)
            .padding(.top, 8)
        }
        .background(IronHerTheme.background.ignoresSafeArea())
        .onAppear {
            if case .exercise(let index) = step {
                loadFields(for: index)
            }
        }
        .onChange(of: step) { _, newValue in
            if case .exercise(let index) = newValue {
                loadFields(for: index)
            }
        }
    }

    private func exerciseContent(_ exercise: Exercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Exercise \(index + 1) of \(exercises.count)")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            Text(exercise.name)
                .font(SheLiftsFont.title)
                .foregroundStyle(IronHerTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text("Choose a challenging weight and perform 8–12 controlled reps.")
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Stop when you feel you could only complete another 1–2 reps with good form.")
                .font(SheLiftsFont.body)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Weight (\(unit.shortLabel))")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(SheLiftsFont.bodyMedium)
                    .padding(14)
                    .background(IronHerTheme.groupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Reps")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                TextField("10", text: $repsText)
                    .keyboardType(.numberPad)
                    .font(SheLiftsFont.bodyMedium)
                    .padding(14)
                    .background(IronHerTheme.groupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("How did that feel?")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                HStack(spacing: 8) {
                    ForEach(CalibrationEffort.allCases) { option in
                        Button {
                            effort = option
                        } label: {
                            Text(option.label)
                                .font(SheLiftsFont.caption)
                                .foregroundStyle(
                                    effort == option ? IronHerTheme.accentForeground : IronHerTheme.primaryText
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(effort == option ? IronHerTheme.accent : IronHerTheme.groupedBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your starting weights are ready.")
                .font(SheLiftsFont.title)
                .foregroundStyle(IronHerTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text("trenira will use these results to estimate starting weights across your exercises, including ones you did not test. After that, your training history takes over.")
                .font(SheLiftsFont.body)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        switch step {
        case .exercise(let index):
            Button("Next exercise") {
                saveCurrent(index: index)
                advance(from: index)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSaveCurrent)

            Button("Skip exercise") {
                calibrationStore.skipExercise(id: exercises[index].id)
                advance(from: index)
            }
            .buttonStyle(OutlineButtonStyle())

            HStack {
                Button("Back") {
                    goBack(from: index)
                }
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

                Spacer()

                Button("Save and finish later") {
                    if canSaveCurrent {
                        saveCurrent(index: index)
                    }
                    onExit(false)
                }
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
            }

        case .done:
            Button("Continue") {
                calibrationStore.markFlowFinishedOrSkipped()
                onExit(true)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var canSaveCurrent: Bool {
        parsedWeightKg != nil && parsedReps != nil
    }

    private var parsedWeightKg: Double? {
        let normalized = weightText.replacingOccurrences(of: ",", with: ".")
        guard let display = Double(normalized), display > 0 else { return nil }
        return WeightFormatter.kilograms(from: display, unit: unit)
    }

    private var parsedReps: Int? {
        guard let reps = Int(repsText.trimmingCharacters(in: .whitespaces)), (1...50).contains(reps) else {
            return nil
        }
        return reps
    }

    private func loadFields(for index: Int) {
        guard exercises.indices.contains(index) else { return }
        let exercise = exercises[index]
        if let existing = calibrationStore.calibration(for: exercise.id) {
            weightText = WeightFormatter.formatNumber(kg: existing.weightKg, unit: unit)
            repsText = "\(existing.reps)"
            effort = existing.effort
        } else {
            weightText = ""
            repsText = "10"
            effort = nil
        }
    }

    private func saveCurrent(index: Int) {
        guard exercises.indices.contains(index),
              let weightKg = parsedWeightKg,
              let reps = parsedReps else { return }
        calibrationStore.saveCalibration(
            exerciseId: exercises[index].id,
            weightKg: weightKg,
            reps: reps,
            effort: effort
        )
    }

    private func advance(from index: Int) {
        let next = index + 1
        if next < exercises.count {
            step = .exercise(next)
        } else {
            step = .done
        }
    }

    private func goBack(from index: Int) {
        if index == 0 {
            if let onBackToPrevious {
                onBackToPrevious()
            } else {
                onExit(false)
            }
        } else {
            step = .exercise(index - 1)
        }
    }
}

#Preview {
    WeightCalibrationFlowView(onExit: { _ in })
        .environment(StrengthCalibrationStore())
        .environment(UserSettingsStore())
}
