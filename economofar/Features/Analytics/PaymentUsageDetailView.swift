import SwiftUI

/// The page of one payment method, or of the tickets that have none: its spending month by month,
/// its main categories and its latest tickets. It reads the figures from the list screen, so that
/// they are the ones read again when the person comes back from a ticket.
struct PaymentUsageDetailView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var viewModel: PaymentUsageViewModel

    /// The key of the payment method, or, without key, the tickets that have no payment method.
    let key: String?
    /// The name when the page was opened.
    let title: String

    @State private var hasAppeared = false

    private let chartHeight: CGFloat = 96

    /// The figures that the page shows.
    private struct Figures {
        let name: String
        let ticketCount: Int
        let amount: Double
        /// Nil for the tickets without payment method.
        let average: Double?
        let share: Double?
        /// The date of the latest ticket and the days since, nil for the tickets without method.
        let lastDate: String?
        let daysSinceLast: Int?
        /// Empty for the tickets without payment method.
        let months: [PaymentUsageMonth]
        let categoryCount: Int
        let categories: [PaymentUsageCategory]
        let tickets: [PaymentUsageTicket]

        var hasMoreTickets: Bool {
            tickets.count < ticketCount
        }

        var hasMoreCategories: Bool {
            categories.count < categoryCount
        }
    }

    private var figures: Figures? {
        guard let result = viewModel.result else {
            return nil
        }

        if let key {
            guard let method = viewModel.method(key: key) else {
                return nil
            }

            return Figures(
                name: method.name,
                ticketCount: method.ticketCount,
                amount: method.amount,
                average: method.average,
                share: method.share,
                lastDate: method.lastDate,
                daysSinceLast: method.daysSinceLast,
                months: method.months,
                categoryCount: method.categoryCount,
                categories: method.categories,
                tickets: method.recent
            )
        }

        guard result.unspecifiedCount > 0 else {
            return nil
        }

        return Figures(
            name: PaymentUsageText.unspecifiedTitle,
            ticketCount: result.unspecifiedCount,
            amount: result.unspecifiedAmount,
            average: nil,
            share: PaymentUsageText.percent(result.unspecifiedAmount, of: result.totalAmount),
            lastDate: nil,
            daysSinceLast: nil,
            months: [],
            categoryCount: 0,
            categories: [],
            tickets: result.unspecified
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
                            message: key == nil ? PaymentUsageText.allSetMessage : PaymentUsageText.notFound,
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
                message: PaymentUsageText.unspecifiedAdvice,
                tint: EconomofarUI.warning,
                background: EconomofarUI.warningSoft
            )
            .padding(.horizontal, -20)
        } else {
            monthsCard(figures)

            if figures.categories.isEmpty == false {
                categoriesCard(figures)
            }
        }

        ticketsCard(figures)
    }

    private var periodText: String {
        guard let result = viewModel.result else {
            return ""
        }

        return PaymentUsageText.periodText(result)
    }

    // MARK: Hero

    private func heroCard(_ figures: Figures) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text((key == nil ? "Moyens de paiement" : "Moyen de paiement") + " · " + periodText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(figures.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(PaymentUsageText.money(figures.amount))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(summary(figures))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if let lastDate = figures.lastDate, let days = figures.daysSinceLast {
                    Text(PaymentUsageText.lastPaymentText(date: lastDate, days: days))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                heroChip(title: "Tickets", value: "\(figures.ticketCount)")

                if key != nil {
                    heroChip(title: "Panier moyen", value: PaymentUsageText.averageText(figures.average))
                }

                heroChip(title: "Part des dépenses", value: PaymentUsageText.shareText(figures.share))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summary(_ figures: Figures) -> String {
        if key == nil {
            return "\(PaymentUsageText.unspecifiedDetail(count: figures.ticketCount))."
        }

        return PaymentUsageText.methodSummary(share: figures.share, count: figures.ticketCount)
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

    // MARK: Months

    private func monthsCard(_ figures: Figures) -> some View {
        let maximum = figures.months.map { $0.amount }.filter { $0.isFinite }.max() ?? 0

        return DashboardSectionCard(title: "Mois par mois") {
            VStack(alignment: .leading, spacing: 12) {
                if maximum > 0 {
                    chart(figures.months, maximum: maximum)
                } else {
                    Text(PaymentUsageText.noAmount)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(PaymentUsageText.monthNote)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private func chart(_ months: [PaymentUsageMonth], maximum: Double) -> some View {
        HStack(alignment: .bottom, spacing: months.count > 12 ? 3 : 6) {
            ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                column(month, index: index, count: months.count, maximum: maximum)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func column(_ month: PaymentUsageMonth, index: Int, count: Int, maximum: Double) -> some View {
        let fraction = PaymentUsageText.barFraction(month.amount, maximum: maximum)
        let height = month.amount > 0 ? max(CGFloat(fraction) * chartHeight, 4) : 2

        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(month.amount > 0 ? EconomofarUI.accent : EconomofarUI.accentSoft)
                .frame(maxWidth: 18)
                .frame(height: height)

            Color.clear
                .frame(height: 12)
                .overlay {
                    Text(PaymentUsageText.monthLabel(month.month))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .lineLimit(1)
                        .fixedSize()
                        .opacity(showsLabel(index: index, count: count) ? 1 : 0)
                }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(PaymentUsageText.monthAccessibility(month)))
    }

    /// Up to 12 months every month has its name; beyond, one month in four, the latest included.
    private func showsLabel(index: Int, count: Int) -> Bool {
        if count <= 12 {
            return true
        }

        return (count - 1 - index) % 4 == 0
    }

    // MARK: Categories

    private func categoriesCard(_ figures: Figures) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: "Catégories") {
                ForEach(Array(figures.categories.enumerated()), id: \.element.id) { index, category in
                    if index > 0 {
                        DashboardDivider()
                    }

                    DashboardInsightRow(
                        icon: "tag.fill",
                        title: category.name,
                        subtitle: PaymentUsageText.tickets(category.ticketCount),
                        value: PaymentUsageText.money(category.amount),
                        tint: EconomofarUI.accent
                    )
                }
            }

            if figures.hasMoreCategories {
                footnote(PaymentUsageText.categoriesNote(shown: figures.categories.count, total: figures.categoryCount))
            }
        }
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
                footnote(PaymentUsageText.recentNote(shown: figures.tickets.count, total: figures.ticketCount))
            }
        }
    }

    private func ticketRow(_ ticket: PaymentUsageTicket) -> some View {
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

                    Text(PaymentUsageText.dateText(ticket.date))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer(minLength: 8)

                Text(ticket.amount > 0 ? PaymentUsageText.money(ticket.amount) : "Montant manquant")
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
