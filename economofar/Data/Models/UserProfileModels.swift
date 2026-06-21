import Foundation

struct UserProfileResponse: Codable, Identifiable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String?
    let role: String?
    let companyName: String?
    let preferredCurrency: String?
    let language: String?
    let requiresReLogin: Bool
}

struct UpdateUserProfileRequest: Codable {
    let firstName: String?
    let lastName: String?
    let email: String?
    let companyName: String?
    let preferredCurrency: String?
    let language: String?
}

struct UpdatePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
    let confirmPassword: String
}

struct PasswordUpdateResponse: Codable {
    let message: String
    let requiresReLogin: Bool
}

enum PreferredLanguage: String, CaseIterable, Identifiable {
    case fr
    case en
    case ar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fr:
            return "Français"
        case .en:
            return "English"
        case .ar:
            return "العربية"
        }
    }
}

enum PreferredCurrency: String, CaseIterable, Identifiable {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case tnd = "TND"
    case cad = "CAD"
    case aed = "AED"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eur:
            return "EUR — Euro"
        case .usd:
            return "USD — Dollar américain"
        case .gbp:
            return "GBP — Livre sterling"
        case .tnd:
            return "TND — Dinar tunisien"
        case .cad:
            return "CAD — Dollar canadien"
        case .aed:
            return "AED — Dirham UAE"
        }
    }
}
