import Foundation

/// Loads the spending of a period for each payment method.
final class PaymentUsageService {
    static let shared = PaymentUsageService()

    private init() {}

    /// months is 3, 12 or 24: the number of calendar months, the current one included.
    func fetch(token: String, months: Int) async throws -> PaymentUsage {
        return try await APIClient.shared.get(
            "/api/analytics/payment-methods",
            query: [
                URLQueryItem(name: "months", value: String(months))
            ],
            token: token,
            as: PaymentUsage.self
        )
    }
}
