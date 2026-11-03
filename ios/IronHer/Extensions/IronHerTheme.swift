import SwiftUI

enum IronHerTheme {
    static let cornerRadius: CGFloat = 18
    static let cornerRadiusSmall: CGFloat = TreniraSpace.controlRadius
    static let screenPadding: CGFloat = TreniraSpace.screen
    static let sectionSpacing: CGFloat = 36
    static let gridSpacing: CGFloat = TreniraSpace.stack

    /// Primary canvas.
    static var background: Color { TreniraColor.canvas }

    /// Grouped / inset surfaces.
    static var groupedBackground: Color { TreniraColor.surface }

    /// Cards and elevated panels.
    static var cardBackground: Color { TreniraColor.elevated }

    /// Primary content.
    static var primaryText: Color { TreniraColor.label }

    /// Secondary labels.
    static var secondaryText: Color { TreniraColor.labelSecondary }

    /// Tagline / quiet supporting brand text.
    static var brandSecondary: Color { TreniraColor.labelSecondary }

    static var separator: Color { TreniraColor.hairline }

    /// Primary filled actions.
    static var accent: Color { TreniraColor.action }

    static var accentForeground: Color { TreniraColor.onAction }

    /// In-app wordmark. The app icon is unchanged.
    static var brandMark: Color { TreniraColor.label }
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
