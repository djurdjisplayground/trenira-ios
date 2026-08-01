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

/// Long-form legal document layout with section hierarchy, spacing, and tappable links.
struct LegalDocumentView: View {
    let title: String
    let markdown: String

    var body: some View {
        let document = LegalDocumentParser.parse(markdown)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(for: document)
                    .padding(.bottom, 28)

                ForEach(Array(document.sections.enumerated()), id: \.offset) { index, section in
                    sectionView(section)
                        .padding(.top, index == 0 ? 8 : 28)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.visible)
        .background(IronHerTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityLabel(title)
    }

    private func header(for document: LegalDocumentParser.Document) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(document.title.isEmpty ? title : document.title)
                .font(SheLiftsFont.largeTitle)
                .foregroundStyle(IronHerTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let effectiveDate = document.effectiveDate {
                Text("Effective date: \(effectiveDate)")
                    .font(SheLiftsFont.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !document.metadata.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(document.metadata.enumerated()), id: \.offset) { _, item in
                        metadataRow(label: item.label, value: item.value)
                    }
                }
                .padding(.top, 4)
            }

            if let intro = document.intro, !intro.characters.isEmpty {
                Text(intro)
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.top, 10)
            }

            Rectangle()
                .fill(IronHerTheme.separator.opacity(0.7))
                .frame(height: 0.5)
                .padding(.top, 16)
        }
    }

    private func metadataRow(label: String, value: AttributedString) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(label):")
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.secondaryText)
            Text(value)
                .font(SheLiftsFont.subheadline)
                .foregroundStyle(IronHerTheme.primaryText)
                .tint(IronHerTheme.primaryText)
                .textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func sectionView(_ section: LegalDocumentParser.Section) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !section.heading.isEmpty {
                Text(section.heading)
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let text):
                    Text(text)
                        .font(SheLiftsFont.body)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .tint(IronHerTheme.primaryText)

                case .bullets(let items):
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("•")
                                    .font(SheLiftsFont.body)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                                    .accessibilityHidden(true)
                                Text(item)
                                    .font(SheLiftsFont.body)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                    .tint(IronHerTheme.primaryText)
                            }
                        }
                    }
                    .padding(.leading, 2)
                }
            }
        }
    }
}

// MARK: - Parser

enum LegalDocumentParser {
    struct Document {
        var title: String = ""
        var effectiveDate: String?
        var metadata: [MetaItem] = []
        var intro: AttributedString?
        var sections: [Section] = []
    }

    struct MetaItem {
        var label: String
        var value: AttributedString
    }

    struct Section {
        var heading: String
        var blocks: [Block]
    }

    enum Block {
        case paragraph(AttributedString)
        case bullets([AttributedString])
    }

    static func parse(_ markdown: String) -> Document {
        var document = Document()
        var currentSection: Section?
        var introParagraphs: [String] = []
        var paragraphBuffer: [String] = []
        var bulletBuffer: [String] = []
        var seenFirstHeading = false

        // Mutate `currentSection` directly — never use `inout` + `if var` on the same
        // optional (that triggers Swift exclusivity crashes).
        func flushBullets() {
            guard !bulletBuffer.isEmpty else { return }
            let items = bulletBuffer.map(attributedInline)
            bulletBuffer.removeAll()
            guard var section = currentSection else { return }
            section.blocks.append(.bullets(items))
            currentSection = section
        }

        func flushParagraph() {
            let joined = paragraphBuffer
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            paragraphBuffer.removeAll()
            guard !joined.isEmpty else { return }

            if !seenFirstHeading {
                introParagraphs.append(joined)
                return
            }

            guard var section = currentSection else { return }
            section.blocks.append(.paragraph(attributedInline(joined)))
            currentSection = section
        }

        func closeSection() {
            flushBullets()
            flushParagraph()
            if let finished = currentSection {
                document.sections.append(finished)
            }
            currentSection = nil
        }

        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushBullets()
                flushParagraph()
                continue
            }

            if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                document.title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if line.hasPrefix("## ") {
                closeSection()
                seenFirstHeading = true
                currentSection = Section(
                    heading: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces),
                    blocks: []
                )
                continue
            }

            if line.hasPrefix("- ") {
                flushParagraph()
                bulletBuffer.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                continue
            }

            if let meta = parseMetadataLine(line) {
                flushBullets()
                flushParagraph()
                if meta.label.lowercased() == "effective date" {
                    document.effectiveDate = meta.plainValue
                } else if !seenFirstHeading {
                    document.metadata.append(
                        MetaItem(label: meta.label, value: attributedInline(meta.plainValue))
                    )
                } else {
                    paragraphBuffer.append(line)
                }
                continue
            }

            flushBullets()
            paragraphBuffer.append(line)
        }

        closeSection()

        if !introParagraphs.isEmpty {
            document.intro = attributedInline(introParagraphs.joined(separator: "\n\n"))
        }

        return document
    }

    private static func parseMetadataLine(_ line: String) -> (label: String, plainValue: String)? {
        // **Label:** value
        guard line.hasPrefix("**"), let close = line.range(of: "**", range: line.index(line.startIndex, offsetBy: 2)..<line.endIndex) else {
            return nil
        }
        let labelPart = String(line[line.index(line.startIndex, offsetBy: 2)..<close.lowerBound])
        var remainder = String(line[close.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard labelPart.hasSuffix(":") || remainder.hasPrefix(":") else { return nil }
        if remainder.hasPrefix(":") {
            remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        let label = labelPart.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespaces))
        guard !label.isEmpty, !remainder.isEmpty else { return nil }
        return (label, remainder)
    }

    static func attributedInline(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace

        var result: AttributedString
        if let parsed = try? AttributedString(markdown: text, options: options) {
            result = parsed
        } else {
            result = AttributedString(text)
        }
        linkifyContacts(in: &result)
        return result
    }

    private static func linkifyContacts(in attributed: inout AttributedString) {
        let plain = String(attributed.characters)
        let nsPlain = plain as NSString
        let fullRange = NSRange(location: 0, length: nsPlain.length)

        let patterns: [(String, (String) -> URL?)] = [
            (
                #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                { URL(string: "mailto:\($0)") }
            ),
            (
                #"https?://[^\s]+"#,
                { URL(string: $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,);")) ) }
            ),
        ]

        for (pattern, makeURL) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let matches = regex.matches(in: plain, options: [], range: fullRange)
            for match in matches.reversed() {
                guard let attrRange = Range(match.range, in: attributed) else { continue }
                let matched = String(attributed[attrRange].characters)
                guard let url = makeURL(matched) else { continue }
                var slice = attributed[attrRange]
                slice.link = url
                slice.underlineStyle = .single
                attributed[attrRange] = slice
            }
        }
    }
}

#Preview("Privacy Policy") {
    NavigationStack {
        PrivacyPolicyView()
    }
}

#Preview("Terms") {
    NavigationStack {
        TermsAndConditionsView()
    }
}
