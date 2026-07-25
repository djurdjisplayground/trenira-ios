import SwiftUI

struct WorkoutPickerSection: View {
    let title: String
    let workouts: [Workout]
    let selectedWorkoutId: UUID?
    let emptyMessage: String
    let onSelect: (Workout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            if workouts.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else {
                ForEach(workouts) { workout in
                    Button {
                        onSelect(workout)
                    } label: {
                        HStack {
                            Text(workout.name)
                                .foregroundStyle(IronHerTheme.primaryText)
                            Spacer()
                            if selectedWorkoutId == workout.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(IronHerTheme.primaryText)
                            }
                        }
                        .padding(14)
                        .background(IronHerTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                                .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct WorkoutAdaptationProposalsSection: View {
    let proposals: [WorkoutAdaptationProposal]
    let actionTitle: String
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let swapCount = proposals.filter(\.isVarietySwap).count

            Text("Suggested changes")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            Text("\(swapCount) exercise\(swapCount == 1 ? "" : "s") updated · sets, reps & weights stay the same")
                .font(.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            ForEach(proposals) { proposal in
                VStack(alignment: .leading, spacing: 6) {
                    if proposal.isVarietySwap {
                        Text("\(proposal.originalName) → \(proposal.proposedName)")
                            .font(.body.weight(.medium))
                            .foregroundStyle(IronHerTheme.primaryText)
                        Text("\(proposal.proposedEquipment) · \(proposal.sets)×\(proposal.reps)")
                            .font(.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    } else {
                        Text(proposal.proposedName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(IronHerTheme.primaryText)
                        Text("Best available match · \(proposal.proposedEquipment)")
                            .font(.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(IronHerTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: onApply) {
                Text(actionTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}
