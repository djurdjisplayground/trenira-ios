import SwiftUI

/// Approved trenira mark.
/// Deep plum tile, light lavender movement ribbon, small lilac dot.
/// Path matches `Resources/trenira-movement-mark.svg`.
struct BrandLogoMark: View {
    var size: CGFloat = 80

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.223, style: .continuous)
            .fill(TreniraColor.plum)
            .frame(width: size, height: size)
            .overlay {
                GeometryReader { geo in
                    MovementRibbonShape()
                        .stroke(
                            BrandMarkPalette.ribbon,
                            style: StrokeStyle(
                                lineWidth: size * 0.09,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    Circle()
                        .fill(BrandMarkPalette.dot)
                        .frame(width: size * 0.10, height: size * 0.10)
                        .position(x: geo.size.width * 0.80, y: geo.size.height * 0.40)
                }
            }
            .accessibilityLabel(BrandIdentity.displayName)
    }
}

typealias SheLiftsLogoMark = BrandLogoMark

private enum BrandMarkPalette {
    /// Light lavender ribbon from the approved mark.
    static let ribbon = Color(red: 246 / 255, green: 233 / 255, blue: 246 / 255)
    /// Lilac dot from the approved mark.
    static let dot = Color(red: 229 / 255, green: 181 / 255, blue: 210 / 255)
}

/// SVG viewBox 0 0 100 100. Y grows downward, matching SwiftUI.
private struct MovementRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x / 100,
                y: rect.minY + rect.height * y / 100
            )
        }

        var path = Path()
        path.move(to: point(22, 58))
        path.addCurve(to: point(52, 49), control1: point(38, 21), control2: point(57, 24))
        path.addCurve(to: point(80, 40), control1: point(47, 75), control2: point(66, 80))
        return path
    }
}

struct BrandWordmark: View {
    var size: CGFloat = 28
    var weight: Font.Weight = .semibold
    var color: Color? = nil

    var body: some View {
        Text(BrandIdentity.displayName)
            .font(SheLiftsFont.display(size: size, weight: weight))
            .foregroundStyle(color ?? IronHerTheme.primaryText)
            .tracking(BrandIdentity.wordmarkTracking)
            .textCase(nil)
    }
}

struct BrandTagline: View {
    var size: CGFloat = 14
    var line2Size: CGFloat? = nil
    var weight: Font.Weight = .regular
    var lineSpacing: CGFloat = 2
    var color: Color? = nil
    /// When true, uses primary brand text (confident statement) instead of secondary.
    var isHero: Bool = false
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        VStack(spacing: lineSpacing) {
            Text(l10n.t(.tagline_line1))
                .font(SheLiftsFont.display(size: size, weight: isHero ? .semibold : weight))
            Text(l10n.t(.tagline_line2))
                .font(SheLiftsFont.display(size: line2Size ?? size, weight: isHero ? .medium : weight))
        }
        .foregroundStyle(color ?? (isHero ? IronHerTheme.primaryText : IronHerTheme.brandSecondary))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

typealias SheLiftsTagline = BrandTagline

/// Brand hierarchy: mark → trenira → Movement that / fits your life.
struct BrandLockup: View {
    var markSize: CGFloat = 72
    var nameSize: CGFloat = 24
    var taglineSize: CGFloat = 13
    var taglineLine2Size: CGFloat? = nil
    var showMark: Bool = true
    var showTagline: Bool = true
    var showWordmark: Bool = true
    var axis: Axis = .vertical
    /// Launch / branding hero: larger tagline, primary color, generous spacing.
    var isHero: Bool = false

    var body: some View {
        Group {
            if axis == .vertical {
                VStack(spacing: 0) {
                    if showMark {
                        BrandLogoMark(size: markSize)
                            .padding(.bottom, showWordmark || showTagline ? (isHero ? 18 : 12) : 0)
                    }
                    if showWordmark {
                        BrandWordmark(
                            size: nameSize,
                            weight: isHero ? .medium : .semibold
                        )
                    }
                    if showTagline {
                        BrandTagline(
                            size: taglineSize,
                            line2Size: taglineLine2Size,
                            lineSpacing: isHero ? 8 : 2,
                            isHero: isHero
                        )
                        .padding(.top, showWordmark ? (isHero ? 16 : 7) : 0)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    if showMark {
                        BrandLogoMark(size: markSize)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        if showWordmark {
                            BrandWordmark(size: nameSize)
                        }
                        if showTagline {
                            BrandTagline(size: max(11, taglineSize * 0.9))
                        }
                    }
                }
            }
        }
    }
}

typealias SheLiftsBrandLockup = BrandLockup

struct BrandLogoView: View {
    var size: CGFloat = 120
    var showWordmark: Bool = true

    var body: some View {
        if showWordmark {
            BrandLockup(
                markSize: size * 0.62,
                nameSize: size * 0.18,
                taglineSize: size * 0.10
            )
        } else {
            BrandLogoMark(size: size * 0.68)
        }
    }
}

typealias SheLiftsLogoView = BrandLogoView

#Preview("Lockup light") {
    BrandLockup()
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreniraColor.lavender)
        .environment(LocalizationStore())
}

#Preview("Lockup dark") {
    BrandLockup()
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreniraColor.canvasDark)
        .environment(LocalizationStore())
        .preferredColorScheme(.dark)
}
