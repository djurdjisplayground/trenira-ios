import SwiftUI

struct IronHerLogoView: View {
    var size: CGFloat = 120

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.45, blue: 0.55),
                                Color(red: 0.88, green: 0.25, blue: 0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: Color.rose600.opacity(0.35), radius: 20, y: 10)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-25))
            }

            Text("trenira")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.slate850)

            Text("Strength, on your own terms.")
                .font(.system(size: size * 0.12, weight: .medium))
                .foregroundStyle(Color.slate500)
        }
    }
}

#Preview {
    IronHerLogoView()
        .padding()
}
