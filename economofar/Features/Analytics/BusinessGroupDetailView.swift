import SwiftUI

/// The page of one expense report, project or client, or of the business tickets that have none:
/// its spending, its VAT and its latest tickets. It reads the figures from the list screen, so that
/// they are the ones read again when the person comes back from a ticket.
struct BusinessGroupDetailView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var viewModel: BusinessExpensesViewModel

    /// What the page is about: a group of this kind with this key, or, without key, the tickets
    /// that have no label of this kind.
    let kind: BusinessSectionKind
    let key: String?
    /// The name when the page was opened.
    let title: String

    @State private var hasAppeared = false

    /// The figures that the page shows.
    private struct Figures {
        let name: String
        let ticketCount: Int
        let amount: Double
        /// Nil for the tickets without label: the VAT of a group only.
        let vat: Double?
        let tickets: [BusinessTicket]

        var hasMoreTickets: Bool {
            tickets.count < ticketCount
        }
    }

    private var figures: Figures? {
        guard let result = viewModel.result else {
            return nil
        }

        let section = result.section(kind)

        if let key {
            guard let group = viewModel.group(kind: kind, key: key) else {
                return nil
            }

            return Figures(
                name: group.name,
                ticketCount: group.ticketCount,
                amount: group.amount,
                vat: group.vat,
                tickets: group.recent
            )
        }

        guard section.missingCount > 0 else {
            return nil
        }

        return Figures(
            name: kind.missingTitle,
            ticketCount: section.missingCount,
            amount: section.missingAmount,
            vat: nil,
            tickets: section.missing
        )
    }

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

                    if let figures {
                        content(figures)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if viewModel.errorMessage == nil {
                        DashboardInfoBanner(
                            icon: key == nil ? "checkmark.circle.fill" : "questionmark.circle.fill",
                            message: key == nil ? kind.allSetMessage : BusinessExpensesText.notFound,
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
        .navigationTitle(figures?.name ?? title)
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
    private func content(_ figures: Figures) -> some View {
        heroCard(figures)

        if key == nil {
            DashboardInfoBanner(
                icon: "lightbulb.fill",
                message: kind.missingAdvice,
                tint: EconomofarUI.warning,
                background: EconomofarUI.warningSoft
            )
            .padding(.horizontal, -20)
        }

        ticketsCard(figures)
    }

    private var periodText: String {
        guard let result = viewModel.result else {
            return ""
        }

        return BusinessExpensesText.periodText(result)
    }

    private var businessTotal: Double {
        viewModel.result?.totalAmount ?? 0
    }

    // MARK: Hero

    private func heroCard(_ figures: Figures) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(kind.title + " · " + periodText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(figures.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(BusinessExpensesText.money(figures.amount))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(summary(figures))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Tickets", value: "\(figures.ticketCount)")

                if let vat = figures.vat {
                    heroChip(title: "TVA", value: BusinessExpensesText.money(vat))
                }

                heroChip(title: "Part des frais", value: BusinessExpensesText.groupShareText(figures.amount, of: businessTotal))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summary(_ figures: Figures) -> String {
        if key == nil {
            return "\(BusinessExpensesText.missingDetail(count: figures.ticketCount))."
        }

        return BusinessExpensesText.groupSummary(amount: figures.amount, total: businessTotal, count: figures.ticketCount)
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

    // MARK: Tickets

    private func ticketsCard(_ figures: Figures) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: key == nil ? "Tickets à compléter" : "Derniers tickets") {
                ForEach(Array(figures.tickets.enumerated()), id: \.element.id) { index, ticket in
                    if index > 0 {
                        DashboardDivider()
                    }

                    ticketRow(ticket)
                }
            }

            if figures.hasMoreTickets {
                footnote(BusinessExpensesText.recentNote(shown: figures.tickets.count, total: figures.ticketCount))
            }
        }
    }

    private func ticketRow(_ ticket: BusinessTicket) -> some View {
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

                    Text(BusinessExpensesText.dateText(ticket.date))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer(minLength: 8)

                Text(ticket.amount > 0 ? BusinessExpensesText.money(ticket.amount) : "Montant manquant")
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
