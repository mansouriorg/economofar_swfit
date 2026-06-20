import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @State private var notificationsEnabled = true
    @State private var faceIDEnabled = false
    @State private var showLogoutConfirmation = false

    private var firstName: String {
        sessionManager.currentUser?.firstName ?? "Utilisateur"
    }

    private var lastName: String {
        sessionManager.currentUser?.lastName ?? ""
    }

    private var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var email: String {
        sessionManager.currentUser?.email ?? "email@exemple.com"
    }

    private var avatarLetter: String {
        String(firstName.prefix(1)).uppercased()
    }

    private var roleText: String {
        sessionManager.currentUser?.role == .admin ? "Administrateur" : "Staff"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsDesign.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        profileCard
                        generalSection
                        securitySection
                        supportSection
                        logoutSection
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Voulez-vous vraiment vous déconnecter ?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Se déconnecter", role: .destructive) {
                    sessionManager.logout()
                }

                Button("Annuler", role: .cancel) { }
            }
        }
    }

    private var profileCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                SettingsAvatarView(letter: avatarLetter)

                VStack(alignment: .leading, spacing: 6) {
                    Text(fullName.isEmpty ? "Utilisateur" : fullName)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(SettingsDesign.textPrimary)
                        .lineLimit(1)

                    Text(email)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(SettingsDesign.textSecondary)
                        .lineLimit(1)

                    Text(roleText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(SettingsDesign.accent)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(SettingsDesign.accentSoft)
                        .clipShape(Capsule())
                        .padding(.top, 2)
                }

                Spacer()
            }

            Divider()
                .background(SettingsDesign.border)

            HStack(spacing: 10) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SettingsDesign.success)

                Text("Compte sécurisé")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SettingsDesign.textSecondary)

                Spacer()

                Text("Economofar")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(SettingsDesign.textTertiary)
            }
        }
        .padding(20)
        .background(SettingsDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(SettingsDesign.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.045), radius: 18, x: 0, y: 10)
    }

    private var generalSection: some View {
        SettingsSectionCard(title: "Général") {
            SettingsToggleRow(
                icon: "bell",
                title: "Notifications",
                subtitle: "Recevoir les alertes importantes",
                tint: SettingsDesign.accent,
                isOn: $notificationsEnabled
            )
        }
    }

    private var securitySection: some View {
        SettingsSectionCard(title: "Sécurité") {
            SettingsToggleRow(
                icon: "faceid",
                title: "Verrouillage Face ID",
                subtitle: "Protéger l’accès à l’application",
                tint: SettingsDesign.success,
                isOn: $faceIDEnabled
            )
        }
    }

    private var supportSection: some View {
        SettingsSectionCard(title: "Assistance") {
            NavigationLink {
                HelpSupportPlaceholderView()
            } label: {
                SettingsNavigationRow(
                    icon: "questionmark.circle",
                    title: "Aide & Support",
                    subtitle: "Obtenir de l’aide avec Economofar",
                    tint: SettingsDesign.accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var logoutSection: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(SettingsDesign.dangerSoft)
                        .frame(width: 46, height: 46)

                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(SettingsDesign.danger)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Se déconnecter")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(SettingsDesign.danger)

                    Text("Quitter votre session actuelle")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(SettingsDesign.textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .background(SettingsDesign.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(SettingsDesign.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Economofar")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(SettingsDesign.textSecondary)

            Text("Version 1.0.0")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(SettingsDesign.textTertiary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Design System

private enum SettingsDesign {
    static let background = color(0xF7F8FA)
    static let card = Color.white
    static let cardSoft = color(0xF1F5FB)

    static let textPrimary = color(0x111827)
    static let textSecondary = color(0x6B7280)
    static let textTertiary = color(0x9CA3AF)

    static let accent = color(0x1F5EFF)
    static let accentDark = color(0x123A8C)
    static let accentSoft = color(0xE8EFFF)

    static let success = color(0x0F8554)
    static let successSoft = color(0xE8F8EF)

    static let danger = color(0xDC2626)
    static let dangerSoft = color(0xFEE2E2)

    static let border = color(0xE5E7EB)

    private static func color(_ hex: UInt, alpha: Double = 1.0) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Avatar

private struct SettingsAvatarView: View {
    let letter: String

    var body: some View {
        ZStack {
            Circle()
                .fill(SettingsDesign.accentSoft)
                .frame(width: 64, height: 64)

            Circle()
                .stroke(SettingsDesign.border, lineWidth: 1)
                .frame(width: 64, height: 64)

            Text(letter)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(SettingsDesign.accent)
        }
    }
}

// MARK: - Section Card

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(SettingsDesign.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(SettingsDesign.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(SettingsDesign.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
        }
    }
}

// MARK: - Toggle Row

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            SettingsIconBox(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(SettingsDesign.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(SettingsDesign.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SettingsDesign.accent)
        }
        .padding(16)
    }
}

// MARK: - Navigation Row

private struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            SettingsIconBox(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(SettingsDesign.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(SettingsDesign.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(SettingsDesign.textTertiary)
        }
        .padding(16)
    }
}

// MARK: - Icon Box

private struct SettingsIconBox: View {
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(tint.opacity(0.11))
                .frame(width: 46, height: 46)

            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
        }
    }
}

// MARK: - Help Placeholder

private struct HelpSupportPlaceholderView: View {
    var body: some View {
        ZStack {
            SettingsDesign.background
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(SettingsDesign.accentSoft)
                        .frame(width: 86, height: 86)

                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(SettingsDesign.accent)
                }

                VStack(spacing: 8) {
                    Text("Aide & Support")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(SettingsDesign.textPrimary)

                    Text("Cette page pourra contenir votre FAQ, contact support ou centre d’aide.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(SettingsDesign.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 32)
                }
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SessionManager())
}
