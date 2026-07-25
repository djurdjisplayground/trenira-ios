import SwiftUI

enum IronHerTheme {
    static let cornerRadius: CGFloat = 18
    static let cornerRadiusSmall: CGFloat = 16
    static let screenPadding: CGFloat = 28
    static let sectionSpacing: CGFloat = 36
    static let gridSpacing: CGFloat = 16

    /// Primary canvas — pure white / deep near-black (not crushed pure black).
    static var background: Color {
        adaptive(
            light: .white,
            dark: Color(red: 0.05, green: 0.05, blue: 0.055)
        )
    }

    /// Grouped / inset surfaces.
    static var groupedBackground: Color {
        adaptive(
            light: .groupedBackground,
            dark: Color(red: 0.10, green: 0.10, blue: 0.11)
        )
    }

    /// Cards and elevated panels — clear lift off the canvas in dark mode.
    static var cardBackground: Color {
        adaptive(
            light: .white,
            dark: Color(red: 0.14, green: 0.14, blue: 0.155)
        )
    }

    /// Primary content — charcoal / pure white.
    static var primaryText: Color {
        adaptive(light: .slate850, dark: .white)
    }

    /// Secondary labels — readable in both modes (never low-contrast gray-on-black).
    static var secondaryText: Color {
        adaptive(
            light: .slate500,
            dark: Color(red: 0.82, green: 0.82, blue: 0.84)
        )
    }

    /// Tagline / quiet supporting brand text — still clearly visible in dark mode.
    static var brandSecondary: Color {
        adaptive(
            light: Color(red: 0.40, green: 0.40, blue: 0.43),
            dark: Color(red: 0.94, green: 0.94, blue: 0.95)
        )
    }

    static var separator: Color {
        adaptive(
            light: .hairline,
            dark: Color(red: 0.36, green: 0.36, blue: 0.38)
        )
    }

    /// Primary filled actions — charcoal / white.
    static var accent: Color {
        adaptive(light: .slate850, dark: .white)
    }

    static var accentForeground: Color {
        adaptive(light: .white, dark: Color(red: 0.05, green: 0.05, blue: 0.055))
    }

    /// Brand mark color — black in light, white in dark.
    static var brandMark: Color {
        primaryText
    }

    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

struct IronHerScreenBackground: View {
    var body: some View {
        IronHerTheme.background
            .ignoresSafeArea()
    }
}

struct NotesCardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(IronHerTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                    .stroke(IronHerTheme.separator.opacity(0.55), lineWidth: 0.5)
            }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SheLiftsFont.section)
            .foregroundStyle(IronHerTheme.accentForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? IronHerTheme.accent : IronHerTheme.secondaryText.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SheLiftsFont.section)
            .foregroundStyle(IronHerTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(IronHerTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                    .stroke(IronHerTheme.separator, lineWidth: 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SheLiftsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func notesCard(padding: CGFloat = 20) -> some View {
        modifier(NotesCardModifier(padding: padding))
    }
}
