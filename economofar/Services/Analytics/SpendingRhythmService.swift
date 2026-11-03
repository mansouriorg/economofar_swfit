import Foundation

/// Loads when the user spends: the days of the week, the parts of the month and the streaks.
final class SpendingRhythmService {
    static let shared = SpendingRhythmService()

    private init() {}

    func fetch(token: String, weeks: Int) async throws -> SpendingRhythm {
        try await APIClient.shared.get(
            "/api/analytics/rhythm",
            query: [URLQueryItem(name: "weeks", value: String(weeks))],
            token: token,
            as: SpendingRhythm.self
        )
    }
}
