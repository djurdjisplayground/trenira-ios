import SwiftUI

/// Compact rest countdown shown under the active exercise card.
struct RestTimerBar: View {
    let controller: RestTimerController
    var onPause: () -> Void
    var onResume: () -> Void
    var onSkip: () -> Void
    var onAdd15: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                    if let name = controller.activeExerciseName, !name.isEmpty {
                        Text("Rest after \(name)")
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                }
                Spacer()
                Text(timeLabel)
                    .font(SheLiftsFont.title)
                    .monospacedDigit()
                    .foregroundStyle(
                        controller.didComplete && controller.remainingSeconds == 0 && !controller.isRunning
                            ? IronHerTheme.accent
                            : IronHerTheme.primaryText
                    )
            }

            HStack(spacing: 10) {
                if controller.isPaused {
                    Button("Resume", action: onResume)
                        .buttonStyle(OutlineButtonStyle())
                } else if controller.isRunning {
                    Button("Pause", action: onPause)
                        .buttonStyle(OutlineButtonStyle())
                }

                Button("+15 sec", action: onAdd15)
                    .buttonStyle(OutlineButtonStyle())

                Button("Skip", action: onSkip)
                    .buttonStyle(OutlineButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IronHerTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
    }

    private var statusTitle: String {
        if controller.didComplete, controller.remainingSeconds == 0, !controller.isRunning, !controller.isPaused {
            return "Rest complete"
        }
        if controller.isPaused {
            return "Rest paused"
        }
        return "Rest"
    }

    private var timeLabel: String {
        let total = max(0, controller.remainingSeconds)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
