import SwiftUI

/// Permanent deletion of trenira account data on this device.
/// Does not delete the user's Apple ID or Google Account.
struct DeleteAccountView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(UserDataCoordinator.self) private var dataCoordinator
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    @State private var confirmText = ""
    @State private var showFirstConfirm = false
    @State private var passedFirstConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var confirmationPhrase: String { "DELETE" }

    private var canDelete: Bool {
        passedFirstConfirm
            && confirmText.trimmingCharacters(in: .whitespacesAndNewlines) == confirmationPhrase
            && !isDeleting
    }

    private var clarifiesExternalAccounts: Bool {
        switch authManager.authState {
        case .apple, .google:
            true
        case .guest, .signedOut:
            false
        }
    }

    var body: some View {
        Form {
            Section {
                Text(l10n.t(.delete_account_title))
                    .font(SheLiftsFont.title)
                    .foregroundStyle(.red)

                Text(l10n.t(.delete_account_body))
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.primaryText)

                if clarifiesExternalAccounts {
                    Text(l10n.t(.delete_account_provider_note))
                        .font(SheLiftsFont.body)
                        .foregroundStyle(IronHerTheme.primaryText)
                }
            }

            if passedFirstConfirm {
                Section {
                    Text(l10n.t(.delete_account_type_delete))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)

                    TextField(confirmationPhrase, text: $confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(SheLiftsFont.body)
                } footer: {
                    if clarifiesExternalAccounts {
                        Text(l10n.t(.delete_account_footer))
                            .font(SheLiftsFont.caption)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if !passedFirstConfirm {
                    Button(role: .destructive) {
                        showFirstConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(l10n.t(.delete_account))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                } else {
                    Button(role: .destructive) {
                        Task { await performDeletion() }
                    } label: {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                            } else {
                                Text(l10n.t(.delete_account))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canDelete)
                }

                Button(l10n.t(.cancel), role: .cancel) {
                    dismiss()
                }
            }
        }
        .navigationTitle(l10n.t(.delete_account))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            l10n.t(.delete_account_confirm_title),
            isPresented: $showFirstConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.continue_action), role: .destructive) {
                passedFirstConfirm = true
            }
            Button(l10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(l10n.t(.delete_account_confirm_message))
        }
        .interactiveDismissDisabled(isDeleting)
    }

    private func performDeletion() async {
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await authManager.deleteAccount(dataCoordinator: dataCoordinator)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
            .environment(AuthenticationManager())
            .environment(
                UserDataCoordinator(
                    workoutStore: WorkoutStore(),
                    historyStore: WeightHistoryStore(),
                    sessionStore: WorkoutSessionStore(),
                    customExerciseStore: CustomExerciseStore(),
                    progressionStore: ExerciseProgressionStore(),
                    globalProgressStore: GlobalExerciseProgressStore(),
                    calibrationStore: StrengthCalibrationStore(),
                    settingsStore: UserSettingsStore()
                )
            )
            .environment(LocalizationStore())
    }
}
