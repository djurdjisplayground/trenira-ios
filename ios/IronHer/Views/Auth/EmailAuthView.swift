import SwiftUI

private enum EmailAuthMode: String, CaseIterable, Identifiable {
    case signIn
    case createAccount

    var id: String { rawValue }
}

struct EmailAuthView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    @State private var mode: EmailAuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    modePicker
                    formSection
                    actionButton
                }
                .padding(.horizontal, IronHerTheme.screenPadding)
                .padding(.vertical, 24)
            }
            .background(IronHerTheme.background)
            .navigationTitle(l10n.t(.email))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(l10n.t(.cancel)) { dismiss() }
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
            .onChange(of: authManager.canAccessApp) { _, canAccess in
                if canAccess { dismiss() }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrandLockup(markSize: 40, nameSize: 20, taglineSize: 13, axis: .horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text(mode == .signIn ? l10n.t(.welcome_back) : l10n.t(.create_your_account))
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(l10n.t(.save_workouts_progress))
                    .font(SheLiftsFont.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(EmailAuthMode.allCases) { option in
                Text(title(for: option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in
            authManager.errorMessage = nil
        }
    }

    private var formSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t(.email))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                TextField("you@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .padding(14)
                    .background(IronHerTheme.groupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t(.password))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                SecureField("At least 8 characters", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    .focused($focusedField, equals: .password)
                    .padding(14)
                    .background(IronHerTheme.groupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
            }

            if authManager.isAuthenticating {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }

            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var actionButton: some View {
        Button {
            submit()
        } label: {
            Text(mode == .signIn ? l10n.t(.continue_with_email) : l10n.t(.create_account))
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSubmit || authManager.isAuthenticating)
    }

    private func title(for mode: EmailAuthMode) -> String {
        switch mode {
        case .signIn: return l10n.t(.sign_in)
        case .createAccount: return l10n.t(.create_account)
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 8
    }

    private func submit() {
        switch mode {
        case .signIn:
            authManager.signInWithEmail(email: email, password: password)
        case .createAccount:
            authManager.createAccountWithEmail(email: email, password: password)
        }
    }
}

#Preview {
    EmailAuthView()
        .environment(AuthenticationManager())
        .environment(LocalizationStore())
}
