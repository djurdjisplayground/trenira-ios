import SwiftUI

struct AuthOptionButton: View {
    enum Style {
        case apple
        case google
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leadingIcon
                Text(title)
                    .font(SheLiftsFont.bodyMedium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .overlay {
                if style != .apple {
                    RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                        .stroke(IronHerTheme.separator, lineWidth: 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(SheLiftsPressStyle())
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch style {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 20, weight: .medium))
        case .google:
            Text("G")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(IronHerTheme.primaryText)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .apple:
            IronHerTheme.accentForeground
        case .google:
            IronHerTheme.primaryText
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .apple:
            IronHerTheme.accent
        case .google:
            IronHerTheme.cardBackground
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AuthOptionButton(title: "Continue with Apple", style: .apple) {}
        AuthOptionButton(title: "Continue with Google", style: .google) {}
    }
    .padding()
    .background(IronHerTheme.background)
}
