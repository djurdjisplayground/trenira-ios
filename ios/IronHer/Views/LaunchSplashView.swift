import SwiftUI

/// Screen 1 — brand only. No auth UI, no sign-in copy.
/// Hierarchy: refined mark → understated trenira → prominent tagline statement.
struct BrandIntroductionView: View {
    @State private var markOpacity = 0.0
    @State private var nameOpacity = 0.0
    @State private var taglineOpacity = 0.0

    var body: some View {
        GeometryReader { geometry in
            let metrics = LaunchBrandMetrics(size: geometry.size)

            ZStack {
                IronHerTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    BrandLogoMark(size: metrics.markSize)
                        .opacity(markOpacity)
                        .padding(.bottom, metrics.markToNameSpacing)

                    BrandWordmark(size: metrics.nameSize, weight: .medium)
                        .opacity(nameOpacity)
                        .padding(.bottom, metrics.nameToTaglineSpacing)

                    BrandTagline(
                        size: metrics.taglineLine1Size,
                        line2Size: metrics.taglineLine2Size,
                        lineSpacing: metrics.taglineLineSpacing,
                        isHero: true
                    )
                    .opacity(taglineOpacity)
                    .padding(.horizontal, metrics.horizontalPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: runEntrance)
    }

    private func runEntrance() {
        withAnimation(.easeOut(duration: 0.70)) {
            markOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.70).delay(0.22)) {
            nameOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.85).delay(0.48)) {
            taglineOpacity = 1
        }
    }
}

/// Responsive sizing so the tagline stays dominant without crowding small phones.
private struct LaunchBrandMetrics {
    let markSize: CGFloat
    let nameSize: CGFloat
    let taglineLine1Size: CGFloat
    let taglineLine2Size: CGFloat
    let taglineLineSpacing: CGFloat
    let markToNameSpacing: CGFloat
    let nameToTaglineSpacing: CGFloat
    let horizontalPadding: CGFloat

    init(size: CGSize) {
        let shortest = min(size.width, size.height)
        let isCompact = shortest < 390

        markSize = isCompact ? 36 : 40
        nameSize = isCompact ? 24 : 28
        taglineLine1Size = isCompact ? 34 : 40
        taglineLine2Size = isCompact ? 30 : 36
        taglineLineSpacing = isCompact ? 6 : 8
        markToNameSpacing = isCompact ? 16 : 20
        nameToTaglineSpacing = isCompact ? 18 : 22
        horizontalPadding = max(28, size.width * 0.08)
    }
}

#Preview("Light") {
    BrandIntroductionView()
        .environment(LocalizationStore())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    BrandIntroductionView()
        .environment(LocalizationStore())
        .preferredColorScheme(.dark)
}
