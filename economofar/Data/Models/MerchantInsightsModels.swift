import Foundation

// MARK: - API response of GET /api/analytics/merchants

struct MerchantSummary: Codable, Identifiable {
    let name: String
    let total: Double
    /// Percentage of all the spending of the period.
    let share: Double
    let tickets: Int
    let averageTicket: Double
    /// "2026-10-17"
    let lastVisit: String
    let daysSinceLastVisit: Int
    let topCategory: String?

    var id: String { name }

    var subtitle: String {
        "\(MerchantText.visits(tickets)) · panier moyen \(AppFormat.money(averageTicket))"
    }
}

struct MerchantList: Codable {
    let months: Int
    let from: String
    let to: String
    let total: Double
    let tickets: Int
    /// Number of different shops (the list only has the biggest ones).
    let merchantCount: Int
    let merchants: [MerchantSummary]

    var isEmpty: Bool {
        merchants.isEmpty
    }

    var isTruncated: Bool {
        merchantCount > merchants.count
    }
}

// MARK: - API response of GET /api/analytics/merchants/detail

struct MerchantPurchase: Codable {
    /// "2026-10-17"
    let date: String
    let amount: Double
    let category: String
}

struct MerchantMonth: Codable, Identifiable {
    /// "2026-10"
    let month: String
    let total: Double
    let tickets: Int

    var id: String { month }
}

struct MerchantCategory: Codable, Identifiable {
    let name: String
    let total: Double
    let share: Double

    var id: String { name }
}

struct MerchantItem: Codable, Identifiable {
    let name: String
    let quantity: Int
    let total: Double

    var id: String { name }
}

struct MerchantDetail: Codable {
    let name: String
    let periodMonths: Int
    let from: String
    let to: String
    let total: Double
    let share: Double
    let tickets: Int
    let averageTicket: Double
    let firstVisit: String
    let lastVisit: String
    let daysSinceLastVisit: Int
    /// Average number of days between two days with a receipt (nil with fewer than two such days).
    let averageDaysBetween: Double?
    /// 1 = Monday ... 7 = Sunday, only when one day clearly stands out.
    let usualWeekday: Int?
    /// Spent in this shop since the 1st of the current month.
    let monthToDate: Double
    /// Spent in this shop during the same days of the month before.
    let previousSamePeriod: Double
    let changePercent: Double?
    let biggest: MerchantPurchase
    let recent: [MerchantPurchase]
    let months: [MerchantMonth]
    let categories: [MerchantCategory]
    let items: [MerchantItem]

    var maxMonthTotal: Double {
        months.map { $0.total }.max() ?? 0
    }

    var periodText: String {
        "\(WeeklyDigestText.format(from, pattern: "MMM yyyy")) - \(WeeklyDigestText.format(to, pattern: "MMM yyyy"))"
    }

    var frequencyText: String? {
        guard let days = averageDaysBetween else { return nil }

        if days <= 1.05 {
            return "Presque tous les jours"
        }

        return "Tous les \(WeeklyDigestText.percent(days)) jours en moyenne"
    }

    var weekdayText: String? {
        guard let day = usualWeekday else { return nil }

        return MerchantText.weekday(day)
    }
}

// MARK: - Texts

enum MerchantText {
    static func visits(_ count: Int) -> String {
        count == 1 ? "1 passage" : "\(count) passages"
    }

    static func lastVisit(daysAgo: Int) -> String {
        if daysAgo <= 0 {
            return "aujourd'hui"
        }

        if daysAgo == 1 {
            return "hier"
        }

        return "il y a \(daysAgo) jours"
    }

    static func shortLastVisit(daysAgo: Int) -> String {
        if daysAgo <= 1 {
            return lastVisit(daysAgo: daysAgo)
        }

        return "il y a \(daysAgo) j"
    }

    static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }

        return String(first).uppercased() + text.dropFirst()
    }

    /// Name of the day of the week for 1 = Monday ... 7 = Sunday, in the language of the profile.
    static func weekday(_ isoDay: Int) -> String? {
        guard (1...7).contains(isoDay) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = AppFormat.locale

        let symbols = formatter.weekdaySymbols ?? []

        guard symbols.count == 7 else { return nil }

        return symbols[isoDay % 7]
    }

    /// First letter of the month, upper case ("O" for "2026-10").
    static func monthLetter(_ month: String) -> String {
        WeeklyDigestText.format(month + "-01", pattern: "MMMMM").uppercased()
    }

    static func monthName(_ month: String) -> String {
        WeeklyDigestText.format(month + "-01", pattern: "LLLL yyyy")
    }
}
