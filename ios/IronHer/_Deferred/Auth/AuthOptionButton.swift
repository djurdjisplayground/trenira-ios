import SwiftUI

struct AuthOptionButton: View {
    enum Style {
        case apple
        case google
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leadingIcon
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .overlay {
                if style == .google {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch style {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 20, weight: .medium))
        case .google:
            GoogleMark()
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .apple:
            .white
        case .google:
            Color.slate850
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .apple:
            .black
        case .google:
            .white
        }
    }
}

private struct GoogleMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .overlay {
                    Circle().stroke(Color.black.opacity(0.08), lineWidth: 1)
                }

            Text("G")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.52, blue: 0.96),
                            Color(red: 0.98, green: 0.74, blue: 0.02),
                            Color(red: 0.92, green: 0.26, blue: 0.21),
                            Color(red: 0.20, green: 0.66, blue: 0.33)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AuthOptionButton(title: "Sign in with Apple", style: .apple) {}
        AuthOptionButton(title: "Continue with Google", style: .google) {}
    }
    .padding()
}
