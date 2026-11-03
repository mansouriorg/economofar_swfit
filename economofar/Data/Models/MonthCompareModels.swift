import Foundation

// MARK: - API response of GET /api/analytics/compare

/// One category of the comparison.
struct MonthCompareCategory: Codable {
    let name: String
    /// Spent in the compared days of the chosen month.
    let current: Double
    /// Spent in the compared days of the previous month.
    let previous: Double
    let delta: Double
    /// Null when nothing was spent in this category in the previous month.
    let deltaPercent: Double?
    /// Percentage of the chosen month's spending.
    let share: Double
}

/// One day of the two cumulative curves.
struct MonthComparePoint: Codable, Identifiable {
    let day: Int
    /// Null after the last compared day of the chosen month.
    let current: Double?
    /// Null after the last day of the previous month.
    let previous: Double?

    var id: Int { day }
}

struct MonthCompare: Codable {
    /// "2026-10"
    let month: String
    let previousMonth: String
    /// True for the month in progress: its first days are compared with the same days of the previous month.
    let partial: Bool
    let days: Int
    let previousDays: Int
    let currentTotal: Double
    let previousTotal: Double
    /// The whole previous month.
    let previousFullTotal: Double
    let delta: Double
    /// Null when nothing was spent in the previous month.
    let deltaPercent: Double?
    let currentTickets: Int
    let previousTickets: Int
    /// Null without ticket.
    let currentAverage: Double?
    let previousAverage: Double?
    let categoryCount: Int
    let categories: [MonthCompareCategory]
    let points: [MonthComparePoint]

    /// The compared days of the previous month can be empty while the whole month is not.
    var hasTickets: Bool {
        currentTickets > 0 || previousTickets > 0 || previousFullTotal > 0
    }
}

// MARK: - Text helpers

enum MonthCompareText {
    static let mergedName = "Autres catégories"

    /// The month keys of the picker, the current month first: ["2026-10", "2026-09", ...].
    static func monthKeys(count: Int, now: Date = Date()) -> [String] {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: now)
        let base = (parts.year ?? 2026) * 12 + ((parts.month ?? 1) - 1)

        return (0..<max(count, 1)).map { offset in
            let total = base - offset
            let month = total % 12 + 1

            return "\(total / 12)-" + (month < 10 ? "0\(month)" : "\(month)")
        }
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + String(text.dropFirst())
    }

    /// "de mars", "d'avril", "d'août", "d'octobre"
    static func ofMonth(_ name: String) -> String {
        let vowels = ["a", "e", "i", "o", "u", "h", "é", "è"]

        return vowels.contains(name.prefix(1).lowercased()) ? "d'\(name)" : "de \(name)"
    }

    /// "Octobre 2026"
    static func monthTitle(_ key: String) -> String {
        capitalized(WeeklyDigestText.format(key + "-01", pattern: "LLLL yyyy"))
    }

    /// "octobre"
    static func monthName(_ key: String) -> String {
        WeeklyDigestText.format(key + "-01", pattern: "LLLL")
    }

    private static func days(_ count: Int, _ name: String) -> String {
        count <= 1 ? "le 1er \(name)" : "du 1er au \(count) \(name)"
    }

    /// "Du 1er au 17 octobre" for the month in progress, "Septembre 2026" for a finished month.
    static func periodText(_ result: MonthCompare) -> String {
        guard result.partial else {
            return monthTitle(result.month)
        }

        return capitalized(days(result.days, monthName(result.month)))
    }

    /// "contre 120,00 € du 1er au 17 septembre", "contre 120,00 € en septembre".
    static func againstText(_ result: MonthCompare) -> String {
        let name = monthName(result.previousMonth)

        if result.partial {
            return "contre \(AppFormat.money(result.previousTotal)) \(days(result.previousDays, name))"
        }

        return "contre \(AppFormat.money(result.previousTotal)) en \(name)"
    }

    /// A change below 2 % is called stable.
    static func isStable(_ result: MonthCompare) -> Bool {
        if let percent = result.deltaPercent {
            return abs(percent) < 2
        }

        return abs(result.delta) < 0.005
    }

    static func summary(_ result: MonthCompare) -> String {
        let name = monthName(result.previousMonth)

        if result.previousTotal <= 0 && result.currentTotal <= 0 {
            return "Aucune dépense sur ces deux périodes."
        }

        if result.previousTotal <= 0 {
            return result.partial
                ? "Rien n'avait encore été dépensé à la même date en \(name)."
                : "Rien n'avait été dépensé en \(name)."
        }

        if isStable(result) {
            return result.partial
                ? "Dépenses stables par rapport à la même date en \(name)."
                : "Dépenses stables par rapport à \(name)."
        }

        let amount = AppFormat.money(abs(result.delta))
        let direction = result.delta > 0 ? "de plus" : "de moins"

        return result.partial
            ? "Vous avez dépensé \(amount) \(direction) qu'à la même date en \(name)."
            : "Vous avez dépensé \(amount) \(direction) qu'en \(name)."
    }

    /// "+12,5 %", "-3 %"
    static func percentText(_ percent: Double) -> String {
        (percent > 0 ? "+" : "") + WeeklyDigestText.percent(percent) + " %"
    }

    static func categoryPercent(_ category: MonthCompareCategory) -> String {
        if let percent = category.deltaPercent {
            return percentText(percent)
        }

        if category.current > 0 {
            return category.name == mergedName ? "Nouvelles" : "Nouvelle"
        }

        return "-"
    }
}
