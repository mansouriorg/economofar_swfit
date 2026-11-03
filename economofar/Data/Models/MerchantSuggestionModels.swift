import Foundation

// MARK: - API response of GET /api/v1/merchants/suggestion

struct MerchantSuggestion: Codable {
    let merchantName: String?
    let category: String?
    let paymentMethod: String?
    let ticketCount: Int
}
