import Foundation

/// Tells which articles are bought at a regular rhythm. The server reads the saved tickets: nothing is sent
/// but the number of months and, for the detail of an article, its key.
final class RepurchaseService {
    static let shared = RepurchaseService()

    private init() {}

    /// months goes from 3 to 24, the server brings other values back into this range.
    func fetch(token: String, months: Int) async throws -> RepurchaseOverview {
        try await APIClient.shared.get(
            "/api/analytics/repurchase",
            query: [URLQueryItem(name: "months", value: String(months))],
            token: token,
            as: RepurchaseOverview.self
        )
    }

    /// key is the key that the list gives for the article.
    func fetchDetail(token: String, key: String, months: Int) async throws -> RepurchaseDetail {
        try await APIClient.shared.get(
            "/api/analytics/repurchase/detail",
            query: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "months", value: String(months))
            ],
            token: token,
            as: RepurchaseDetail.self
        )
    }
}
