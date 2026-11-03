import Foundation

/// Tells where the person spends. The server reads the saved tickets: nothing is sent but the number of
/// months and, for the detail of a shop, its key.
final class ShopsService {
    static let shared = ShopsService()

    private init() {}

    /// months goes from 3 to 24, the server brings other values back into this range.
    func fetch(token: String, months: Int) async throws -> ShopsOverview {
        try await APIClient.shared.get(
            "/api/analytics/shops",
            query: [URLQueryItem(name: "months", value: String(months))],
            token: token,
            as: ShopsOverview.self
        )
    }

    /// key is the key that the list gives for the shop.
    func fetchDetail(token: String, key: String, months: Int) async throws -> ShopDetail {
        try await APIClient.shared.get(
            "/api/analytics/shops/detail",
            query: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "months", value: String(months))
            ],
            token: token,
            as: ShopDetail.self
        )
    }
}
