import SwiftUI

/// Compact Settings entry for the optional Founder Consultation.
struct ConsultationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ConsultationConfig.title)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

            Text(ConsultationConfig.subtitle)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(ConsultationConfig.priceLabel)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.primaryText)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ConsultationConfig.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                            .foregroundStyle(IronHerTheme.secondaryText)
                            .accessibilityHidden(true)
                        Text(bullet)
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            NavigationLink {
                ConsultationDetailView()
            } label: {
                Text("Request a session")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Request a session")
            .accessibilityHint("Opens consultation details and request form")
        }
        .padding(.vertical, 4)
    }
}
