import SwiftUI

/// The page of one budget: what was spent, what remains, the pace of the month and the latest tickets
/// of the category. It reads the figures from the list screen, so that they are the ones read again
/// when the person comes back from a ticket.
struct BudgetTrackingDetailView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var viewModel: BudgetTrackingViewModel

    /// The key of the budget.
    let key: String
    /// The name when the page was opened.
    let title: String

    @State private var hasAppeared = false

    private var line: BudgetTrackingLine? {
        viewModel.line(key: key)
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

                    if let line, let overview = viewModel.overview {
                        content(line, overview)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if viewModel.errorMessage == nil {
                        DashboardInfoBanner(
                            icon: "questionmark.circle.fill",
                            message: BudgetTrackingText.notFound,
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
        .navigationTitle(line?.name ?? title)
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
    private func content(_ line: BudgetTrackingLine, _ overview: BudgetTrackingOverview) -> some View {
        heroCard(line, overview)

        if overview.currentMonth {
            paceCard(line, overview)
        }

        if line.ticketCount > 0 {
            ticketsCard(line)
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: BudgetTrackingText.noTicketsInCategory,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Hero

    private func heroCard(_ line: BudgetTrackingLine, _ overview: BudgetTrackingOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(line.name + " · " + BudgetTrackingText.monthTitle(overview.month))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(BudgetTrackingText.money(line.spent))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("sur \(BudgetTrackingText.money(line.budget)) · \(BudgetTrackingText.percentText(line.percentUsed)) · \(BudgetTrackingText.statusTitle(line))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            heroBar(BudgetTrackingText.fraction(spent: line.spent, budget: line.budget))

            HStack(spacing: 10) {
                heroChip(title: line.remaining < 0 ? "Dépassé de" : "Reste", value: BudgetTrackingText.money(abs(line.remaining)))
                heroChip(title: line.ticketCount < 2 ? "Ticket" : "Tickets", value: "\(line.ticketCount)")
                heroChip(title: "Budget", value: BudgetTrackingText.money(line.budget))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroBar(_ fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))

                Capsule()
                    .fill(Color.white)
                    .frame(width: max(proxy.size.width * CGFloat(fraction), fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
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

    // MARK: Pace

    @ViewBuilder
    private func paceCard(_ line: BudgetTrackingLine, _ overview: BudgetTrackingOverview) -> some View {
        if line.projected != nil || line.dailyAllowance != nil {
            VStack(spacing: 8) {
                DashboardSectionCard(title: "Rythme du mois") {
                    if let projected = line.projected {
                        DashboardInsightRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: BudgetTrackingText.projectionTitle,
                            subtitle: BudgetTrackingText.projectionDetail(line),
                            value: BudgetTrackingText.money(projected),
                            tint: line.projectedOver ? EconomofarUI.warning : EconomofarUI.success
                        )
                    }

                    if line.projected != nil && line.dailyAllowance != nil {
                        DashboardDivider()
                    }

                    if let allowance = line.dailyAllowance {
                        DashboardInsightRow(
                            icon: "calendar",
                            title: "Disponible par jour",
                            subtitle: BudgetTrackingText.allowanceDetail(daysLeft: overview.daysLeft),
                            value: BudgetTrackingText.money(allowance),
                            tint: EconomofarUI.accent
                        )
                    }
                }

                if line.projected == nil && overview.dayOfMonth < BudgetTrackingText.projectionFromDay {
                    footnote(BudgetTrackingText.paceNote)
                }
            }
        } else if line.level == .over {
            footnote("Le budget est dépassé : il n'y a plus rien de disponible pour la fin du mois.")
        }
    }

    // MARK: Tickets

    private func ticketsCard(_ line: BudgetTrackingLine) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: "Derniers tickets") {
                ForEach(Array(line.recent.enumerated()), id: \.element.id) { index, ticket in
                    if index > 0 {
                        DashboardDivider()
                    }

                    ticketRow(ticket)
                }
            }

            if line.hasMoreTickets {
                footnote(BudgetTrackingText.recentNote(shown: line.recent.count, total: line.ticketCount))
            }
        }
    }

    private func ticketRow(_ ticket: BudgetTrackingTicket) -> some View {
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

                    Text(BudgetTrackingText.dateText(ticket.date))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer(minLength: 8)

                Text(ticket.amount.map { BudgetTrackingText.money($0) } ?? "Montant manquant")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(ticket.amount != nil ? EconomofarUI.textPrimary : EconomofarUI.textSecondary)
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
