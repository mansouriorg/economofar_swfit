import Foundation

// MARK: - API response of GET /api/analytics/summary

struct AnalyticsSummary: Codable {
    let months: Int
    let rangeStart: String?
    let rangeEnd: String?
    let totalSpent: Double
    let ticketCount: Int
    let averageTicket: Double
    let categories: [AnalyticsCategory]
    let monthly: [AnalyticsMonth]
    let topMerchants: [AnalyticsNamedTotal]
    let paymentMethods: [AnalyticsNamedTotal]
}

struct AnalyticsCategory: Codable, Identifiable {
    let name: String
    let total: Double
    let count: Int
    let percentage: Double

    var id: String { name }
}

struct AnalyticsMonth: Codable, Identifiable {
    /// "2026-10"
    let month: String
    let total: Double
    let count: Int

    var id: String { month }

    /// Short month name for the chart axis ("oct.")
    var shortLabel: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"

        guard let date = parser.date(from: month) else { return month }

        let display = DateFormatter()
        display.locale = Locale.current
        display.dateFormat = "MMM"

        return display.string(from: date)
    }
}

struct AnalyticsNamedTotal: Codable, Identifiable {
    let name: String
    let total: Double
    let count: Int

    var id: String { name }
}
