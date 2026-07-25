import SwiftUI

struct WorkoutActionButton: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(IronHerTheme.primaryText)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(IronHerTheme.secondaryText.opacity(0.6))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(IronHerTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
        }
    }
}

#Preview {
    WorkoutActionButton(
        title: "Create a workout",
        subtitle: "Build a new routine from scratch",
        icon: "plus"
    )
    .padding()
    .background(IronHerTheme.background)
}
