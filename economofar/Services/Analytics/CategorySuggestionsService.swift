import Foundation

/// Loads the category suggestions, and gives a ticket the category that is suggested for it.
final class CategorySuggestionsService {
    static let shared = CategorySuggestionsService()

    private init() {}

    /// months is the length of the period (3, 12 or 24); the server also looks at the last 24 months to learn from.
    func fetch(token: String, months: Int) async throws -> CategorySuggestions {
        return try await APIClient.shared.get(
            "/api/analytics/category-suggestions",
            query: [
                URLQueryItem(name: "months", value: String(months))
            ],
            token: token,
            as: CategorySuggestions.self
        )
    }

    /// The call the ticket screen uses to change a category.
    func apply(ticketId: String, category: String, token: String) async throws {
        _ = try await TicketEditableService.shared.changeCategory(
            ticketId: ticketId,
            category: category,
            token: token
        )
    }

    /// True when the server says that the session is over.
    static func isSessionExpired(_ error: Error) -> Bool {
        if case APIError.unauthorized = error {
            return true
        }

        if case TicketEditableServiceError.backendError(let statusCode, _) = error {
            // The server answers 403 when the token is not accepted, and 404 for a ticket that is not the user's
            return statusCode == 401 || statusCode == 403
        }

        return false
    }

    /// The server answered with a success but its answer could not be read: the category is changed.
    static func isAppliedDespiteError(_ error: Error) -> Bool {
        if case TicketEditableServiceError.decodingFailed = error {
            return true
        }

        return false
    }
}
