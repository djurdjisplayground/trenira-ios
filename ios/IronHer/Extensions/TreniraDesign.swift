import SwiftUI

/// Visual tokens for the movement-companion direction.
/// Light values follow the written product specification. Dark values are calm companions
/// so existing screens stay readable when the system appearance is dark.
enum TreniraColor {
    static let lavender = Color(red: 240 / 255, green: 232 / 255, blue: 243 / 255)
    static let plum = Color(red: 101 / 255, green: 66 / 255, blue: 118 / 255)
    static let lilac = Color(red: 233 / 255, green: 221 / 255, blue: 241 / 255)
    static let rose = Color(red: 250 / 255, green: 239 / 255, blue: 242 / 255)
    static let ink = Color(red: 53 / 255, green: 40 / 255, blue: 62 / 255)
    static let inkSecondary = Color(red: 130 / 255, green: 121 / 255, blue: 139 / 255)
    static let card = Color.white
    static let border = Color(red: 231 / 255, green: 224 / 255, blue: 234 / 255)
    static let ivory = Color(red: 250 / 255, green: 247 / 255, blue: 242 / 255)
    static let mauve = Color(red: 220 / 255, green: 199 / 255, blue: 216 / 255)
    static let orchid = Color(red: 167 / 255, green: 131 / 255, blue: 155 / 255)

    static let canvasDark = Color(red: 28 / 255, green: 22 / 255, blue: 34 / 255)
    static let cardDark = Color(red: 42 / 255, green: 34 / 255, blue: 50 / 255)
    static let inkDark = Color(red: 247 / 255, green: 242 / 255, blue: 250 / 255)
    static let inkSecondaryDark = Color(red: 201 / 255, green: 189 / 255, blue: 208 / 255)
    static let borderDark = Color(red: 74 / 255, green: 65 / 255, blue: 84 / 255)
    static let surfaceDark = Color(red: 48 / 255, green: 39 / 255, blue: 58 / 255)

    static var canvas: Color { adaptive(light: lavender, dark: canvasDark) }
    static var surface: Color { adaptive(light: lilac, dark: surfaceDark) }
    static var warmSurface: Color { adaptive(light: rose, dark: surfaceDark) }
    static var elevated: Color { adaptive(light: card, dark: cardDark) }
    static var label: Color { adaptive(light: ink, dark: inkDark) }
    static var labelSecondary: Color { adaptive(light: inkSecondary, dark: inkSecondaryDark) }
    static var hairline: Color { adaptive(light: border, dark: borderDark) }
    static var action: Color { plum }
    static var onAction: Color { card }

    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

enum TreniraSpace {
    static let screen: CGFloat = 28
    static let section: CGFloat = 28
    static let stack: CGFloat = 12
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 16
}

/// Dynamic Type styles. Sizes follow the user's text-size setting.
enum TreniraType {
    /// Serif display. Fraunces is not bundled, so this uses the system serif.
    static var display: Font { .system(.largeTitle, design: .serif).weight(.regular) }
    static var displayTitle: Font { .system(.title2, design: .serif).weight(.regular) }
    static var largeTitle: Font { .system(.largeTitle, design: .default).weight(.semibold) }
    static var title: Font { .system(.title2, design: .default).weight(.semibold) }
    static var section: Font { .system(.headline, design: .default).weight(.medium) }
    static var body: Font { .system(.body, design: .default).weight(.regular) }
    static var bodyMedium: Font { .system(.body, design: .default).weight(.medium) }
    static var caption: Font { .system(.caption, design: .default).weight(.regular) }
}

struct TreniraCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(TreniraSpace.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TreniraColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous)
                    .stroke(TreniraColor.hairline, lineWidth: 1)
            }
    }
}

struct TreniraPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TreniraType.section)
            .foregroundStyle(TreniraColor.onAction)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? TreniraColor.action : TreniraColor.labelSecondary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct TreniraSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TreniraType.section)
            .foregroundStyle(TreniraColor.label)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(TreniraColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TreniraSpace.controlRadius, style: .continuous)
                    .stroke(TreniraColor.hairline, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

/// A single selectable answer. Supports one or many selections through `isSelected`.
struct TreniraChoiceRow: View {
    let title: String
    var detail: String? = nil
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(TreniraType.bodyMedium)
                        .foregroundStyle(TreniraColor.label)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(TreniraType.caption)
                            .foregroundStyle(TreniraColor.labelSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? TreniraColor.action : TreniraColor.labelSecondary)
                    .accessibilityHidden(true)
            }
            .padding(TreniraSpace.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? TreniraColor.surface : TreniraColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TreniraSpace.controlRadius, style: .continuous)
                    .stroke(isSelected ? TreniraColor.action : TreniraColor.hairline, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    func treniraCard() -> some View {
        modifier(TreniraCardModifier())
    }
}
