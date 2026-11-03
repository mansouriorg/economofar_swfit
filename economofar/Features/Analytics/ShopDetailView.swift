import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class ShopDetailViewModel: ObservableObject {
    @Published var detail: ShopDetail? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?, key: String, months: Int) async {
        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let result = try await ShopsService.shared.fetchDetail(token: token, key: key, months: months)

            if current == generation {
                detail = result
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled, (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    detail = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }
}

// MARK: - Small charts

/// A thin bar that is filled up to a fraction of its width.
private struct ShopsBarGauge: View {
    let fraction: Double
    let tint: Color
    let height: CGFloat

    var body: some View {
        let value = fraction.isFinite ? min(max(fraction, 0), 1) : 0

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.border)

                Capsule()
                    .fill(tint)
                    .frame(width: value > 0 ? max(proxy.size.width * CGFloat(value), height) : 0)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Columns, one for each value, the first on the left. Nothing is drawn for a value of zero but a thin line.
private struct ShopsColumnChart: View {
    let values: [Double]
    let labels: [String]
    let tint: Color
    let spoken: String

    private let chartHeight: CGFloat = 84

    var body: some View {
        let peak = values.filter { $0.isFinite }.max() ?? 0

        return HStack(alignment: .bottom, spacing: values.count > 12 ? 3 : 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(value > 0 ? tint : EconomofarUI.border)
                        .frame(height: height(value, peak: peak))

                    if index < labels.count {
                        Text(labels[index])
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    private func height(_ value: Double, peak: Double) -> CGFloat {
        guard peak > 0, value.isFinite, value > 0 else {
            return 2
        }

        return max(CGFloat(value / peak) * chartHeight, 3)
    }
}

// MARK: - Screen

struct ShopDetailView: View {
    let line: ShopLine
    let months: Int

    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = ShopDetailViewModel()

    init(line: ShopLine, months: Int) {
        self.line = line
        self.months = months
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

                    if let detail = viewModel.detail {
                        content(detail)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else {
                        retryButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .refreshable {
                await viewModel.load(token: sessionManager.token, key: line.key, months: months)
            }
        }
        .navigationTitle(line.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token, key: line.key, months: months)
        }
    }

    private var retryButton: some View {
        Button {
            Task {
                await viewModel.load(token: sessionManager.token, key: line.key, months: months)
            }
        } label: {
            Label("Réessayer", systemImage: "arrow.clockwise")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(EconomofarUI.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ detail: ShopDetail) -> some View {
        heroCard(detail)

        if let status = ShopsText.statusLine(detail.shop) {
            DashboardInfoBanner(
                icon: ShopsText.icon(detail.shop.level),
                message: status,
                tint: tint(detail.shop.level),
                background: softBackground(detail.shop.level)
            )
            .padding(.horizontal, -20)
        }

        if let basket = ShopsText.basketText(detail) {
            DashboardInfoBanner(
                icon: "cart.fill",
                message: basket,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        if detail.shop.recentSpent > 0 || detail.shop.previousSpent > 0 {
            VStack(spacing: 8) {
                evolutionCard(detail.shop)

                footnote(ShopsText.evolutionNote)
            }
        }

        monthsCard(detail)

        if !detail.categories.isEmpty {
            categoriesCard(detail)
        }

        weekdaysCard(detail)

        if !detail.tickets.isEmpty {
            ticketsCard(detail)
        }

        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: ShopsText.detailMethod,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }

    private func tint(_ level: ShopStatus) -> Color {
        switch level {
        case .new:
            return EconomofarUI.accent
        case .fading:
            return EconomofarUI.warning
        case .up:
            return EconomofarUI.danger
        case .down:
            return EconomofarUI.success
        case .steady:
            return EconomofarUI.textSecondary
        }
    }

    private func softBackground(_ level: ShopStatus) -> Color {
        switch level {
        case .new:
            return EconomofarUI.accentSoft
        case .fading:
            return EconomofarUI.warningSoft
        case .up:
            return EconomofarUI.dangerSoft
        case .down:
            return EconomofarUI.successSoft
        case .steady:
            return EconomofarUI.accentSoft
        }
    }

    // MARK: Hero

    private func heroCard(_ detail: ShopDetail) -> some View {
        let shop = detail.shop
        let rhythm: String = shop.averageGapDays.map { WeeklyDigestText.percent($0) + "\u{00A0}j" } ?? "-"

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(shop.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text("Dépensé · " + ShopsText.periodTitle(detail.months))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)

                Text(ShopsText.detailHeadline(shop))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(ShopsText.detailSummary(detail, months: detail.months))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Part des dépenses", value: ShopsText.percentText(shop.sharePercent))
                heroChip(title: "Panier moyen", value: ShopsText.money(shop.averageBasket))
                heroChip(title: "Entre deux visites", value: rhythm)
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
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title + " : " + ShopsText.spoken(value)))
    }

    // MARK: Evolution

    private func evolutionCard(_ shop: ShopLine) -> some View {
        DashboardSectionCard(title: ShopsText.evolutionTitle) {
            plainRow(title: ShopsText.recentTitle, value: ShopsText.money(shop.recentSpent), tint: EconomofarUI.textPrimary)

            DashboardDivider()

            plainRow(title: ShopsText.previousTitle, value: ShopsText.money(shop.previousSpent), tint: EconomofarUI.textPrimary)

            if shop.changePercent != nil {
                DashboardDivider()

                plainRow(title: "Écart", value: ShopsText.signedPercent(shop.changePercent), tint: tint(shop.level))
            }
        }
    }

    private func plainRow(title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Months

    private func monthsCard(_ detail: ShopDetail) -> some View {
        let values = detail.monthly.map { $0.spent }
        let first = detail.monthly.first.map { ShopsText.monthText($0.month) } ?? ""
        let last = detail.monthly.last.map { ShopsText.monthText($0.month) } ?? ""
        let bestText = ShopsText.bestMonthText(detail.monthly)
        let spoken = "Dépenses mois par mois, de \(first) à \(last). " + bestText

        return DashboardSectionCard(title: ShopsText.monthsTitle) {
            VStack(alignment: .leading, spacing: 8) {
                ShopsColumnChart(values: values, labels: [], tint: EconomofarUI.accent, spoken: spoken)
                    .frame(height: 90, alignment: .bottom)

                HStack {
                    Text(first)

                    Spacer()

                    Text(last)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
                .accessibilityHidden(true)

                Text(bestText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            .padding(16)
        }
    }

    // MARK: Categories

    private func categoriesCard(_ detail: ShopDetail) -> some View {
        let biggest = detail.categories.map { $0.spent }.max() ?? 0

        return VStack(spacing: 8) {
            DashboardSectionCard(title: ShopsText.categoriesTitle) {
                ForEach(Array(detail.categories.enumerated()), id: \.element.id) { index, category in
                    if index > 0 {
                        DashboardDivider()
                    }

                    categoryRow(category, biggest: biggest)
                }
            }

            if detail.hiddenCategoryCount > 0 {
                footnote(ShopsText.hiddenCategoriesNote(detail))
            }
        }
    }

    private func categoryRow(_ category: ShopCategory, biggest: Double) -> some View {
        let subtitle: String = category.sharePercent == nil
            ? ShopsText.tickets(category.ticketCount)
            : ShopsText.tickets(category.ticketCount) + " · " + ShopsText.percentText(category.sharePercent)
        let value = ShopsText.money(category.spent)
        let spoken: String = [category.name, value, subtitle].joined(separator: ", ")

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }

            ShopsBarGauge(fraction: biggest > 0 ? category.spent / biggest : 0, tint: EconomofarUI.accent, height: 6)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    // MARK: Days of the week

    private func weekdaysCard(_ detail: ShopDetail) -> some View {
        let days: [Int] = detail.weekdayVisitDays.count == 7 ? detail.weekdayVisitDays : Array(repeating: 0, count: 7)
        let values = days.map { Double($0) }

        return DashboardSectionCard(title: ShopsText.weekdaysTitle) {
            ShopsColumnChart(
                values: values,
                labels: ShopsText.weekdayLetters,
                tint: EconomofarUI.accent,
                spoken: ShopsText.weekdaysAccessibility(days)
            )
            .frame(height: 104, alignment: .bottom)
            .padding(16)
        }
    }

    // MARK: Tickets

    private func ticketsCard(_ detail: ShopDetail) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: ShopsText.ticketsTitle) {
                ForEach(Array(detail.tickets.enumerated()), id: \.offset) { index, ticket in
                    if index > 0 {
                        DashboardDivider()
                    }

                    ticketRow(ticket)
                }
            }

            if detail.hiddenTicketCount > 0 {
                footnote(ShopsText.hiddenTicketsNote(detail))
            }
        }
    }

    private func ticketRow(_ ticket: ShopTicket) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ShopsText.dateText(ticket.date))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)

                Text(ticket.category)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(ShopsText.money(ticket.amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
