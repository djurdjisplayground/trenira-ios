import SwiftUI

/// Silent looping procedural demonstration — refined female silhouette,
/// equipment-accurate props, static camera. Media loads only when shown.
struct ProceduralExerciseDemonstrationView: View {
    let demonstration: ExerciseDemonstration

    @State private var isPlaying = true
    @State private var showPauseHint = false
    @State private var pausedPhase: CGFloat = 0

    /// Slow teaching tempo with brief end holds (≈5.6s full loop).
    private let loopDuration: TimeInterval = 5.6

    var body: some View {
        ZStack {
            demonstrationBackground

            TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
                let phase = isPlaying ? loopPhase(at: context.date) : pausedPhase
                Canvas { context, size in
                    DemonstrationFigureDrawing.draw(
                        in: context,
                        size: size,
                        demonstration: demonstration,
                        phase: phase
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if DevelopmentConfig.isDevelopmentMode, demonstration.quality == .needsRefinement {
                VStack {
                    HStack {
                        Text("DEV · refine")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(IronHerTheme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(IronHerTheme.cardBackground.opacity(0.9))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(10)
                .allowsHitTesting(false)
            }

            Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(IronHerTheme.primaryText.opacity(showPauseHint || !isPlaying ? 0.75 : 0))
                .animation(.easeOut(duration: 0.2), value: showPauseHint || !isPlaying)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 248)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                .stroke(IronHerTheme.separator.opacity(0.45), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .onTapGesture(perform: togglePlayback)
        .accessibilityLabel(isPlaying ? "Pause demonstration" : "Play demonstration")
        .accessibilityAddTraits(.isButton)
    }

    private var demonstrationBackground: some View {
        LinearGradient(
            colors: [
                IronHerTheme.cardBackground,
                IronHerTheme.groupedBackground.opacity(0.55),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Controlled tempo with soft holds at the start and end positions.
    private func loopPhase(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: loopDuration) / loopDuration

        // 0–8% hold start, 8–46% concentric, 46–54% hold end, 54–92% eccentric, 92–100% hold.
        let travel: CGFloat
        if t < 0.08 {
            travel = 0
        } else if t < 0.46 {
            travel = CGFloat((t - 0.08) / 0.38)
        } else if t < 0.54 {
            travel = 1
        } else if t < 0.92 {
            travel = 1 - CGFloat((t - 0.54) / 0.38)
        } else {
            travel = 0
        }
        return smoothstep(travel)
    }

    private func smoothstep(_ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }

    private func togglePlayback() {
        if isPlaying {
            pausedPhase = loopPhase(at: Date())
            isPlaying = false
            showPauseHint = true
        } else {
            isPlaying = true
            showPauseHint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showPauseHint = false
            }
        }
    }
}
