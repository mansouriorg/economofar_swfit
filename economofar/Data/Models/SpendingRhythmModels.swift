import Foundation

// MARK: - API response of GET /api/analytics/rhythm

/// One day of the week over the period: 1 is Monday, 7 is Sunday.
struct WeekdayRhythm: Codable, Identifiable {
    let dayOfWeek: Int
    let total: Double
    /// total divided by days: what is spent on average on this day of the week.
    let average: Double
    /// Percentage of all the spending of the period.
    let share: Double
    let purchaseCount: Int
    /// How many of these days have at least one purchase.
    let activeDays: Int
    /// How many of these days the period contains.
    let days: Int

    var id: Int { dayOfWeek }
}

/// One part of the month: "start" (days 1 to 10), "middle" (11 to 20) or "end" (21 to the last day).
struct MonthPartRhythm: Codable, Identifiable {
    let key: String
    let days: Int
    let total: Double
    let dailyAverage: Double
    let share: Double

    var id: String { key }
}

struct SpendingRhythm: Codable {
    let weeks: Int
    let from: String
    let to: String
    /// The first purchase of the period; the figures only use the days since then.
    let trackedFrom: String?
    let trackedDays: Int
    /// False under 14 tracked days: the days of the week cannot be compared yet.
    let enoughHistory: Bool
    let total: Double
    let purchaseCount: Int
    let activeDays: Int
    let noPurchaseDays: Int
    let dailyAverage: Double
    /// Always 7 entries, Monday first.
    let weekdays: [WeekdayRhythm]
    let busiestDay: Int?
    let quietestDay: Int?
    /// Daily average of the busiest day of the week divided by the daily average of the period.
    let peakRatio: Double
    let weekendTotal: Double
    let weekendShare: Double
    let weekendDailyAverage: Double
    let weekdayDailyAverage: Double
    /// Always 3 entries: start, middle, end.
    let monthParts: [MonthPartRhythm]
    let biggestDayDate: String?
    let biggestDayAmount: Double?
    let currentStreak: Int
    let longestStreak: Int

    var hasData: Bool {
        purchaseCount > 0
    }

    /// True when the figures start after the beginning of the period asked for.
    var startsLater: Bool {
        guard let trackedFrom else { return false }

        return trackedFrom > from
    }

    var periodText: String {
        let start = trackedFrom ?? from

        return "\(WeeklyDigestText.format(start, pattern: "d MMM")) - \(WeeklyDigestText.format(to, pattern: "d MMM yyyy"))"
    }

    var maxWeekdayAverage: Double {
        weekdays.map { $0.average }.max() ?? 0
    }

    var maxPartAverage: Double {
        monthParts.map { $0.dailyAverage }.max() ?? 0
    }
}

// MARK: - Text helpers

enum RhythmText {
    /// The peak ratio from which a day of the week is called the strong day.
    static let pronouncedPeak = 1.25

    private static let weekdayNames = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

    static func weekday(_ dayOfWeek: Int) -> String {
        guard dayOfWeek >= 1, dayOfWeek <= weekdayNames.count else { return "" }

        return weekdayNames[dayOfWeek - 1]
    }

    static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }

        return String(first).uppercased() + text.dropFirst()
    }

    static func periodTitle(_ weeks: Int) -> String {
        "\(weeks) sem."
    }

    /// "0 jour", "1 jour", "5 jours".
    static func dayCount(_ count: Int) -> String {
        count > 1 ? "\(count) jours" : "\(count) jour"
    }

    static func partTitle(_ key: String) -> String {
        switch key {
        case "start":
            return "Début du mois"
        case "middle":
            return "Milieu du mois"
        default:
            return "Fin du mois"
        }
    }

    static func partRange(_ key: String) -> String {
        switch key {
        case "start":
            return "du 1er au 10"
        case "middle":
            return "du 11 au 20"
        default:
            return "du 21 à la fin du mois"
        }
    }

    static func visits(_ weekday: WeekdayRhythm) -> String {
        "\(dayCount(weekday.activeDays)) avec achat sur \(weekday.days)"
    }
}
