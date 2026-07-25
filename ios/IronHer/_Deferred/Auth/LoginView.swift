import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.rose50,
                    Color.white,
                    Color.rose50.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                IronHerLogoView(size: 110)

                VStack(spacing: 8) {
                    Text("Create an account")
                        .font(.title2.bold())
                        .foregroundStyle(Color.slate850)

                    Text("Save your workouts and sync across devices.")
                        .font(.subheadline)
                        .foregroundStyle(Color.slate500)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 28)

                Spacer()

                VStack(spacing: 12) {
                    if authManager.isAuthenticating {
                        ProgressView()
                    }

                    Text(authManager.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.slate500)
                        .multilineTextAlignment(.center)

                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    AuthOptionButton(title: "Sign in with Apple", style: .apple) {
                        authManager.signInWithApple()
                    }
                    .disabled(authManager.isAuthenticating)
                    .opacity(authManager.isAuthenticating ? 0.6 : 1)

                    AuthOptionButton(title: "Continue with Google", style: .google) {
                        authManager.signInWithGoogle()
                    }
                    .disabled(authManager.isAuthenticating)
                    .opacity(authManager.isAuthenticating ? 0.6 : 1)

                    Button("Skip for now") {
                        authManager.continueAsGuest()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.slate500)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthenticationManager())
}
