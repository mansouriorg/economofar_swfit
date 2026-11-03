import Foundation

/// Loads the review of a year: the 12 months, the categories, the shops where the most was spent,
/// the biggest ticket and the comparison with the previous year.
final class YearReviewService {
    static let shared = YearReviewService()

    private init() {}

    /// year is for example 2026; nil asks for the year in progress.
    func fetch(token: String, year: Int?) async throws -> YearReview {
        var query: [URLQueryItem] = []

        if let year {
            query.append(URLQueryItem(name: "year", value: String(year)))
        }

        return try await APIClient.shared.get(
            "/api/analytics/year",
            query: query,
            token: token,
            as: YearReview.self
        )
    }
}
