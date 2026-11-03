import Foundation

// MARK: - Server configuration

/// Single place that knows where the API server is.
///
/// - Simulator: the default http://localhost:8080 works.
/// - Real iPhone: open Settings > Assistance > "Adresse du serveur" and enter
///   the IP address of your Mac, for example http://192.168.1.20:8080
enum AppConfig {
    static let defaultBaseURL = "http://localhost:8080"

    /// Server root without trailing slash, e.g. "http://192.168.1.20:8080".
    static var baseURL: String {
        let saved = UserDefaults.standard
            .string(forKey: AppStorageKeys.serverURLOverride)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let value = saved.isEmpty ? defaultBaseURL : saved

        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }

    /// True when the app currently uses the default (localhost) server.
    static var isUsingDefaultServer: Bool {
        let saved = UserDefaults.standard
            .string(forKey: AppStorageKeys.serverURLOverride)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return saved.isEmpty
    }

    /// Saves a custom server address. Pass nil or an empty string to go back to the default.
    static func setBaseURL(_ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.serverURLOverride)
        } else {
            UserDefaults.standard.set(trimmed, forKey: AppStorageKeys.serverURLOverride)
        }
    }

    /// Returns a clean "scheme://host[:port]" string, or nil if the input is not a valid http(s) address.
    static func normalizedServerURL(from input: String) -> String? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { return nil }

        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "http://" + value
        }

        while value.hasSuffix("/") {
            value.removeLast()
        }

        guard
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty
        else {
            return nil
        }

        var result = "\(scheme)://\(host)"

        if let port = components.port {
            result += ":\(port)"
        }

        return result
    }

    /// Builds a full URL for an image path returned by the API ("/uploads/abc.jpg").
    static func absoluteURL(forServerPath path: String?) -> URL? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              path != "placeholder.jpg" else {
            return nil
        }

        if let url = URL(string: path), let scheme = url.scheme, scheme == "http" || scheme == "https" {
            return url
        }

        if path.hasPrefix("/") {
            return URL(string: baseURL + path)
        }

        return URL(string: baseURL + "/" + path)
    }
}

// MARK: - UserDefaults keys

enum AppStorageKeys {
    static let serverURLOverride = "api_base_url_override"
    static let faceIDLock = "faceid_lock_enabled"
    static let preferredCurrency = "preferred_currency"
    static let preferredLanguage = "preferred_language"
}

// MARK: - Formatting helpers

enum AppFormat {
    /// Currency chosen in the user profile (EUR by default).
    static var currencyCode: String {
        UserDefaults.standard.string(forKey: AppStorageKeys.preferredCurrency) ?? "EUR"
    }

    /// Number format of the user (French by default, US style when the profile language is English).
    static var locale: Locale {
        let language = UserDefaults.standard.string(forKey: AppStorageKeys.preferredLanguage) ?? "fr"
        return Locale(identifier: language == "en" ? "en_US" : "fr_FR")
    }

    /// Formats an amount with the currency chosen in the profile (EUR, USD, GBP, TND...).
    static func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f %@", value, currencyCode)
    }

    /// SF Symbol that matches the current currency.
    static var currencyIcon: String {
        switch currencyCode {
        case "EUR":
            return "eurosign.circle"
        case "USD", "CAD":
            return "dollarsign.circle"
        case "GBP":
            return "sterlingsign.circle"
        default:
            return "banknote"
        }
    }

    static var currencyIconFilled: String {
        currencyIcon + ".fill"
    }
}

// MARK: - Payment methods

enum EconomofarPaymentMethods {
    static let all: [String] = [
        "Carte",
        "Espèces",
        "Chèque",
        "Virement",
        "Apple Pay",
        "Autre"
    ]
}
