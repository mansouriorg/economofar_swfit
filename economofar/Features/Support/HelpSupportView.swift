import SwiftUI

struct HelpSupportView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.openURL) private var openURL

    @StateObject private var viewModel = SupportViewModel()

    private var userEmail: String? {
        sessionManager.currentUser?.email
    }

    var body: some View {
        ZStack {
            SupportDesign.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header

                    if viewModel.isLoading {
                        loadingCard
                    }

                    if let errorMessage = viewModel.errorMessage {
                        supportBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: SupportDesign.danger,
                            background: SupportDesign.dangerSoft
                        )
                    }

                    if let successMessage = viewModel.successMessage {
                        supportBanner(
                            icon: "checkmark.circle.fill",
                            message: successMessage,
                            tint: SupportDesign.success,
                            background: SupportDesign.successSoft
                        )
                    }

                    statusSection
                    faqSection
                    contactSection
                    bugReportSection
                    legalSection
                    myRequestsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Aide & Support")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.load()
            await viewModel.loadMyRequests()
        }
        .refreshable {
            await viewModel.load()
            await viewModel.loadMyRequests()
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(SupportDesign.accentSoft)
                    .frame(width: 78, height: 78)

                Image(systemName: "questionmark.circle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(SupportDesign.accent)
            }

            VStack(spacing: 8) {
                Text("Comment pouvons-nous vous aider ?")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(SupportDesign.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Consultez la FAQ, contactez le support ou signalez un bug.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SupportDesign.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(SupportDesign.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Chargement du support")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(SupportDesign.textPrimary)

                Text("Récupération de la FAQ et du statut.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(SupportDesign.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(SupportDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(SupportDesign.border, lineWidth: 1)
        }
    }

    private var statusSection: some View {
        SupportSectionCard(title: "Statut de l’application") {
            HStack(spacing: 14) {
                SupportIconBox(
                    icon: statusIcon,
                    tint: statusTint
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(statusTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(SupportDesign.textPrimary)

                    Text(viewModel.appStatus?.message ?? "Statut indisponible pour le moment.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(SupportDesign.textSecondary)
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(16)
        }
    }

    private var faqSection: some View {
        SupportSectionCard(title: "FAQ") {
            if viewModel.faqs.isEmpty && !viewModel.isLoading {
                emptyRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Aucune FAQ disponible",
                    subtitle: "Les questions fréquentes apparaîtront ici."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.faqs) { item in
                        DisclosureGroup {
                            Text(item.answer)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(SupportDesign.textSecondary)
                                .lineSpacing(3)
                                .padding(.top, 8)
                                .padding(.bottom, 12)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.question)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(SupportDesign.textPrimary)

                                Text(item.category)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(SupportDesign.accent)
                            }
                        }
                        .tint(SupportDesign.accent)
                        .padding(16)

                        if item.id != viewModel.faqs.last?.id {
                            SupportDivider()
                        }
                    }
                }
            }
        }
    }

    private var contactSection: some View {
        SupportSectionCard(title: "Contacter le support") {
            VStack(spacing: 14) {
                supportTextField(
                    title: "Sujet",
                    placeholder: "Ex: Problème avec mon compte",
                    text: $viewModel.contactSubject
                )

                supportTextEditor(
                    title: "Message",
                    placeholder: "Expliquez votre demande...",
                    text: $viewModel.contactMessage
                )

                Button {
                    Task {
                        await viewModel.sendContact(contactEmail: userEmail)
                    }
                } label: {
                    supportButtonLabel(
                        icon: "paperplane.fill",
                        title: viewModel.isSendingContact ? "Envoi en cours..." : "Envoyer au support",
                        isLoading: viewModel.isSendingContact
                    )
                }
                .disabled(viewModel.isSendingContact)
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }

    private var bugReportSection: some View {
        SupportSectionCard(title: "Signaler un bug") {
            VStack(spacing: 14) {
                supportTextField(
                    title: "Bug rencontré",
                    placeholder: "Ex: Le scanner se ferme tout seul",
                    text: $viewModel.bugSubject
                )

                supportTextEditor(
                    title: "Description",
                    placeholder: "Décrivez les étapes pour reproduire le bug...",
                    text: $viewModel.bugMessage
                )

                Button {
                    Task {
                        await viewModel.sendBugReport(contactEmail: userEmail)
                    }
                } label: {
                    supportButtonLabel(
                        icon: "ladybug.fill",
                        title: viewModel.isSendingBug ? "Signalement..." : "Signaler le bug",
                        isLoading: viewModel.isSendingBug
                    )
                }
                .disabled(viewModel.isSendingBug)
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }

    private var legalSection: some View {
        SupportSectionCard(title: "Informations légales") {
            VStack(spacing: 0) {
                if let supportEmail = viewModel.supportConfig?.supportEmail {
                    Button {
                        openEmail(supportEmail)
                    } label: {
                        SupportNavigationRow(
                            icon: "envelope",
                            title: "Email support",
                            subtitle: supportEmail,
                            tint: SupportDesign.accent
                        )
                    }
                    .buttonStyle(.plain)

                    SupportDivider()
                }

                Button {
                    openURLString(viewModel.supportConfig?.termsUrl)
                } label: {
                    SupportNavigationRow(
                        icon: "doc.text",
                        title: "Conditions d’utilisation",
                        subtitle: "Lire les conditions générales",
                        tint: SupportDesign.textSecondary
                    )
                }
                .buttonStyle(.plain)

                SupportDivider()

                Button {
                    openURLString(viewModel.supportConfig?.privacyUrl)
                } label: {
                    SupportNavigationRow(
                        icon: "lock.shield",
                        title: "Politique de confidentialité",
                        subtitle: "Consulter la protection des données",
                        tint: SupportDesign.success
                    )
                }
                .buttonStyle(.plain)

                SupportDivider()

                Button {
                    openURLString(viewModel.supportConfig?.statusPageUrl)
                } label: {
                    SupportNavigationRow(
                        icon: "waveform.path.ecg",
                        title: "Page de statut",
                        subtitle: "Voir l’état des services Economofar",
                        tint: statusTint
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var myRequestsSection: some View {
        SupportSectionCard(title: "Mes demandes") {
            if viewModel.myRequests.isEmpty {
                emptyRow(
                    icon: "tray",
                    title: "Aucune demande envoyée",
                    subtitle: "Vos demandes de support apparaîtront ici."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.myRequests) { request in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(request.subject)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(SupportDesign.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text(statusLabel(request.status))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(SupportDesign.accent)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(SupportDesign.accentSoft)
                                    .clipShape(Capsule())
                            }

                            Text(request.type == "BUG_REPORT" ? "Bug report" : "Contact support")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(SupportDesign.textTertiary)

                            Text(request.message)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(SupportDesign.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(16)

                        if request.id != viewModel.myRequests.last?.id {
                            SupportDivider()
                        }
                    }
                }
            }
        }
    }

    private var statusTitle: String {
        switch viewModel.appStatus?.status {
        case "OPERATIONAL":
            return "Tous les services sont opérationnels"
        case "DEGRADED":
            return "Service partiellement dégradé"
        default:
            return "Statut indisponible"
        }
    }

    private var statusIcon: String {
        switch viewModel.appStatus?.status {
        case "OPERATIONAL":
            return "checkmark.seal.fill"
        case "DEGRADED":
            return "exclamationmark.triangle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    private var statusTint: Color {
        switch viewModel.appStatus?.status {
        case "OPERATIONAL":
            return SupportDesign.success
        case "DEGRADED":
            return SupportDesign.warning
        default:
            return SupportDesign.textSecondary
        }
    }

    private func supportTextField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(SupportDesign.textSecondary)

            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(14)
                .background(SupportDesign.cardSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SupportDesign.border, lineWidth: 1)
                }
        }
    }

    private func supportTextEditor(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(SupportDesign.textSecondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 105)
                    .padding(10)
                    .background(SupportDesign.cardSoft)

                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(SupportDesign.textTertiary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SupportDesign.border, lineWidth: 1)
            }
        }
    }

    private func supportButtonLabel(
        icon: String,
        title: String,
        isLoading: Bool
    ) -> some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(SupportDesign.accent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: SupportDesign.accent.opacity(0.16), radius: 12, x: 0, y: 7)
    }

    private func emptyRow(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 14) {
            SupportIconBox(icon: icon, tint: SupportDesign.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(SupportDesign.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(SupportDesign.textSecondary)
            }

            Spacer()
        }
        .padding(16)
    }

    private func supportBanner(
        icon: String,
        message: String,
        tint: Color,
        background: Color
    ) -> some View {
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
    }

    private func openURLString(_ value: String?) {
        guard
            let value,
            let url = URL(string: value)
        else {
            return
        }

        openURL(url)
    }

    private func openEmail(_ email: String) {
        guard let url = URL(string: "mailto:\(email)") else {
            return
        }

        openURL(url)
    }

    private func statusLabel(_ value: String) -> String {
        switch value {
        case "OPEN":
            return "Ouverte"
        case "IN_PROGRESS":
            return "En cours"
        case "RESOLVED":
            return "Résolue"
        case "CLOSED":
            return "Fermée"
        default:
            return value
        }
    }
}

// MARK: - Components

private struct SupportSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(SupportDesign.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(SupportDesign.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(SupportDesign.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
        }
    }
}

private struct SupportIconBox: View {
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

private struct SupportNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            SupportIconBox(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(SupportDesign.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(SupportDesign.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(SupportDesign.textTertiary)
        }
        .padding(16)
    }
}

private struct SupportDivider: View {
    var body: some View {
        Divider()
            .background(SupportDesign.border)
            .padding(.leading, 76)
    }
}

// MARK: - Design

private enum SupportDesign {
    static let background = color(0xF7F8FA)
    static let card = Color.white
    static let cardSoft = color(0xF1F5FB)

    static let textPrimary = color(0x111827)
    static let textSecondary = color(0x6B7280)
    static let textTertiary = color(0x9CA3AF)

    static let accent = color(0x1F5EFF)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        HelpSupportView()
            .environmentObject(SessionManager())
    }
}
