import SwiftUI

/// Calm, non-blocking notice for automatically generated or adapted workouts.
struct RecommendationDisclaimerBanner: View {
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(IronHerTheme.secondaryText)
                .padding(.top, 1)

            Text(l10n.t(.recommendation_disclaimer))
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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
