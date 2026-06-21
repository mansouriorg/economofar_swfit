import Foundation

struct DashboardInsightsResponse: Codable {
    let totalScannedAmount: Double
    let ticketCount: Int
    let averageBasket: Double

    let totalSpentThisWeek: Double
    let totalSpentThisMonth: Double
    let totalSpentLastMonth: Double
    let monthlyComparisonPercentage: Double?

    let highestReceiptAmount: Double
    let highestReceiptMerchant: String?

    let averageTicketAmount: Double
    let mostFrequentMerchant: String?

    let recentTickets: [DashboardRecentTicketResponse]
}

struct DashboardRecentTicketResponse: Codable, Identifiable {
    let id: String
    let merchantName: String?
    let totalAmount: Double?
    let purchaseDate: String?
    let category: String?
    let imageUrl: String?
}
