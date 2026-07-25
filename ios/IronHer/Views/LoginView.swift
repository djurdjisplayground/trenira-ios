import SwiftUI

/// Screen 2 — welcome and authentication.
struct WelcomeAuthView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(LocalizationStore.self) private var l10n

    @State private var showEmailAuth = false
    @State private var contentOpacity = 0.0
    @State private var contentOffset: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                BrandLockup(markSize: 38, nameSize: 22, taglineSize: 12)

                Text(l10n.t(.welcome_sign_in_prompt))
                    .font(SheLiftsFont.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)

            Spacer()

            VStack(spacing: 12) {
                if authManager.isAuthenticating {
                    ProgressView()
                        .padding(.bottom, 4)
                }

                if let errorMessage = authManager.errorMessage, !showEmailAuth {
                    Text(errorMessage)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                AuthOptionButton(title: l10n.t(.continue_with_apple), style: .apple) {
                    authManager.signInWithApple()
                }
                .disabled(authManager.isAuthenticating)

                AuthOptionButton(title: l10n.t(.continue_with_google), style: .google) {
                    authManager.signInWithGoogle()
                }
                .disabled(authManager.isAuthenticating)

                AuthOptionButton(title: l10n.t(.continue_with_email), style: .email) {
                    authManager.errorMessage = nil
                    showEmailAuth = true
                }
                .disabled(authManager.isAuthenticating)

                Button {
                    authManager.continueAsGuest()
                } label: {
                    Text(l10n.t(.continue_as_guest))
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(SheLiftsPressStyle())
                .disabled(authManager.isAuthenticating)
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 52)
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IronHerTheme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.08)) {
                contentOpacity = 1
                contentOffset = 0
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
        }
        .onChange(of: authManager.canAccessApp) { _, canAccess in
            if canAccess {
                showEmailAuth = false
            }
        }
    }
}

#Preview {
    WelcomeAuthView()
        .environment(AuthenticationManager())
        .environment(LocalizationStore())
}
