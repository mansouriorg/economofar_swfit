import Foundation

/// Asks the backend how the user usually files the receipts of a shop.
/// Any failure returns nil: the suggestion is a bonus and must never block the scan.
final class MerchantSuggestionService {
    static let shared = MerchantSuggestionService()

    private init() {}

    func fetch(merchant: String, token: String) async -> MerchantSuggestion? {
        do {
            let suggestion = try await APIClient.shared.get(
                "/api/v1/merchants/suggestion",
                query: [URLQueryItem(name: "name", value: merchant)],
                token: token,
                as: MerchantSuggestion.self
            )

            return suggestion.ticketCount > 0 ? suggestion : nil
        } catch {
            return nil
        }
    }
}
