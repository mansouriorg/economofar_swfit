import Foundation

/// Splits the spending of a month into needs, wants and savings. The server reads the incomes and the
/// saved tickets and keeps the choices of the person (which group a category belongs to).
final class SpendingSplitService {
    static let shared = SpendingSplitService()

    private let path = "/api/analytics/spending-split"

    private init() {}

    /// month is "2026-10", or nil for the current month.
    func fetch(token: String, month: String?) async throws -> SpendingSplitOverview {
        var query: [URLQueryItem] = []

        if let month {
            query.append(URLQueryItem(name: "month", value: month))
        }

        return try await APIClient.shared.get(
            path,
            query: query,
            token: token,
            as: SpendingSplitOverview.self
        )
    }

    /// Puts a category in a group: "NEED", "WANT" or "EXCLUDED", or "DEFAULT" to go back to the proposed one.
    func setGroup(token: String, category: String, group: String) async throws {
        let body = SpendingSplitRuleBody(category: category, group: group)

        _ = try await APIClient.shared.post(path + "/rules", body: body, token: token)
    }
}
