import Foundation

/// API paths used by the newer screens (analytics, account, profile).
/// The older services keep their own paths.
enum Endpoint {
    static let profile = "/api/profile"
    static let analyticsSummary = "/api/analytics/summary"
    static let deleteAccount = "/api/account/delete"

    static func receipt(_ id: String) -> String {
        "/api/v1/receipts/\(id)"
    }
}
