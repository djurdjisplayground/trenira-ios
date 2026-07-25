import SwiftUI

/// Typography aligned with SF Pro Display (headings) and SF Pro Text (body).
enum SheLiftsFont {
    static func display(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static var largeTitle: Font { .system(.largeTitle, design: .default).weight(.semibold) }
    static var title: Font { .system(.title2, design: .default).weight(.semibold) }
    static var section: Font { .system(.headline, design: .default).weight(.medium) }
    static var body: Font { .system(.body, design: .default).weight(.regular) }
    static var bodyMedium: Font { .system(.body, design: .default).weight(.medium) }
    static var subheadline: Font { .system(.subheadline, design: .default).weight(.regular) }
    static var caption: Font { .system(.caption, design: .default).weight(.regular) }
    static var cardTitle: Font { .system(.title3, design: .default).weight(.semibold) }
    static var cardLabel: Font { .system(.headline, design: .default).weight(.medium) }
}
