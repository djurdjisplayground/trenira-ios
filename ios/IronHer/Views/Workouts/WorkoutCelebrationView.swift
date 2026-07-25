import SwiftUI

struct WorkoutCelebrationView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n

    let message: String
    let onDone: () -> Void
    var onReopen: (() -> Void)? = nil

    @State private var contentOpacity = 0.0
    @State private var checkScale = 0.82
    @State private var ringOpacity = 0.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(IronHerTheme.separator, lineWidth: 0.5)
                        .frame(width: 96, height: 96)
                        .opacity(ringOpacity)

                    Text("🎉")
                        .font(.system(size: 36))
                        .scaleEffect(checkScale)
                }

                VStack(spacing: 14) {
                    Text(l10n.t(.workout_complete))
                        .font(SheLiftsFont.largeTitle)
                        .foregroundStyle(IronHerTheme.primaryText)

                    Text(message)
                        .font(SheLiftsFont.body)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
            .opacity(contentOpacity)
            .padding(.horizontal, IronHerTheme.screenPadding)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onDone) {
                    Text(l10n.t(.back_to_home))
                }
                .buttonStyle(PrimaryButtonStyle())

                if settingsStore.showsReopenWorkoutButton, let onReopen {
                    Button(action: onReopen) {
                        Text("Reopen Workout (Development Only)")
                    }
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 40)
            .opacity(contentOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IronHerTheme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1
                checkScale = 1
                ringOpacity = 1
            }
        }
    }
}
