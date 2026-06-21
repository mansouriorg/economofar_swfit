import Foundation

// MARK: - History Receipt Response

struct TicketHistoryReceipt: Codable, Identifiable, Hashable {
    let id: UUID
    let merchantName: String?
    let totalAmount: Double?
    let purchaseDate: String?
    let category: String?
    let paymentMethod: String?
    let scanStatus: TicketScanStatus?
    let imageUrl: String?

    var displayMerchant: String {
        guard let merchantName, !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Magasin inconnu"
        }

        return merchantName
    }

    var displayAmount: String {
        String(format: "%.2f €", totalAmount ?? 0.0)
    }

    var displayCategory: String {
        guard let category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Autre"
        }

        return category
    }

    var displayPaymentMethod: String {
        guard let paymentMethod, !paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Non précisé"
        }

        return paymentMethod
    }

    var displayDate: String {
        TicketHistoryDateHelper.shortDate(from: purchaseDate)
    }

    var displayMonth: String {
        TicketHistoryDateHelper.monthTitle(from: purchaseDate)
    }
}

// MARK: - History Group Response

struct TicketHistoryGroup: Codable, Identifiable, Hashable {
    let groupKey: String?
    let groupTitle: String?
    let ticketCount: Int?
    let totalAmount: Double?
    let tickets: [TicketHistoryReceipt]?

    var id: String {
        groupKey ?? UUID().uuidString
    }

    var displayTitle: String {
        guard let groupTitle, !groupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Groupe"
        }

        return groupTitle
    }

    var displayCount: String {
        let count = ticketCount ?? tickets?.count ?? 0
        return "\(count) ticket\(count > 1 ? "s" : "")"
    }

    var displayTotal: String {
        String(format: "%.2f €", totalAmount ?? 0.0)
    }

    var safeTickets: [TicketHistoryReceipt] {
        tickets ?? []
    }
}

// MARK: - Filter Model

struct TicketHistoryFilter: Equatable {
    var fromDate: String = ""
    var toDate: String = ""
    var merchant: String = ""
    var minAmount: String = ""
    var maxAmount: String = ""
    var category: String = "Tous"
    var paymentMethod: String = "Tous"
    var month: String = ""
    var scanStatus: String = "Tous"
    var sortBy: TicketHistorySortOption = .newestFirst
    var groupBy: TicketHistoryGroupOption = .month

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []

        addQueryItem(&items, name: "fromDate", value: fromDate)
        addQueryItem(&items, name: "toDate", value: toDate)
        addQueryItem(&items, name: "merchant", value: merchant)
        addQueryItem(&items, name: "minAmount", value: minAmount)
        addQueryItem(&items, name: "maxAmount", value: maxAmount)
        addQueryItem(&items, name: "month", value: month)

        if category != "Tous" {
            addQueryItem(&items, name: "category", value: category)
        }

        if paymentMethod != "Tous" {
            addQueryItem(&items, name: "paymentMethod", value: paymentMethod)
        }

        if scanStatus != "Tous" {
            addQueryItem(&items, name: "scanStatus", value: scanStatus)
        }

        items.append(URLQueryItem(name: "sortBy", value: sortBy.rawValue))

        return items
    }

    var groupedQueryItems: [URLQueryItem] {
        var items = queryItems
        items.append(URLQueryItem(name: "groupBy", value: groupBy.rawValue))
        return items
    }

    var hasActiveFilters: Bool {
        !fromDate.isEmpty ||
        !toDate.isEmpty ||
        !merchant.isEmpty ||
        !minAmount.isEmpty ||
        !maxAmount.isEmpty ||
        category != "Tous" ||
        paymentMethod != "Tous" ||
        !month.isEmpty ||
        scanStatus != "Tous" ||
        sortBy != .newestFirst
    }

    private func addQueryItem(_ items: inout [URLQueryItem], name: String, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: name, value: trimmed))
        }
    }
}

// MARK: - Sort Options

enum TicketHistorySortOption: String, CaseIterable, Identifiable {
    case newestFirst = "NEWEST_FIRST"
    case oldestFirst = "OLDEST_FIRST"
    case highestAmount = "HIGHEST_AMOUNT"
    case lowestAmount = "LOWEST_AMOUNT"
    case merchantName = "MERCHANT_NAME"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .newestFirst:
            return "Plus récents"
        case .oldestFirst:
            return "Plus anciens"
        case .highestAmount:
            return "Montant élevé"
        case .lowestAmount:
            return "Montant faible"
        case .merchantName:
            return "Nom marchand"
        }
    }

    var icon: String {
        switch self {
        case .newestFirst:
            return "arrow.down.circle"
        case .oldestFirst:
            return "arrow.up.circle"
        case .highestAmount:
            return "arrow.up.right"
        case .lowestAmount:
            return "arrow.down.right"
        case .merchantName:
            return "textformat"
        }
    }
}

// MARK: - Group Options

enum TicketHistoryGroupOption: String, CaseIterable, Identifiable {
    case month = "MONTH"
    case merchant = "MERCHANT"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .month:
            return "Par mois"
        case .merchant:
            return "Par marchand"
        }
    }

    var icon: String {
        switch self {
        case .month:
            return "calendar"
        case .merchant:
            return "storefront"
        }
    }
}

// MARK: - View Mode

enum TicketHistoryViewMode: String, CaseIterable, Identifiable {
    case list
    case grouped

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .list:
            return "Liste"
        case .grouped:
            return "Groupé"
        }
    }
}

// MARK: - Payment Methods

enum TicketPaymentMethodOptions {
    static let all: [String] = [
        "Tous",
        "Carte",
        "Espèces",
        "Chèque",
        "Virement",
        "Apple Pay",
        "Google Pay",
        "Autre"
    ]
}

// MARK: - Scan Status Options

enum TicketScanStatusOptions {
    static let all: [String] = [
        "Tous",
        "UPLOADING",
        "ANALYZING",
        "OCR_COMPLETED",
        "NEEDS_REVIEW",
        "SAVED",
        "FAILED"
    ]

    static func displayTitle(_ value: String) -> String {
        switch value {
        case "Tous":
            return "Tous"
        case "UPLOADING":
            return "Envoi"
        case "ANALYZING":
            return "Analyse"
        case "OCR_COMPLETED":
            return "OCR terminé"
        case "NEEDS_REVIEW":
            return "À valider"
        case "SAVED":
            return "Sauvegardé"
        case "FAILED":
            return "Échec"
        default:
            return value
        }
    }
}

// MARK: - Date Helper

enum TicketHistoryDateHelper {

    static func shortDate(from dateString: String?) -> String {
        guard let date = parseDate(dateString) else {
            return dateString ?? "Date inconnue"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short

        return formatter.string(from: date)
    }

    static func mediumDate(from dateString: String?) -> String {
        guard let date = parseDate(dateString) else {
            return dateString ?? "Date inconnue"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium

        return formatter.string(from: date)
    }

    static func monthTitle(from dateString: String?) -> String {
        guard let date = parseDate(dateString) else {
            return "Date inconnue"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"

        let value = formatter.string(from: date)

        guard let first = value.first else {
            return value
        }

        return first.uppercased() + value.dropFirst()
    }

    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString, !dateString.isEmpty else {
            return nil
        }

        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatterWithFraction.date(from: dateString) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        if let date = standardFormatter.date(from: dateString) {
            return date
        }

        let localDateTimeFormatter = DateFormatter()
        localDateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        if let date = localDateTimeFormatter.date(from: dateString) {
            return date
        }

        let localDateFormatter = DateFormatter()
        localDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateFormatter.dateFormat = "yyyy-MM-dd"

        if let date = localDateFormatter.date(from: dateString) {
            return date
        }

        return nil
    }
}
