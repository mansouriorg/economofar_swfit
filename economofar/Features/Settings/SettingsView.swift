import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @StateObject private var viewModel = SettingsViewModel()

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

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsDesign.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        profileCard
                        profileSection

                        if let errorMessage = viewModel.errorMessage {
                            SettingsInfoBanner(
                                icon: "exclamationmark.triangle.fill",
                                message: errorMessage,
                                tint: SettingsDesign.danger,
                                background: SettingsDesign.dangerSoft
                            )
                        }

                        if let successMessage = viewModel.successMessage {
                            SettingsInfoBanner(
                                icon: "checkmark.circle.fill",
                                message: successMessage,
                                tint: SettingsDesign.success,
                                background: SettingsDesign.successSoft
                            )
                        }

                        notificationsSection
                        budgetSection
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
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
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

    private var profileSection: some View {
        SettingsSectionCard(title: "Profil") {
            NavigationLink {
                EditProfileView()
            } label: {
                SettingsNavigationRow(
                    icon: "person.crop.circle",
                    title: "Modifier mon profil",
                    subtitle: "Nom, email, entreprise, devise et langue",
                    tint: SettingsDesign.accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var notificationsSection: some View {
        SettingsSectionCard(title: "Notifications") {
            if viewModel.isLoadingPreferences {
                SettingsLoadingRow(
                    icon: "bell",
                    title: "Chargement des préférences",
                    subtitle: "Synchronisation avec votre compte",
                    tint: SettingsDesign.accent
                )
            } else {
                SettingsToggleRow(
                    icon: "bell.badge",
                    title: "Notifications intégrées",
                    subtitle: "Activer ou désactiver toutes les alertes",
                    tint: SettingsDesign.accent,
                    isOn: preferenceBinding(
                        \.inAppEnabled,
                        request: { UpdateNotificationPreferencesRequest(inAppEnabled: $0) }
                    )
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "doc.text.viewfinder",
                    title: "Analyse de ticket terminée",
                    subtitle: "Alerte après l’analyse OCR d’un ticket",
                    tint: SettingsDesign.accent,
                    isOn: preferenceBinding(
                        \.ticketAnalysisCompleted,
                        request: { UpdateNotificationPreferencesRequest(ticketAnalysisCompleted: $0) }
                    )
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "calendar",
                    title: "Résumé mensuel",
                    subtitle: "Recevoir le total dépensé chaque mois",
                    tint: SettingsDesign.accent,
                    isOn: preferenceBinding(
                        \.monthlySpendingSummary,
                        request: { UpdateNotificationPreferencesRequest(monthlySpendingSummary: $0) }
                    )
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "exclamationmark.triangle",
                    title: "Dépense inhabituelle",
                    subtitle: "Détection des montants anormalement élevés",
                    tint: SettingsDesign.warning,
                    isOn: preferenceBinding(
                        \.unusualSpending,
                        request: { UpdateNotificationPreferencesRequest(unusualSpending: $0) }
                    )
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Budget dépassé",
                    subtitle: "Alerte lorsque votre budget mensuel est dépassé",
                    tint: SettingsDesign.danger,
                    isOn: preferenceBinding(
                        \.budgetExceeded,
                        request: { UpdateNotificationPreferencesRequest(budgetExceeded: $0) }
                    )
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "calendar.badge.clock",
                    title: "Rapport hebdomadaire",
                    subtitle: "Recevoir un résumé de vos tickets chaque semaine",
                    tint: SettingsDesign.success,
                    isOn: preferenceBinding(
                        \.weeklyExpenseReport,
                        request: { UpdateNotificationPreferencesRequest(weeklyExpenseReport: $0) }
                    )
                )

                SettingsDivider()

                NavigationLink {
                    NotificationsView()
                } label: {
                    SettingsNavigationRow(
                        icon: "bell",
                        title: "Voir mes notifications",
                        subtitle: "Consulter l’historique des alertes",
                        tint: SettingsDesign.accent
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var budgetSection: some View {
        SettingsSectionCard(title: "Budget mensuel") {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    SettingsIconBox(icon: "wallet.pass", tint: SettingsDesign.success)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Définir un budget")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(SettingsDesign.textPrimary)

                        Text("Recevez une alerte si le budget est dépassé")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(SettingsDesign.textSecondary)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    TextField("Ex: 800", text: $viewModel.monthlyBudgetText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(SettingsDesign.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(SettingsDesign.cardSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(SettingsDesign.border, lineWidth: 1)
                        }

                    Text(viewModel.currency)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(SettingsDesign.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(SettingsDesign.cardSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(SettingsDesign.border, lineWidth: 1)
                        }
                }

                Button {
                    Task {
                        await viewModel.saveBudget()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isSavingBudget {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }

                        Text(viewModel.isSavingBudget ? "Enregistrement..." : "Enregistrer le budget")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SettingsDesign.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: SettingsDesign.accent.opacity(0.18), radius: 12, x: 0, y: 7)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSavingBudget)
            }
            .padding(16)
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
                HelpSupportView()
            } label: {
                SettingsNavigationRow(
                    icon: "questionmark.circle",
                    title: "Aide & Support",
                    subtitle: "FAQ, contact support, bugs et statut de l’application",
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

            Text("Version \(appVersion)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(SettingsDesign.textTertiary)
        }
        .padding(.top, 4)
    }

    private func preferenceBinding(
        _ keyPath: WritableKeyPath<NotificationPreferences, Bool>,
        request: @escaping (Bool) -> UpdateNotificationPreferencesRequest
    ) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.preferences[keyPath: keyPath]
            },
            set: { newValue in
                viewModel.preferences[keyPath: keyPath] = newValue

                Task {
                    await viewModel.updatePreferences(request(newValue))
                }
            }
        )
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

    static let warning = color(0xB7791F)
    static let warningSoft = color(0xFFF7E6)

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

// MARK: - Divider

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(SettingsDesign.border)
            .padding(.leading, 76)
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
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SettingsDesign.accent)
        }
        .padding(16)
    }
}

// MARK: - Loading Row

private struct SettingsLoadingRow: View {
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

            ProgressView()
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
                    .lineLimit(2)
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

// MARK: - Info Banner

private struct SettingsInfoBanner: View {
    let icon: String
    let message: String
    let tint: Color
    let background: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SessionManager())
}
