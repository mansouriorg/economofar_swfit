import Foundation

// MARK: - API responses of /api/warranties

struct Warranty: Codable, Identifiable {
    let ticketId: String
    let merchantName: String?
    let note: String?
    /// "2026-10-16"
    let purchaseDate: String?
    let endDate: String
    /// Negative once the warranty has ended.
    let daysLeft: Int
    /// "active", "expiring" (30 days or less) or "expired"
    let status: String

    var id: String { ticketId }

    var title: String {
        if let merchantName, !merchantName.isEmpty {
            return merchantName
        }

        return "Achat"
    }

    var endDateValue: Date? {
        WarrantyDates.parse(endDate)
    }

    var endDateText: String {
        guard let date = endDateValue else { return endDate }
        return WarrantyDates.display(date)
    }

    var purchaseDateText: String? {
        guard let purchaseDate, let date = WarrantyDates.parse(purchaseDate) else { return nil }
        return WarrantyDates.display(date)
    }

    var remainingText: String {
        if daysLeft < 0 {
            return "Expirée"
        }

        if daysLeft == 0 {
            return "Expire aujourd'hui"
        }

        if daysLeft == 1 {
            return "1 jour restant"
        }

        if daysLeft < 60 {
            return "\(daysLeft) jours restants"
        }

        let months = daysLeft / 30
        return "\(months) mois restants"
    }
}

struct WarrantyCandidate: Codable, Identifiable {
    let ticketId: String
    let merchantName: String?
    let purchaseDate: String
    let totalAmount: Double?
    let category: String?

    var id: String { ticketId }

    var title: String {
        if let merchantName, !merchantName.isEmpty {
            return merchantName
        }

        return "Achat"
    }

    var label: String {
        var text = title

        if let date = WarrantyDates.parse(purchaseDate) {
            text += " · " + WarrantyDates.display(date)
        }

        if let totalAmount {
            text += " · " + AppFormat.money(totalAmount)
        }

        return text
    }
}

struct SetWarrantyBody: Encodable {
    let months: Int
}

// MARK: - Dates

enum WarrantyDates {
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        parser.date(from: value)
    }

    static func display(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppFormat.locale
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    static func addMonths(_ months: Int, to date: Date) -> Date? {
        Calendar.current.date(byAdding: .month, value: months, to: date)
    }
}
