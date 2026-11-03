import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var insights: DashboardInsightsResponse?

    // Kept for compatibility with older DashboardView code if it still uses recentReceipts.
    @Published var recentReceipts: [Receipt] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dashboardService: DashboardInsightService

    init(dashboardService: DashboardInsightService = .shared) {
        self.dashboardService = dashboardService
    }

    // MARK: - Loading

    func loadDashboard(token: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedInsights = try await dashboardService.fetchDashboardInsights(token: token)
            insights = loadedInsights
            recentReceipts = mapRecentTicketsToReceipts(loadedInsights.recentTickets)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh(token: String? = nil) async {
        await loadDashboard(token: token)
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

    // MARK: - Smart Cards

    var monthlyTotalText: String {
        amountText(insights?.totalSpentThisMonth)
    }

    var ticketCountText: String {
        "\(insights?.ticketCount ?? 0)"
    }

    var averageBasketText: String {
        amountText(insights?.averageBasket)
    }

    var topMerchantText: String {
        guard let merchant = insights?.mostFrequentMerchant, !merchant.isEmpty else {
            return "Indisponible"
        }

        return merchant
    }

    var budgetRemainingText: String {
        guard let insights else {
            return AppFormat.money(0)
        }

        guard let monthlyBudget = insights.monthlyBudget, monthlyBudget > 0 else {
            return "Non défini"
        }

        return amountText(insights.budgetRemaining)
    }

    var budgetRemainingSubtitle: String {
        guard let insights else {
            return "Budget mensuel"
        }

        guard let monthlyBudget = insights.monthlyBudget, monthlyBudget > 0 else {
            return "Ajoutez un budget"
        }

        if insights.budgetExceeded == true {
            return "Budget dépassé"
        }

        return "Budget restant"
    }

    var isBudgetExceeded: Bool {
        insights?.budgetExceeded == true
    }

    func lastScanStatusText(
        isScanning: Bool,
        isScanReady: Bool
    ) -> String {
        if isScanning {
            return "Analyse en cours"
        }

        if isScanReady {
            return "Analyse terminée"
        }

        guard let status = insights?.lastScanStatus else {
            return "Prêt à scanner"
        }

        switch status {
        case "COMPLETED":
            return "Dernier scan OK"
        case "READY_TO_SCAN":
            return "Prêt à scanner"
        default:
            return "Prêt à scanner"
        }
    }

    func lastScanSubtitle(
        isScanning: Bool,
        isScanReady: Bool
    ) -> String {
        if isScanning {
            return "Traitement du ticket"
        }

        if isScanReady {
            return "Touchez pour vérifier"
        }

        if let merchant = insights?.lastScanMerchant, !merchant.isEmpty {
            if let amount = insights?.lastScanAmount {
                return "\(merchant) • \(amountText(amount))"
            }

            return merchant
        }

        if let date = insights?.lastScanDate, !date.isEmpty {
            return formattedDate(date)
        }

        return "Aucun scan récent"
    }

    // MARK: - Dashboard Texts

    var totalScannedAmountText: String {
        amountText(insights?.totalScannedAmount)
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
        topMerchantText
    }

    var highestReceiptText: String {
        guard let insights else {
            return AppFormat.money(0)
        }

        if let merchant = insights.highestReceiptMerchant, !merchant.isEmpty {
            return "\(amountText(insights.highestReceiptAmount)) • \(merchant)"
        }

        return amountText(insights.highestReceiptAmount)
    }

    // MARK: - Formatting

    func amountText(_ value: Double?) -> String {
        guard let value else {
            return AppFormat.money(0)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = AppFormat.currencyCode
        formatter.locale = AppFormat.locale
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSNumber(value: value)) ?? AppFormat.money(value)
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

    func formattedDate(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return ""
        }

        if let date = parseDate(value) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

            return formatter.string(from: date)
        }

        return value
    }

    private func parseDate(_ value: String) -> Date? {
        let isoFormatterWithFraction = ISO8601DateFormatter()
        isoFormatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatterWithFraction.date(from: value) {
            return date
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        if let date = isoFormatter.date(from: value) {
            return date
        }

        let localDateTimeFormatter = DateFormatter()
        localDateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        if let date = localDateTimeFormatter.date(from: value) {
            return date
        }

        let localDateFormatter = DateFormatter()
        localDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateFormatter.dateFormat = "yyyy-MM-dd"

        if let date = localDateFormatter.date(from: value) {
            return date
        }

        return nil
    }
}
