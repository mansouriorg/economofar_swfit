import Foundation

/// Loads the ranking of the shops and the detail of one shop.
final class MerchantInsightsService {
    static let shared = MerchantInsightsService()

    private init() {}

    func list(token: String, months: Int) async throws -> MerchantList {
        try await APIClient.shared.get(
            "/api/analytics/merchants",
            query: [URLQueryItem(name: "months", value: String(months))],
            token: token,
            as: MerchantList.self
        )
    }

    func detail(token: String, name: String, months: Int) async throws -> MerchantDetail {
        try await APIClient.shared.get(
            "/api/analytics/merchants/detail",
            query: [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "months", value: String(months))
            ],
            token: token,
            as: MerchantDetail.self
        )
    }
}
