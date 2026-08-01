import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            title: LegalDocumentContent.privacyTitle,
            markdown: LegalDocumentContent.privacyMarkdown
        )
    }
}

struct TermsAndConditionsView: View {
    var body: some View {
        LegalDocumentView(
            title: LegalDocumentContent.termsTitle,
            markdown: LegalDocumentContent.termsMarkdown
        )
    }
}

struct LegalDocumentView: View {
    let title: String
    let markdown: String

    var body: some View {
        ScrollView {
            Text(localizedMarkdown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, IronHerTheme.screenPadding)
                .padding(.vertical, 20)
                .textSelection(.enabled)
        }
        .background(IronHerTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityLabel(title)
    }

    private var localizedMarkdown: AttributedString {
        if let parsed = try? AttributedString(markdown: markdown) {
            return parsed
        }
        return AttributedString(markdown)
    }
}
