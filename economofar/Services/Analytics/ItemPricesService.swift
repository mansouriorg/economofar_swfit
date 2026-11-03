import Foundation

/// Follows the price of the articles that are on the saved tickets. The server reads the tickets: nothing
/// is sent but the number of months and, for the detail, the key of the article.
final class ItemPricesService {
    static let shared = ItemPricesService()

    private init() {}

    /// months goes from 3 to 24, the server brings other values back into this range.
    func fetch(token: String, months: Int) async throws -> ItemPricesOverview {
        try await APIClient.shared.get(
            "/api/analytics/item-prices",
            query: [URLQueryItem(name: "months", value: String(months))],
            token: token,
            as: ItemPricesOverview.self
        )
    }

    /// key is the key that the list gives for the article.
    func fetchDetail(token: String, key: String, months: Int) async throws -> ItemPriceDetail {
        try await APIClient.shared.get(
            "/api/analytics/item-prices/detail",
            query: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "months", value: String(months))
            ],
            token: token,
            as: ItemPriceDetail.self
        )
    }
}
