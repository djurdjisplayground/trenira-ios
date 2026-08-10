import SwiftUI

struct ConsultationRequestFormView: View {
    @Binding var request: ConsultationRequest
    @Binding var disclaimerAccepted: Bool
    var validationErrors: [ConsultationValidationError]
    var onClearDraft: () -> Void
    var onCopyEmailAddress: () -> Void
    var statusMessage: String?

    private func message(for error: ConsultationValidationError) -> String? {
        validationErrors.contains(error) ? error.message : nil
    }

    var body: some View {
        Section {
            Text(ConsultationConfig.formExplainer)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("How requesting a session works")
                .accessibilityValue(ConsultationConfig.formExplainer)
        }

        Section("Your details") {
            field(
                title: "Name",
                text: $request.name,
                error: message(for: .emptyName),
                keyboard: .default,
                contentType: .name,
                autocapitalization: .words,
                limit: ConsultationRequest.maxNameLength
            )

            field(
                title: "Email",
                text: $request.email,
                error: message(for: .emptyEmail) ?? message(for: .invalidEmail),
                keyboard: .emailAddress,
                contentType: .emailAddress,
                autocapitalization: .never,
                limit: ConsultationRequest.maxEmailLength
            )

            field(
                title: "Timezone",
                text: $request.preferredTimezone,
                error: nil,
                keyboard: .default,
                contentType: nil,
                autocapitalization: .words,
                placeholder: "e.g. CET / Europe/Amsterdam",
                limit: ConsultationRequest.maxTimezoneLength
            )

            Picker("Current training experience", selection: $request.experience) {
                ForEach(ConsultationTrainingExperience.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .accessibilityLabel("Current training experience")

            labeledEditor(
                title: "What you want help with",
                text: $request.helpWith,
                error: message(for: .emptyHelpWith),
                accessibilityLabel: "What you want help with",
                limit: ConsultationRequest.maxHelpWithLength
            )

            labeledEditor(
                title: "Optional notes",
                text: $request.optionalNotes,
                error: nil,
                accessibilityLabel: "Optional notes",
                limit: ConsultationRequest.maxNotesLength
            )
        }

        Section {
            ConsultationDisclaimerView()
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

            Toggle(isOn: $disclaimerAccepted) {
                Text(ConsultationConfig.disclaimerCheckboxLabel)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityLabel(ConsultationConfig.disclaimerCheckboxLabel)

            if let disclaimerError = message(for: .disclaimerNotAccepted) {
                Text(disclaimerError)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Disclaimer error")
                    .accessibilityValue(disclaimerError)
            }
        } header: {
            Text("Scope")
        }

        Section {
            Text(AppConfiguration.consultationEmail)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
                .textSelection(.enabled)
                .accessibilityLabel("Consultation email address")
                .accessibilityValue(AppConfiguration.consultationEmail)

            Button("Copy email address", action: onCopyEmailAddress)
                .accessibilityHint("Copies \(AppConfiguration.consultationEmail) to the clipboard")

            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .accessibilityLabel("Status")
                    .accessibilityValue(statusMessage)
            }
        } header: {
            Text("Contact")
        } footer: {
            Text(ConsultationConfig.draftStorageDescription)
                .font(SheLiftsFont.caption)
        }

        Section {
            Button("Clear saved draft", role: .destructive, action: onClearDraft)
                .disabled(request.isBlank && ConsultationDraftStore.load() == nil)
                .accessibilityHint("Removes the locally saved consultation request draft")
        }
    }

    @ViewBuilder
    private func field(
        title: String,
        text: Binding<String>,
        error: String?,
        keyboard: UIKeyboardType,
        contentType: UITextContentType?,
        autocapitalization: TextInputAutocapitalization,
        placeholder: String? = nil,
        limit: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder ?? title, text: limitedBinding(text, limit: limit))
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .font(SheLiftsFont.body)
                .accessibilityLabel(title)

            if let error {
                Text(error)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("\(title) error")
                    .accessibilityValue(error)
            }
        }
    }

    @ViewBuilder
    private func labeledEditor(
        title: String,
        text: Binding<String>,
        error: String?,
        accessibilityLabel: String,
        limit: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            TextField(title, text: limitedBinding(text, limit: limit), axis: .vertical)
                .lineLimit(3...8)
                .font(SheLiftsFont.body)
                .accessibilityLabel(accessibilityLabel)

            if let error {
                Text(error)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("\(title) error")
                    .accessibilityValue(error)
            }
        }
    }

    private func limitedBinding(_ binding: Binding<String>, limit: Int) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = String($0.prefix(limit)) }
        )
    }
}
