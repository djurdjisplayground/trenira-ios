import MessageUI
import SwiftUI
import UIKit

struct ConsultationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var request = ConsultationDraftStore.load() ?? ConsultationRequest()
    @State private var disclaimerAccepted = false
    @State private var validationErrors: [ConsultationValidationError] = []
    @State private var showMailComposer = false
    @State private var showMailUnavailable = false
    @State private var statusMessage: String?
    @State private var showSentSuccess = false
    @State private var saveTask: Task<Void, Never>?

    private var canRequestSession: Bool {
        disclaimerAccepted
    }

    var body: some View {
        Form {
            if showSentSuccess {
                successSection
            } else {
                overviewSections
                ConsultationRequestFormView(
                    request: $request,
                    disclaimerAccepted: $disclaimerAccepted,
                    validationErrors: validationErrors,
                    onClearDraft: clearDraft,
                    onCopyEmailAddress: copyEmailAddress,
                    statusMessage: statusMessage
                )
                Section {
                    Button {
                        requestSession()
                    } label: {
                        Text("Request a session")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(!canRequestSession)
                    .accessibilityLabel("Request a session")
                    .accessibilityHint(
                        canRequestSession
                            ? "Validates the form and opens Mail with a prefilled consultation request"
                            : "Accept the consultation scope before requesting a session"
                    )
                } footer: {
                    Text("Opens Mail addressed to \(AppConfiguration.consultationEmail). You still need to tap Send.")
                        .font(SheLiftsFont.caption)
                }
            }
        }
        .navigationTitle(ConsultationConfig.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: request) { _, newValue in
            scheduleDraftSave(newValue)
        }
        .onDisappear {
            saveTask?.cancel()
            if !showSentSuccess, !request.isBlank {
                var copy = request
                copy.clampFieldLengths()
                ConsultationDraftStore.save(copy)
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipients: [AppConfiguration.consultationEmail],
                subject: ConsultationService.emailSubject(for: request),
                body: ConsultationService.emailBody(for: request)
            ) { result in
                showMailComposer = false
                applyMailOutcome(mapMailResult(result))
            }
            .ignoresSafeArea()
        }
        .alert(ConsultationConfig.mailUnavailableTitle, isPresented: $showMailUnavailable) {
            Button("Copy request") {
                copyRequestToPasteboard()
            }
            if let mailto = ConsultationService.mailtoURL(for: request) {
                Button("Open email app") {
                    openURL(mailto)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(ConsultationConfig.mailUnavailableBody)
        }
    }

    @ViewBuilder
    private var successSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(ConsultationConfig.successTitle)
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(ConsultationConfig.successBody)
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }

        Section {
            Button("Back to Settings") {
                dismiss()
            }
            .accessibilityLabel("Back to Settings")
        }
    }

    @ViewBuilder
    private var overviewSections: some View {
        Section {
            Text(ConsultationConfig.serviceDescription)
                .font(SheLiftsFont.body)
                .foregroundStyle(IronHerTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Price") {
                Text(ConsultationConfig.priceAmount)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
            LabeledContent("Duration") {
                Text(ConsultationConfig.durationLabel)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        } header: {
            Text("About this session")
        }

        Section("What’s included") {
            ForEach(ConsultationConfig.included, id: \.self) { item in
                Text(item)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.primaryText)
            }
        }

        Section("What’s not included") {
            ForEach(ConsultationConfig.notIncluded, id: \.self) { item in
                Text(item)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }

        Section("About the founder") {
            Text(ConsultationConfig.founderBlurb)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func requestSession() {
        var normalized = request
        normalized.clampFieldLengths()
        request = normalized

        let errors = ConsultationService.validate(normalized, disclaimerAccepted: disclaimerAccepted)
        validationErrors = errors
        guard errors.isEmpty else { return }

        ConsultationDraftStore.save(normalized)
        statusMessage = nil

        if MailComposeView.canSendMail {
            showMailComposer = true
        } else {
            showMailUnavailable = true
        }
    }

    private func applyMailOutcome(_ outcome: ConsultationMailOutcome) {
        let effect = ConsultationService.effect(for: outcome)
        if effect.clearDraft {
            ConsultationDraftStore.clear()
            request = ConsultationRequest()
            disclaimerAccepted = false
            validationErrors = []
        }
        statusMessage = effect.statusMessage
        showSentSuccess = effect.showSentSuccess
    }

    private func mapMailResult(_ result: MailComposeResultKind) -> ConsultationMailOutcome {
        switch result {
        case .sent: return .sent
        case .saved: return .saved
        case .cancelled: return .cancelled
        case .failed: return .failed
        }
    }

    private func copyRequestToPasteboard() {
        UIPasteboard.general.string = ConsultationService.clipboardRequestPayload(for: request)
        applyMailOutcome(.copiedRequest)
    }

    private func copyEmailAddress() {
        UIPasteboard.general.string = AppConfiguration.consultationEmail
        applyMailOutcome(.copiedEmailAddress)
    }

    private func clearDraft() {
        ConsultationDraftStore.clear()
        request = ConsultationRequest()
        validationErrors = []
        statusMessage = nil
    }

    private func scheduleDraftSave(_ value: ConsultationRequest) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            var copy = value
            copy.clampFieldLengths()
            if copy.isBlank {
                ConsultationDraftStore.clear()
            } else {
                ConsultationDraftStore.save(copy)
            }
        }
    }
}
