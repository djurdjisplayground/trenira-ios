import SwiftUI

/// Destructive erase of all Trenira data stored on this device.
/// Does not delete the user's Apple ID or Google account.
struct EraseLocalDataView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(UserDataCoordinator.self) private var dataCoordinator
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    @State private var confirmText = ""
    @State private var showFirstConfirm = false
    @State private var passedFirstConfirm = false
    @State private var isErasing = false
    @State private var errorMessage: String?

    private var confirmationPhrase: String { "DELETE" }

    private var canErase: Bool {
        passedFirstConfirm
            && confirmText.trimmingCharacters(in: .whitespacesAndNewlines) == confirmationPhrase
            && !isErasing
    }

    var body: some View {
        Form {
            Section {
                Text(l10n.t(.erase_local_data_title))
                    .font(SheLiftsFont.title)
                    .foregroundStyle(.red)

                Text(l10n.t(.erase_local_data_body))
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.primaryText)
            }

            if passedFirstConfirm {
                Section {
                    Text(l10n.t(.erase_local_data_type_delete))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)

                    TextField(confirmationPhrase, text: $confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(SheLiftsFont.body)
                } footer: {
                    Text(l10n.t(.erase_local_data_footer))
                        .font(SheLiftsFont.caption)
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
                            Text(l10n.t(.erase_local_data))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                } else {
                    Button(role: .destructive) {
                        Task { await performErasure() }
                    } label: {
                        HStack {
                            Spacer()
                            if isErasing {
                                ProgressView()
                            } else {
                                Text(l10n.t(.erase_data))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canErase)
                }

                Button(l10n.t(.cancel), role: .cancel) {
                    dismiss()
                }
            }
        }
        .navigationTitle(l10n.t(.erase_local_data))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            l10n.t(.erase_local_data_confirm_title),
            isPresented: $showFirstConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.continue_action), role: .destructive) {
                passedFirstConfirm = true
            }
            Button(l10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(l10n.t(.erase_local_data_confirm_message))
        }
        .interactiveDismissDisabled(isErasing)
    }

    private func performErasure() async {
        errorMessage = nil
        isErasing = true
        defer { isErasing = false }

        do {
            try await authManager.eraseAllLocalData(dataCoordinator: dataCoordinator)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        EraseLocalDataView()
            .environment(AuthenticationManager())
            .environment(
                UserDataCoordinator(
                    workoutStore: WorkoutStore(),
                    historyStore: WeightHistoryStore(),
                    sessionStore: WorkoutSessionStore(),
                    customExerciseStore: CustomExerciseStore(),
                    progressionStore: ExerciseProgressionStore(),
                    globalProgressStore: GlobalExerciseProgressStore(),
                    settingsStore: UserSettingsStore()
                )
            )
            .environment(LocalizationStore())
    }
}
