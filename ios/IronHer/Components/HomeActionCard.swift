import SwiftUI

struct HomeActionCard: View {
    enum Style {
        case primary
        case secondary
    }

    @Environment(LocalizationStore.self) private var l10n

    let title: String
    var subtitle: String? = nil
    let icon: String
    var style: Style = .secondary
    var minHeight: CGFloat = 112
    var showsPremiumBadge: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundStyle(iconColor)

                Spacer(minLength: 0)

                if showsPremiumBadge {
                    Text(l10n.t(.premium_badge))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(style == .primary ? IronHerTheme.accentForeground.opacity(0.85) : IronHerTheme.secondaryText)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)

                if let subtitle {
                    Text(subtitle)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .padding(20)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .overlay {
            if style == .secondary {
                RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                    .stroke(IronHerTheme.separator.opacity(0.55), lineWidth: 0.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
    }

    private var iconSize: CGFloat {
        style == .primary ? 26 : 22
    }

    private var titleFont: Font {
        style == .primary ? SheLiftsFont.cardTitle : SheLiftsFont.cardLabel
    }

    private var backgroundColor: Color {
        style == .primary ? IronHerTheme.accent : IronHerTheme.cardBackground
    }

    private var iconColor: Color {
        style == .primary ? IronHerTheme.accentForeground : IronHerTheme.primaryText
    }

    private var titleColor: Color {
        style == .primary ? IronHerTheme.accentForeground : IronHerTheme.primaryText
    }

    private var subtitleColor: Color {
        style == .primary ? IronHerTheme.accentForeground.opacity(0.78) : IronHerTheme.secondaryText
    }
}

#Preview {
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    LazyVGrid(columns: columns, spacing: 16) {
        HomeActionCard(
            title: "Start Workout",
            subtitle: "Begin training",
            icon: "play",
            style: .primary,
            minHeight: 136
        )
        HomeActionCard(title: "My Workouts", icon: "list.bullet")
        HomeActionCard(title: "Create Workout", icon: "plus")
        HomeActionCard(title: "Settings", icon: "gearshape")
    }
    .padding(28)
    .background(IronHerTheme.background)
    .environment(LocalizationStore())
}
