import Foundation

// MARK: - API response of GET /api/analytics/recurring

struct RecurringExpensesResponse: Codable {
    let items: [RecurringExpense]
    let monthlyTotal: Double
}

struct RecurringExpense: Codable, Identifiable {
    let merchantName: String
    let category: String?
    let typicalAmount: Double
    let occurrences: Int
    /// "weekly", "biweekly", "monthly" or "quarterly"
    let frequency: String
    let intervalDays: Int
    /// "2026-10-16"
    let lastDate: String
    let nextExpectedDate: String
    /// Negative when the next one is late.
    let daysUntilNext: Int
    let monthlyEstimate: Double

    var id: String { merchantName + frequency }

    var frequencyLabel: String {
        switch frequency {
        case "weekly":
            return "Chaque semaine"
        case "biweekly":
            return "Toutes les 2 semaines"
        case "monthly":
            return "Chaque mois"
        case "quarterly":
            return "Chaque trimestre"
        default:
            return "Régulier"
        }
    }

    var subtitle: String {
        if let category, !category.isEmpty {
            return frequencyLabel + " · " + category
        }

        return frequencyLabel
    }

    var nextDateText: String {
        guard let date = Self.parser.date(from: nextExpectedDate) else {
            return nextExpectedDate
        }

        let formatter = DateFormatter()
        formatter.locale = AppFormat.locale
        formatter.dateFormat = "d MMM"

        return formatter.string(from: date)
    }

    var nextText: String {
        if daysUntilNext < 0 {
            let late = abs(daysUntilNext)
            return "Attendu depuis \(late) jour\(late > 1 ? "s" : "")"
        }

        if daysUntilNext == 0 {
            return "Prévu aujourd'hui"
        }

        if daysUntilNext == 1 {
            return "Prochain : demain (\(nextDateText))"
        }

        return "Prochain : dans \(daysUntilNext) jours (\(nextDateText))"
    }

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
