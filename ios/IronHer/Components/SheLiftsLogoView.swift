import SwiftUI

/// Three-element abstract dumbbell.
/// Left fine line · continuous flowing S · right fine line. Never intersecting.
enum BrandMarkStyle: String, CaseIterable, Identifiable {
    /// Pronounced elegant S connector — default brand mark.
    case flowingS
    /// Softer, slightly quieter S.
    case softS
    /// Soft upward arch (no S).
    case softArch
    /// Straight center bar — pure geometry.
    case essential
    /// Taller end strokes.
    case tallPlates
    /// Longer connector span, shorter ends.
    case wideBar
    /// Right end slightly taller — implicit progress.
    case ascendingEnds
    /// Wider gap at the core.
    case openCore
    /// Compact proportions for tiny UI.
    case compact
    /// Same as flowingS with slightly heavier stroke for icons.
    case iconWeight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flowingS: return "Flowing S"
        case .softS: return "Soft S"
        case .softArch: return "Soft Arch"
        case .essential: return "Essential"
        case .tallPlates: return "Tall Plates"
        case .wideBar: return "Wide Bar"
        case .ascendingEnds: return "Ascending Ends"
        case .openCore: return "Open Core"
        case .compact: return "Compact"
        case .iconWeight: return "Icon Weight"
        }
    }

    var subtitle: String {
        switch self {
        case .flowingS: return "Fine ends + clear flowing S center"
        case .softS: return "Quieter S — still continuous and smooth"
        case .softArch: return "Soft upward curve through the center"
        case .essential: return "Straight bar — pure three-line form"
        case .tallPlates: return "Taller ends, restrained connector"
        case .wideBar: return "Longer center, shorter ends"
        case .ascendingEnds: return "Subtle growth left to right"
        case .openCore: return "More negative space in the middle"
        case .compact: return "Tighter mark for small UI"
        case .iconWeight: return "Flowing S with slightly heavier stroke"
        }
    }

    var strokeScale: CGFloat {
        switch self {
        case .iconWeight: return 1.22
        case .openCore: return 0.92
        case .compact: return 1.06
        default: return 1.0
        }
    }

    fileprivate var barCurve: BarCurve {
        switch self {
        case .flowingS, .iconWeight: return .flowingS
        case .softS: return .softS
        case .softArch: return .softArch
        default: return .straight
        }
    }
}

private enum BarCurve {
    case straight
    case softArch
    case softS
    case flowingS
}

typealias SheLiftsMarkStyle = BrandMarkStyle

/// Standalone brand symbol — adapts black ↔ white with appearance.
struct BrandLogoMark: View {
    var size: CGFloat = 80
    var style: BrandMarkStyle = BrandIdentity.defaultMarkStyle
    var color: Color? = nil

    var body: some View {
        let strokeColor = color ?? IronHerTheme.brandMark
        ThreeLineDumbbellShape(style: style)
            .stroke(
                strokeColor,
                style: StrokeStyle(
                    lineWidth: max(1.15, size * 0.032 * style.strokeScale),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size * 0.78, height: size * 0.52)
            .frame(width: size, height: size * 0.78)
            .accessibilityLabel(BrandIdentity.displayName)
    }
}

typealias SheLiftsLogoMark = BrandLogoMark

// MARK: - Shape

private struct ThreeLineDumbbellShape: Shape {
    var style: BrandMarkStyle

    func path(in rect: CGRect) -> Path {
        switch style {
        case .flowingS, .iconWeight, .softS:
            return threeLine(in: rect, leftH: 0.62, rightH: 0.62, barInset: 0.09, plateInset: 0.02)
        case .softArch:
            return threeLine(in: rect, leftH: 0.72, rightH: 0.72, barInset: 0.10, plateInset: 0.02)
        case .essential:
            return threeLine(in: rect, leftH: 0.78, rightH: 0.78, barInset: 0.10, plateInset: 0.02)
        case .tallPlates:
            return threeLine(in: rect, leftH: 0.95, rightH: 0.95, barInset: 0.13, plateInset: 0.02)
        case .wideBar:
            return threeLine(in: rect, leftH: 0.48, rightH: 0.48, barInset: 0.06, plateInset: 0.015)
        case .ascendingEnds:
            return threeLine(in: rect, leftH: 0.50, rightH: 0.78, barInset: 0.09, plateInset: 0.02)
        case .openCore:
            return threeLine(in: rect, leftH: 0.62, rightH: 0.62, barInset: 0.18, plateInset: 0.02)
        case .compact:
            return threeLine(in: rect, leftH: 0.58, rightH: 0.58, barInset: 0.08, plateInset: 0.05, horizontalInset: 0.12)
        }
    }

    private func threeLine(
        in rect: CGRect,
        leftH: CGFloat,
        rightH: CGFloat,
        barInset: CGFloat,
        plateInset: CGFloat,
        horizontalInset: CGFloat = 0.08
    ) -> Path {
        var path = Path()
        let r = rect.insetBy(dx: rect.width * horizontalInset, dy: rect.height * 0.10)
        let midY = r.midY

        let leftX = r.minX + r.width * plateInset
        let leftHalf = r.height * leftH * 0.5
        path.move(to: CGPoint(x: leftX, y: midY - leftHalf))
        path.addLine(to: CGPoint(x: leftX, y: midY + leftHalf))

        let rightX = r.maxX - r.width * plateInset
        let rightHalf = r.height * rightH * 0.5
        path.move(to: CGPoint(x: rightX, y: midY - rightHalf))
        path.addLine(to: CGPoint(x: rightX, y: midY + rightHalf))

        let barLeft = CGPoint(x: leftX + r.width * barInset, y: midY)
        let barRight = CGPoint(x: rightX - r.width * barInset, y: midY)
        addBar(to: &path, from: barLeft, to: barRight, in: r, curve: style.barCurve)

        return path
    }

    private func addBar(
        to path: inout Path,
        from start: CGPoint,
        to end: CGPoint,
        in bounds: CGRect,
        curve: BarCurve
    ) {
        path.move(to: start)
        let span = end.x - start.x
        let midY = bounds.midY

        switch curve {
        case .straight:
            path.addLine(to: end)

        case .softArch:
            let amplitude = bounds.height * 0.14
            let control = CGPoint(x: start.x + span * 0.5, y: midY - amplitude)
            path.addQuadCurve(to: end, control: control)

        case .softS:
            let amplitude = bounds.height * 0.22
            let c1 = CGPoint(x: start.x + span * 0.28, y: midY - amplitude)
            let c2 = CGPoint(x: start.x + span * 0.72, y: midY + amplitude)
            path.addCurve(to: end, control1: c1, control2: c2)

        case .flowingS:
            // One continuous, clearly visible flowing S — movement + progress.
            let amplitude = bounds.height * 0.36
            let c1 = CGPoint(x: start.x + span * 0.26, y: midY - amplitude)
            let c2 = CGPoint(x: start.x + span * 0.74, y: midY + amplitude)
            path.addCurve(to: end, control1: c1, control2: c2)
        }
    }
}

// MARK: - Wordmark & lockup

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

/// Brand hierarchy:
/// mark → trenira → Strength, / on your own terms.
struct BrandLockup: View {
    var markSize: CGFloat = 44
    var nameSize: CGFloat = 24
    var taglineSize: CGFloat = 13
    var taglineLine2Size: CGFloat? = nil
    var style: BrandMarkStyle = BrandIdentity.defaultMarkStyle
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
                        BrandLogoMark(size: markSize, style: style)
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
                        BrandLogoMark(size: markSize, style: style)
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
    var style: BrandMarkStyle = BrandIdentity.defaultMarkStyle

    var body: some View {
        if showWordmark {
            BrandLockup(
                markSize: size * 0.40,
                nameSize: size * 0.18,
                taglineSize: size * 0.10,
                style: style
            )
        } else {
            BrandLogoMark(size: size * 0.68, style: style)
        }
    }
}

typealias SheLiftsLogoView = BrandLogoView

struct BrandLogoVariantsGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("trenira mark")
                    .font(SheLiftsFont.section)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text("Fine ends · flowing S · movement + progress")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                BrandLockup()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                iconTreatments

                ForEach(BrandMarkStyle.allCases) { style in
                    HStack(spacing: 20) {
                        ZStack {
                            IronHerTheme.cardBackground
                            BrandLogoMark(size: 64, style: style)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(IronHerTheme.separator.opacity(0.5), lineWidth: 0.5)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.title)
                                .font(SheLiftsFont.bodyMedium)
                                .foregroundStyle(IronHerTheme.primaryText)
                            Text(style.subtitle)
                                .font(SheLiftsFont.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                            if style == BrandIdentity.defaultMarkStyle {
                                Text("Selected")
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(IronHerTheme.primaryText)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(24)
        }
        .background(IronHerTheme.groupedBackground)
    }

    private var iconTreatments: some View {
        HStack(spacing: 12) {
            iconSwatch(background: .white, foreground: .black, label: "Light")
            iconSwatch(background: Color(white: 0.05), foreground: .white, label: "Dark")
        }
    }

    private func iconSwatch(background: Color, foreground: Color, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                background
                BrandLogoMark(size: 52, color: foreground)
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(IronHerTheme.separator.opacity(0.4), lineWidth: 0.5)
            }

            Text(label)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
    }
}

typealias SheLiftsLogoVariantsGallery = BrandLogoVariantsGallery

#Preview("Lockup light") {
    BrandLockup()
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
}

#Preview("Lockup dark") {
    BrandLockup()
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.05))
        .preferredColorScheme(.dark)
}

#Preview("All variants") {
    BrandLogoVariantsGallery()
}
