import SwiftUI

/// Screen 2 — welcome and authentication.
struct WelcomeAuthView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(LocalizationStore.self) private var l10n

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

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if authManager.statusMessage == l10n.t(.local_data_erased)
                    || authManager.statusMessage == "Local data erased." {
                    Text(l10n.t(.local_data_erased))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
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

                earlyBetaNotice
                    .padding(.top, 4)
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 36)
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
    }

    private var earlyBetaNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "internaldrive")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(IronHerTheme.secondaryText)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.t(.early_beta_title))
                    .font(SheLiftsFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(l10n.t(.early_beta_notice))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(IronHerTheme.groupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous)
                .stroke(IronHerTheme.separator.opacity(0.45), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeAuthView()
        .environment(AuthenticationManager())
        .environment(LocalizationStore())
}
