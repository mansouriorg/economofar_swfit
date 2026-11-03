import SwiftUI

/// The page of one category: its spending, its rhythm, its main merchants and its latest tickets.
/// It reads the figures from the list screen, so that they are the ones read again when the person
/// comes back from a ticket.
struct CategoryProfileDetailView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var viewModel: CategoryProfilesViewModel

    /// The category to show, and its name when the page was opened.
    let key: String
    let title: String

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let errorMessage = viewModel.errorMessage {
                        DashboardInfoBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: EconomofarUI.danger,
                            background: EconomofarUI.dangerSoft
                        )
                        .padding(.horizontal, -20)
                    }

                    if let profile = viewModel.profile(key: key) {
                        content(profile)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if viewModel.errorMessage == nil {
                        DashboardInfoBanner(
                            icon: "questionmark.circle.fill",
                            message: CategoryProfilesText.notFound,
                            tint: EconomofarUI.accent,
                            background: EconomofarUI.accentSoft
                        )
                        .padding(.horizontal, -20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .refreshable {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .navigationTitle(viewModel.profile(key: key)?.category ?? title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // The first time the list has just read the figures. Coming back from a ticket, they
            // are read again: the ticket may have been changed or deleted there.
            if hasAppeared {
                Task {
                    await viewModel.load(token: sessionManager.token)
                }
            } else {
                hasAppeared = true
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ profile: CategoryProfile) -> some View {
        heroCard(profile)

        rhythmCard(profile)

        if profile.merchants.isEmpty == false {
            merchantsCard(profile)
        }

        ticketsCard(profile)
    }

    private var periodText: String {
        guard let result = viewModel.result else {
            return ""
        }

        return CategoryProfilesText.periodText(result)
    }

    // MARK: Hero

    private func heroCard(_ profile: CategoryProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(periodText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .accessibilityAddTraits(.isHeader)

                Text(AppFormat.money(profile.total))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(CategoryProfilesText.profileSummary(profile))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Tickets", value: "\(profile.ticketCount)")
                heroChip(title: "Panier moyen", value: profile.average.map { AppFormat.money($0) } ?? "-")
                heroChip(title: "Part des dépenses", value: CategoryProfilesText.shareText(profile.share))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title + " : " + value))
    }

    // MARK: Rhythm

    private func rhythmCard(_ profile: CategoryProfile) -> some View {
        DashboardSectionCard(title: "Rythme") {
            DashboardInsightRow(
                icon: "clock.fill",
                title: "Dernier achat",
                subtitle: CategoryProfilesText.dateText(profile.lastDate),
                value: CategoryProfilesText.lastPurchase(profile.daysSinceLast),
                tint: EconomofarUI.accent
            )

            DashboardDivider()

            DashboardInsightRow(
                icon: "calendar",
                title: "Premier achat",
                subtitle: "Sur la période",
                value: CategoryProfilesText.dateText(profile.firstDate),
                tint: EconomofarUI.accent
            )

            DashboardDivider()

            DashboardInsightRow(
                icon: "repeat",
                title: "Fréquence",
                subtitle: CategoryProfilesText.activeDaysText(profile),
                value: CategoryProfilesText.rhythm(profile),
                tint: EconomofarUI.accent
            )
        }
    }

    // MARK: Merchants

    private func merchantsCard(_ profile: CategoryProfile) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: "Enseignes principales") {
                ForEach(Array(profile.merchants.enumerated()), id: \.element.id) { index, merchant in
                    if index > 0 {
                        DashboardDivider()
                    }

                    merchantRow(merchant, in: profile)
                }
            }

            if let note = CategoryProfilesText.merchantsNote(profile) {
                footnote(note)
            }

            if let note = CategoryProfilesText.unknownNote(profile) {
                footnote(note)
            }
        }
    }

    private func merchantRow(_ merchant: CategoryMerchant, in profile: CategoryProfile) -> some View {
        let fraction = CategoryProfilesText.merchantFraction(merchant, in: profile)
        let unknown = CategoryProfilesText.isUnknown(merchant)

        return HStack(alignment: .top, spacing: 14) {
            DashboardIconBox(
                icon: unknown ? "questionmark.circle.fill" : "storefront.fill",
                tint: unknown ? EconomofarUI.textTertiary : EconomofarUI.accent
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(merchant.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(AppFormat.money(merchant.amount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text(CategoryProfilesText.tickets(merchant.ticketCount))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(EconomofarUI.accentSoft)

                        Capsule()
                            .fill(unknown ? EconomofarUI.textTertiary : EconomofarUI.accent)
                            .frame(width: max(proxy.size.width * CGFloat(fraction), fraction > 0 ? 6 : 0))
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Tickets

    private func ticketsCard(_ profile: CategoryProfile) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: "Derniers tickets") {
                ForEach(Array(profile.recent.enumerated()), id: \.element.id) { index, ticket in
                    if index > 0 {
                        DashboardDivider()
                    }

                    ticketRow(ticket)
                }
            }

            if profile.hasMoreTickets {
                footnote(CategoryProfilesText.recentNote(shown: profile.recent.count, total: profile.ticketCount))
            }
        }
    }

    private func ticketRow(_ ticket: CategoryTicket) -> some View {
        NavigationLink {
            ReceiptDetailView(receiptId: ticket.id)
        } label: {
            HStack(spacing: 14) {
                DashboardIconBox(icon: "doc.text.fill", tint: EconomofarUI.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.merchant)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(CategoryProfilesText.dateText(ticket.date))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer(minLength: 8)

                Text(ticket.amount > 0 ? AppFormat.money(ticket.amount) : "Montant manquant")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(ticket.amount > 0 ? EconomofarUI.textPrimary : EconomofarUI.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }

    // MARK: Footnote

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
