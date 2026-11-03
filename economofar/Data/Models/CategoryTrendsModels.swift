import Foundation

// MARK: - API response of GET /api/analytics/category-trends

/// How the spending of one category moved over the months of the window.
struct CategoryTrend: Codable {
    let name: String
    /// One amount per month of the window, the oldest first.
    let totals: [Double]
    let total: Double
    /// Null when no month is tracked.
    let monthlyAverage: Double?
    /// Monthly average of the most recent months. Null when the history is too short to compare.
    let recentAverage: Double?
    /// Monthly average of the same number of months before them.
    let earlierAverage: Double?
    /// Change from the earlier months to the recent ones. Null when it cannot be calculated.
    let changePercent: Double?
    /// UP, DOWN, STABLE, NEW, GONE or NONE
    let trend: String
}

struct CategoryTrends: Codable {
    /// "2026-04"
    let from: String
    /// "2026-09": the last finished month.
    let to: String
    let months: Int
    /// The months of the window, the oldest first: ["2026-04", ..., "2026-09"].
    let monthKeys: [String]
    /// Months from the first one with a ticket.
    let trackedMonths: Int
    /// Number of recent months (and of earlier months) that the trends compare. 0 when too short.
    let compareMonths: Int
    let overall: CategoryTrend
    let categoryCount: Int
    let categories: [CategoryTrend]

    var hasData: Bool {
        trackedMonths > 0
    }
}

// MARK: - Text helpers

enum TrendBarRole {
    case untracked
    case earlier
    case recent
    case other
}

enum CategoryTrendsText {
    private static let monthNames = [
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre"
    ]

    private static let shortMonthNames = [
        "janv.", "févr.", "mars", "avr.", "mai", "juin",
        "juil.", "août", "sept.", "oct.", "nov.", "déc."
    ]

    /// "2026-04" gives (2026, 4); nil for anything else.
    static func splitKey(_ key: String) -> (year: Int, month: Int)? {
        let pieces = key.split(separator: "-")

        guard pieces.count == 2,
              let year = Int(pieces[0]),
              let month = Int(pieces[1]),
              month >= 1,
              month <= 12 else {
            return nil
        }

        return (year, month)
    }

    /// "avr."
    static func shortMonth(_ key: String) -> String {
        guard let parts = splitKey(key) else {
            return key
        }

        return shortMonthNames[parts.month - 1]
    }

    /// "Septembre 2026"
    static func monthTitle(_ key: String) -> String {
        guard let parts = splitKey(key) else {
            return key
        }

        let name = monthNames[parts.month - 1]

        return name.prefix(1).uppercased() + String(name.dropFirst()) + " \(parts.year)"
    }

    /// "septembre 2026", for the middle of a sentence
    static func monthYear(_ key: String) -> String {
        guard let parts = splitKey(key) else {
            return key
        }

        return "\(monthNames[parts.month - 1]) \(parts.year)"
    }

    /// "sept. 2026", "avr. - sept. 2026", "oct. 2025 - sept. 2026"
    static func periodText(_ result: CategoryTrends) -> String {
        let startIndex = max(result.monthKeys.count - result.trackedMonths, 0)
        let firstKey = result.trackedMonths > 0 && startIndex < result.monthKeys.count
            ? result.monthKeys[startIndex]
            : (result.monthKeys.first ?? result.from)
        let lastKey = result.monthKeys.last ?? result.to

        guard let first = splitKey(firstKey), let last = splitKey(lastKey) else {
            return "\(firstKey) - \(lastKey)"
        }

        if firstKey == lastKey {
            return "\(shortMonth(lastKey)) \(last.year)"
        }

        if first.year == last.year {
            return "\(shortMonth(firstKey)) - \(shortMonth(lastKey)) \(last.year)"
        }

        return "\(shortMonth(firstKey)) \(first.year) - \(shortMonth(lastKey)) \(last.year)"
    }

    static func title(_ trend: String) -> String {
        switch trend {
        case "UP":
            return "En hausse"
        case "DOWN":
            return "En baisse"
        case "STABLE":
            return "Stable"
        case "NEW":
            return "Nouvelle"
        case "GONE":
            return "Disparue"
        default:
            return "Pas de tendance"
        }
    }

    /// The title for the whole spending, which is not a category.
    static func overallTitle(_ trend: String) -> String {
        switch trend {
        case "NEW":
            return "Nouvelle activité"
        case "GONE":
            return "Arrêt des dépenses"
        default:
            return title(trend)
        }
    }

    static func icon(_ trend: String) -> String {
        switch trend {
        case "UP":
            return "arrow.up.right"
        case "DOWN":
            return "arrow.down.right"
        case "STABLE":
            return "equal"
        case "NEW":
            return "sparkles"
        case "GONE":
            return "minus.circle"
        default:
            return "ellipsis"
        }
    }

    /// "+12,5 %", "-3 %"
    static func percentText(_ percent: Double) -> String {
        (percent > 0 ? "+" : "") + WeeklyDigestText.percent(percent) + " %"
    }

    /// The text of the badge: "+23 %", "-15 %", "Stable", "Nouvelle", "Disparue", "-".
    /// The merged line stands for several categories, so it is worded in the plural.
    static func badgeText(_ category: CategoryTrend, merged: Bool = false) -> String {
        switch category.trend {
        case "UP", "DOWN":
            return category.changePercent.map { percentText($0) } ?? title(category.trend)
        case "STABLE":
            return "Stable"
        case "NEW":
            return merged ? "Nouvelles" : "Nouvelle"
        case "GONE":
            return merged ? "Disparues" : "Disparue"
        default:
            return "-"
        }
    }

    private static func recentPart(_ average: Double, _ count: Int) -> String {
        count == 1
            ? "\(AppFormat.money(average)) le dernier mois"
            : "\(AppFormat.money(average)) par mois sur les \(count) derniers mois"
    }

    private static func earlierPart(_ average: Double, _ count: Int) -> String {
        count == 1
            ? "\(AppFormat.money(average)) le mois précédent"
            : "\(AppFormat.money(average)) par mois sur les \(count) mois précédents"
    }

    /// The sentence of the top card, about the whole spending.
    static func summary(_ result: CategoryTrends) -> String {
        let overall = result.overall
        let count = result.compareMonths

        guard result.hasData else {
            return "Aucune dépense sur ces mois."
        }

        guard count >= 1, let recent = overall.recentAverage, let earlier = overall.earlierAverage else {
            return "Il faut au moins 2 mois terminés avec des tickets pour dégager une tendance."
        }

        switch overall.trend {
        case "UP", "DOWN":
            let direction = overall.trend == "UP" ? "en hausse" : "en baisse"
            let amount = overall.changePercent.map { " de \(WeeklyDigestText.percent(abs($0))) %" } ?? ""

            return "Vos dépenses sont \(direction)\(amount) : \(recentPart(recent, count)) contre \(earlierPart(earlier, count))."
        case "STABLE":
            return "Vos dépenses sont stables : \(recentPart(recent, count)) contre \(earlierPart(earlier, count))."
        case "NEW":
            let before = count == 1 ? "le mois précédent" : "sur les \(count) mois précédents"

            return "Vos dépenses ont démarré : \(recentPart(recent, count)), rien \(before)."
        case "GONE":
            let after = count == 1 ? "le dernier mois" : "sur les \(count) derniers mois"

            return "Vous n'avez rien dépensé \(after), contre \(earlierPart(earlier, count))."
        default:
            return "Aucune dépense sur les mois comparés."
        }
    }

    /// "Moyenne 120,00 € par mois · sept. 130,00 €"
    static func rowDetail(_ category: CategoryTrend, monthKeys: [String]) -> String {
        var text = "Moyenne \(AppFormat.money(category.monthlyAverage ?? 0)) par mois"

        if let last = category.totals.last, let key = monthKeys.last {
            text += " · \(shortMonth(key)) \(AppFormat.money(last))"
        }

        return text
    }

    static func rowAccessibility(_ category: CategoryTrend, monthKeys: [String]) -> String {
        var text = "\(category.name), \(title(category.trend))"

        if category.trend == "UP" || category.trend == "DOWN", let percent = category.changePercent {
            text += " de \(WeeklyDigestText.percent(abs(percent))) %"
        }

        return text + ", " + rowDetail(category, monthKeys: monthKeys)
    }

    /// What a bar of the little charts stands for.
    static func role(index: Int, count: Int, trackedMonths: Int, compareMonths: Int) -> TrendBarRole {
        if index < count - trackedMonths {
            return .untracked
        }

        if compareMonths >= 1 {
            if index >= count - compareMonths {
                return .recent
            }

            if index >= count - 2 * compareMonths {
                return .earlier
            }
        }

        return .other
    }
}
