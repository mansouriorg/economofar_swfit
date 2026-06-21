import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var insights: DashboardInsightsResponse?

    // Kept for compatibility with your old DashboardView if it still uses recentReceipts.
    @Published var recentReceipts: [Receipt] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dashboardService: DashboardInsightService

    init(dashboardService: DashboardInsightService = .shared) {
        self.dashboardService = dashboardService
    }

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedInsights = try await dashboardService.fetchDashboardInsights()
            insights = loadedInsights
            recentReceipts = mapRecentTicketsToReceipts(loadedInsights.recentTickets)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadDashboard()
    }

    // MARK: - Compatibility with old code

    func fetchRecentReceipts() {
        Task {
            await loadDashboard()
        }
    }

    private func mapRecentTicketsToReceipts(
        _ tickets: [DashboardRecentTicketResponse]
    ) -> [Receipt] {
        tickets.map { ticket in
            Receipt(
                merchantName: ticket.merchantName ?? "Commerçant inconnu",
                totalAmount: ticket.totalAmount ?? 0.0,
                items: []
            )
        }
    }

    // MARK: - Formatting

    func amountText(_ value: Double?) -> String {
        guard let value else {
            return "0,00 €"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
    }

    func simpleAmountText(_ value: Double?) -> String {
        guard let value else {
            return "0,00"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    var totalScannedAmountText: String {
        amountText(insights?.totalScannedAmount)
    }

    var ticketCountText: String {
        "\(insights?.ticketCount ?? 0)"
    }

    var averageBasketText: String {
        amountText(insights?.averageBasket)
    }

    var totalSpentThisWeekText: String {
        amountText(insights?.totalSpentThisWeek)
    }

    var totalSpentThisMonthText: String {
        amountText(insights?.totalSpentThisMonth)
    }

    var totalSpentLastMonthText: String {
        amountText(insights?.totalSpentLastMonth)
    }

    var averageTicketAmountText: String {
        amountText(insights?.averageTicketAmount)
    }

    var monthlyComparisonText: String {
        guard let percentage = insights?.monthlyComparisonPercentage else {
            return "Comparaison indisponible"
        }

        let sign = percentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", percentage))% par rapport au mois dernier"
    }

    var monthlyComparisonIsPositive: Bool {
        guard let percentage = insights?.monthlyComparisonPercentage else {
            return false
        }

        return percentage >= 0
    }

    var mostFrequentMerchantText: String {
        guard let merchant = insights?.mostFrequentMerchant, !merchant.isEmpty else {
            return "Indisponible"
        }

        return merchant
    }

    var highestReceiptText: String {
        guard let insights else {
            return "0,00 €"
        }

        if let merchant = insights.highestReceiptMerchant, !merchant.isEmpty {
            return "\(amountText(insights.highestReceiptAmount)) • \(merchant)"
        }

        return amountText(insights.highestReceiptAmount)
    }

    func formattedDate(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return ""
        }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        guard let date = parser.date(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(from: date)
    }
}
