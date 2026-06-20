import SwiftUI

// MARK: - Splash View

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentVisible = false
    @State private var logoBreath = false
    @State private var progressActive = false

    var body: some View {
        ZStack {
            EconomofarMinimalBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 34) {
                    EconomofarMinimalLogo(isAnimating: logoBreath)
                        .opacity(contentVisible ? 1 : 0)
                        .scaleEffect(contentVisible ? 1 : 0.92)
                        .offset(y: contentVisible ? 0 : 14)

                    brandContent
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 14)

                    EconomofarMinimalLoader(isAnimating: progressActive)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 10)
                }
                .padding(.horizontal, 32)

                Spacer()

                footer
                    .opacity(contentVisible ? 1 : 0)
                    .padding(.bottom, 34)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private var brandContent: some View {
        VStack(spacing: 12) {
            Text("Economofar")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .foregroundColor(EconomofarTheme.textPrimary)

            Text("Scannez vos tickets. Suivez vos dépenses.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(EconomofarTheme.accent)

            Text("Données sécurisées")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarTheme.textTertiary)
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.65).delay(0.1)) {
            contentVisible = true
        }

        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            logoBreath = true
        }

        withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: false)) {
            progressActive = true
        }
    }
}

// MARK: - Theme

enum EconomofarTheme {
    static let background = Color(hex: 0xF7F8FA)
    static let backgroundSoftBlue = Color(hex: 0xEEF4FA)

    static let textPrimary = Color(hex: 0x111827)
    static let textSecondary = Color(hex: 0x6B7280)
    static let textTertiary = Color(hex: 0x9CA3AF)

    static let accent = Color(hex: 0x1F5EFF)
    static let accentDark = Color(hex: 0x123A8C)
    static let accentSoft = Color(hex: 0xE8EFFF)

    static let card = Color.white
    static let border = Color(hex: 0xE5E7EB)

    static let logoGradient = LinearGradient(
        colors: [
            accentDark,
            accent
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Background

private struct EconomofarMinimalBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    EconomofarTheme.background,
                    EconomofarTheme.backgroundSoftBlue
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(EconomofarTheme.accent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 55)
                .offset(x: -130, y: -290)

            Circle()
                .fill(EconomofarTheme.accent.opacity(0.06))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
                .offset(x: 150, y: 300)
        }
    }
}

// MARK: - Logo

private struct EconomofarMinimalLogo: View {
    let isAnimating: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(EconomofarTheme.accent.opacity(isAnimating ? 0.11 : 0.07))
                .frame(width: 152, height: 152)
                .blur(radius: isAnimating ? 12 : 8)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(EconomofarTheme.card)
                .frame(width: 126, height: 126)
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(EconomofarTheme.border, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 14)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(EconomofarTheme.logoGradient)
                .frame(width: 82, height: 82)
                .shadow(color: EconomofarTheme.accent.opacity(0.22), radius: 14, x: 0, y: 8)

            Image(systemName: "receipt.fill")
                .font(.system(size: 39, weight: .semibold))
                .foregroundColor(.white)

            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                Image(systemName: "eurosign")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarTheme.accent)
            }
            .offset(x: 39, y: 38)
        }
        .scaleEffect(isAnimating ? 1.025 : 1)
    }
}

// MARK: - Loader

private struct EconomofarMinimalLoader: View {
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("Chargement de votre espace")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarTheme.textSecondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(EconomofarTheme.accentSoft)

                    Capsule()
                        .fill(EconomofarTheme.accent)
                        .frame(
                            width: isAnimating
                            ? geometry.size.width
                            : geometry.size.width * 0.18
                        )
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: 230)
    }
}

// MARK: - Color Helper

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Preview

#Preview {
    SplashView()
}
