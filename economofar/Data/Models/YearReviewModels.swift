import Foundation

// MARK: - API response of GET /api/analytics/year

/// One month of the year.
struct YearReviewMonth: Codable, Identifiable {
    /// 1 for January, 12 for December.
    let month: Int
    let total: Double
    let tickets: Int

    var id: Int { month }
}

/// One category of the year.
struct YearReviewCategory: Codable {
    let name: String
    let total: Double
    /// Percentage of the year's spending.
    let share: Double
}

/// A shop where a lot was spent.
struct YearReviewMerchant: Codable {
    let name: String
    let total: Double
    let tickets: Int
}

/// The biggest ticket of the year.
struct YearReviewTicket: Codable {
    let id: UUID?
    let merchant: String
    let category: String
    /// "2026-10-17"
    let date: String
    let amount: Double
}

struct YearReview: Codable {
    let year: Int
    /// True for the year in progress: it is compared with the same period of the previous year.
    let partial: Bool
    /// Number of months of the year that have started (12 for a finished year).
    let monthsElapsed: Int
    let total: Double
    let tickets: Int
    /// Null without ticket.
    let averageTicket: Double?
    /// The previous year up to the same day (the whole previous year for a finished year).
    let previousTotal: Double
    /// The whole previous year.
    let previousFullTotal: Double
    let delta: Double
    /// Null when nothing was spent in the compared period of the previous year.
    let deltaPercent: Double?
    /// Months between the first month with a ticket and the last finished month.
    let trackedMonths: Int
    /// Null when no month is tracked.
    let monthlyAverage: Double?
    /// Null with less than 2 tracked months.
    let busiestMonth: Int?
    let quietestMonth: Int?
    /// Always 12 months, January first.
    let months: [YearReviewMonth]
    let categoryCount: Int
    let categories: [YearReviewCategory]
    let merchantCount: Int
    let merchants: [YearReviewMerchant]
    let biggestTicket: YearReviewTicket?

    /// The compared period of the previous year can be empty while the whole year is not.
    var hasTickets: Bool {
        tickets > 0 || previousFullTotal > 0
    }

    func month(_ number: Int) -> YearReviewMonth? {
        months.first { $0.month == number }
    }
}

// MARK: - Text helpers

enum YearReviewText {
    static let mergedName = "Autres catégories"

    private static let monthNames = [
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre"
    ]

    private static let monthInitials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    /// The years of the picker, the current year first: [2026, 2025, ...].
    static func yearKeys(count: Int, now: Date = Date()) -> [Int] {
        let year = Calendar(identifier: .gregorian).component(.year, from: now)

        return (0..<max(count, 1)).map { year - $0 }
    }

    /// "octobre"
    static func monthName(_ month: Int) -> String {
        guard month >= 1, month <= monthNames.count else {
            return ""
        }

        return monthNames[month - 1]
    }

    /// "O"
    static func monthInitial(_ month: Int) -> String {
        guard month >= 1, month <= monthInitials.count else {
            return ""
        }

        return monthInitials[month - 1]
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + String(text.dropFirst())
    }

    /// "1 ticket", "5 tickets"
    static func ticketCount(_ count: Int) -> String {
        count > 1 ? "\(count) tickets" : "\(count) ticket"
    }

    /// "+ 1 autre commerce", "+ 4 autres commerces"
    static func moreShops(_ count: Int) -> String {
        count == 1 ? "+ 1 autre commerce" : "+ \(count) autres commerces"
    }

    static func periodText(_ result: YearReview) -> String {
        result.partial
            ? "Bilan \(result.year) · depuis le 1er janvier"
            : "Bilan \(result.year) · année entière"
    }

    /// "contre 1 200,00 € à la même date en 2025", "contre 1 200,00 € en 2025".
    static func againstText(_ result: YearReview) -> String {
        let money = AppFormat.money(result.previousTotal)

        return result.partial
            ? "contre \(money) à la même date en \(result.year - 1)"
            : "contre \(money) en \(result.year - 1)"
    }

    /// A change below 2 % is called stable.
    static func isStable(_ result: YearReview) -> Bool {
        if let percent = result.deltaPercent {
            return abs(percent) < 2
        }

        return abs(result.delta) < 0.005
    }

    static func summary(_ result: YearReview) -> String {
        let last = result.year - 1

        if result.previousTotal <= 0 && result.total <= 0 {
            return "Aucune dépense sur ces deux périodes."
        }

        if result.previousTotal <= 0 {
            return result.partial
                ? "Rien n'avait encore été dépensé à la même date en \(last)."
                : "Rien n'avait été dépensé en \(last)."
        }

        if isStable(result) {
            return result.partial
                ? "Dépenses stables par rapport à la même date en \(last)."
                : "Dépenses stables par rapport à \(last)."
        }

        let amount = AppFormat.money(abs(result.delta))
        let direction = result.delta > 0 ? "de plus" : "de moins"

        return result.partial
            ? "Vous avez dépensé \(amount) \(direction) qu'à la même date en \(last)."
            : "Vous avez dépensé \(amount) \(direction) qu'en \(last)."
    }

    /// "+12,5 %", "-3 %"
    static func percentText(_ percent: Double) -> String {
        (percent > 0 ? "+" : "") + WeeklyDigestText.percent(percent) + " %"
    }

    static func shareText(_ share: Double) -> String {
        WeeklyDigestText.percent(share) + " %"
    }

    /// "Moyenne de 220,00 € par mois sur 9 mois"
    static func averageText(_ result: YearReview) -> String? {
        guard let average = result.monthlyAverage, result.trackedMonths > 0 else {
            return nil
        }

        let months = result.trackedMonths > 1 ? "\(result.trackedMonths) mois" : "1 mois"

        return "Moyenne de \(AppFormat.money(average)) par mois sur \(months)"
    }

    static func monthAccessibility(_ item: YearReviewMonth, in result: YearReview) -> String {
        let name = capitalized(monthName(item.month))

        if result.partial && item.month > result.monthsElapsed {
            return "\(name), pas encore commencé"
        }

        var label = "\(name), \(AppFormat.money(item.total)), \(ticketCount(item.tickets))"

        if result.partial && item.month == result.monthsElapsed {
            label += ", mois en cours"
        }

        if item.month == result.busiestMonth {
            label += ", mois le plus dépensier"
        } else if item.month == result.quietestMonth {
            label += ", mois le plus calme"
        }

        return label
    }
}
