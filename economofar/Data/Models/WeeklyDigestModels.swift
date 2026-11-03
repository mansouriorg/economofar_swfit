import Foundation

// MARK: - API response of GET /api/analytics/weekly-digest

struct DigestDay: Codable, Identifiable {
    /// "2026-10-17"
    let date: String
    let amount: Double
    let ticketCount: Int

    var id: String { date }
}

struct DigestCategory: Codable, Identifiable {
    let name: String
    let amount: Double
    /// Percentage of the total of the last 7 days.
    let share: Double
    let previousAmount: Double
    /// amount - previousAmount, negative when the category went down.
    let change: Double

    var id: String { name }
}

struct DigestMerchant: Codable {
    let name: String
    let amount: Double
    let visits: Int
}

struct DigestPurchase: Codable {
    let merchant: String
    let amount: Double
    let date: String
}

struct WeeklyDigest: Codable {
    let from: String
    let to: String
    let total: Double
    let previousTotal: Double
    let ticketCount: Int
    let previousTicketCount: Int
    let averagePerDay: Double
    /// Null when nothing was spent in the 7 days before.
    let changePercent: Double?
    /// "up", "down", "stable", "new" or "empty"
    let trend: String
    let noSpendDays: Int
    /// Exactly 7 days, the oldest first.
    let days: [DigestDay]
    let categories: [DigestCategory]
    let topMerchant: DigestMerchant?
    let biggestPurchase: DigestPurchase?
    let biggestChange: DigestCategory?

    var hasData: Bool {
        trend != "empty"
    }

    var hasComparison: Bool {
        previousTotal > 0
    }

    var periodText: String {
        "Du \(WeeklyDigestText.format(from, pattern: "d MMM")) au \(WeeklyDigestText.format(to, pattern: "d MMM"))"
    }

    var trendTitle: String {
        let percent = WeeklyDigestText.percent(abs(changePercent ?? 0))

        switch trend {
        case "up":
            return "Dépenses en hausse de \(percent) %"
        case "down":
            return "Dépenses en baisse de \(percent) %"
        case "stable":
            return "Dépenses stables"
        case "new":
            return "Rien la semaine précédente pour comparer"
        default:
            return "Aucun achat enregistré"
        }
    }

    var trendSubtitle: String? {
        guard hasComparison else { return nil }

        return "Semaine précédente : \(AppFormat.money(previousTotal))"
    }

    var trendIcon: String {
        switch trend {
        case "up":
            return "arrow.up.right"
        case "down":
            return "arrow.down.right"
        case "stable":
            return "equal"
        default:
            return "sparkles"
        }
    }

    var maxDayAmount: Double {
        days.map { $0.amount }.max() ?? 0
    }

    /// The day with the most spending, the latest one when several are equal.
    var busiestDay: DigestDay? {
        var best: DigestDay? = nil

        for day in days where day.amount > 0 {
            if let current = best, day.amount < current.amount {
                continue
            }

            best = day
        }

        return best
    }
}

// MARK: - Text helpers

enum WeeklyDigestText {
    static func format(_ iso: String, pattern: String) -> String {
        let utc = TimeZone(identifier: "UTC") ?? TimeZone.current

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = utc
        parser.dateFormat = "yyyy-MM-dd"

        guard let date = parser.date(from: iso) else {
            return iso
        }

        let formatter = DateFormatter()
        formatter.locale = AppFormat.locale
        formatter.timeZone = utc
        formatter.dateFormat = pattern

        return formatter.string(from: date)
    }

    static func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = AppFormat.locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1

        return formatter.string(from: NSNumber(value: value.isFinite ? value : 0)) ?? "0"
    }

    /// "+12,00 €" for an increase, "-12,00 €" for a decrease.
    static func signedMoney(_ value: Double) -> String {
        let text = AppFormat.money(value)

        return value > 0 ? "+" + text : text
    }
}
