import SwiftUI

struct ExerciseThumbnailView: View {
    let exercise: Exercise
    var size: CGFloat = 56

    private var imageAssetName: String? {
        ExerciseVisuals.resolvedImageAsset(for: exercise)
    }

    var body: some View {
        Group {
            if let imageAssetName {
                Image(imageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .stroke(IronHerTheme.separator.opacity(0.5), lineWidth: 0.5)
                    }
                    .accessibilityLabel(exercise.name)
            }
        }
    }
}

/// Conditionally reserves space for a thumbnail only when a verified asset exists.
struct ExerciseThumbnailSlot<Content: View>: View {
    let exercise: Exercise
    var size: CGFloat = 56
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if exercise.hasVisualAsset {
                ExerciseThumbnailView(exercise: exercise, size: size)
            }
            content()
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Text("No asset — text only")
            .font(SheLiftsFont.caption)
        ExerciseThumbnailSlot(exercise: ExerciseCatalog.all[0]) {
            VStack(alignment: .leading) {
                Text(ExerciseCatalog.all[0].name)
                Text(ExerciseCatalog.all[0].listSubtitle)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
    }
    .padding()
}
