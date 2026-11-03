import Foundation

// MARK: - API response of GET /api/analytics/small-purchases

/// The small purchases of one month.
struct SmallMonth: Codable {
    let count: Int
    let total: Double
}

/// A merchant or a category among the small purchases.
struct SmallGroup: Codable {
    let name: String
    let count: Int
    let total: Double
    /// Percent of all the small purchases, with one decimal.
    let share: Double?
}

struct SmallPurchases: Codable {
    /// "2026-04"
    let from: String
    /// "2026-09": the last finished month.
    let to: String
    let months: Int
    /// A purchase is small when its amount is at most this, in euros.
    let threshold: Int
    /// The months of the window, the oldest first: ["2026-04", ..., "2026-09"].
    let monthKeys: [String]
    /// Months from the first one with a ticket.
    let trackedMonths: Int
    /// All the purchases of the window, small or not.
    let purchaseCount: Int
    let totalAmount: Double
    let smallCount: Int
    let smallTotal: Double
    /// Null when there is no small purchase.
    let smallAverage: Double?
    /// Null when no month is tracked.
    let monthlyAverage: Double?
    let yearlyEstimate: Double?
    let yearlySavingIfQuarterFewer: Double?
    /// Percent of all the spending, null when nothing was spent.
    let shareOfSpending: Double?
    /// Percent of all the purchases, null when there was no purchase.
    let shareOfPurchases: Double?
    /// Null when there is no small purchase.
    let daysPerPurchase: Double?
    /// One entry per month of the window, the oldest first.
    let perMonth: [SmallMonth]
    let merchantCount: Int
    let merchants: [SmallGroup]
    let categoryCount: Int
    let categories: [SmallGroup]

    var hasData: Bool {
        trackedMonths > 0
    }

    var hasSmall: Bool {
        smallCount > 0
    }
}

// MARK: - Text helpers

enum SmallPurchasesText {
    /// "≤ 10 €"
    static func thresholdBadge(_ threshold: Int) -> String {
        "≤\u{00A0}\(threshold)\u{00A0}€"
    }

    /// "10 €", for the middle of a sentence
    static func thresholdAmount(_ threshold: Int) -> String {
        "\(threshold)\u{00A0}€"
    }

    /// "0 achat", "1 achat", "5 achats"
    static func purchases(_ count: Int) -> String {
        count < 2 ? "\(count) achat" : "\(count) achats"
    }

    /// "sept. 2026", "avr. - sept. 2026", "oct. 2025 - sept. 2026"
    static func periodText(_ result: SmallPurchases) -> String {
        let startIndex = max(result.monthKeys.count - result.trackedMonths, 0)
        let firstKey = result.trackedMonths > 0 && startIndex < result.monthKeys.count
            ? result.monthKeys[startIndex]
            : (result.monthKeys.first ?? result.from)
        let lastKey = result.monthKeys.last ?? result.to

        guard let first = CategoryTrendsText.splitKey(firstKey),
              let last = CategoryTrendsText.splitKey(lastKey) else {
            return "\(firstKey) - \(lastKey)"
        }

        if firstKey == lastKey {
            return "\(CategoryTrendsText.shortMonth(lastKey)) \(last.year)"
        }

        if first.year == last.year {
            return "\(CategoryTrendsText.shortMonth(firstKey)) - \(CategoryTrendsText.shortMonth(lastKey)) \(last.year)"
        }

        return "\(CategoryTrendsText.shortMonth(firstKey)) \(first.year) - \(CategoryTrendsText.shortMonth(lastKey)) \(last.year)"
    }

    /// The sentence of the top card.
    static func summary(_ result: SmallPurchases) -> String {
        guard result.hasData else {
            return "Aucun ticket sur ces mois."
        }

        let limit = thresholdAmount(result.threshold)

        guard result.hasSmall else {
            return "Aucun achat de \(limit) ou moins sur ces mois."
        }

        var text = "\(purchases(result.smallCount)) de \(limit) ou moins"

        if let share = result.shareOfSpending {
            text += ", soit \(WeeklyDigestText.percent(share))\u{00A0}% de vos dépenses"
        }

        if let share = result.shareOfPurchases {
            text += " et \(WeeklyDigestText.percent(share))\u{00A0}% de vos achats"
        }

        return text + "."
    }

    /// "environ un tous les 3 jours"
    static func frequency(_ daysPerPurchase: Double) -> String {
        if daysPerPurchase < 1 {
            return "plus d'un par jour"
        }

        let days = Int(daysPerPurchase.rounded())

        return days <= 1 ? "environ un par jour" : "environ un tous les \(days) jours"
    }

    /// "Environ un par jour": the same text with a capital letter.
    static func capitalised(_ text: String) -> String {
        text.prefix(1).uppercased() + String(text.dropFirst())
    }

    /// "Et 3 autres enseignes", "Et 1 autre catégorie"
    static func more(_ rest: Int, singular: String, plural: String) -> String {
        rest == 1 ? "Et 1 autre \(singular)" : "Et \(rest) autres \(plural)"
    }

    /// "12,5 %", or "-" when the share is not known.
    static func shareText(_ share: Double?) -> String {
        guard let share else {
            return "-"
        }

        return WeeklyDigestText.percent(share) + "\u{00A0}%"
    }

    /// "3 achats · 55,2 % des petits achats"
    static func groupDetail(_ group: SmallGroup) -> String {
        var text = purchases(group.count)

        if let share = group.share {
            text += " · \(WeeklyDigestText.percent(share))\u{00A0}% des petits achats"
        }

        return text
    }

    /// What the row of a month says to VoiceOver.
    static func monthAccessibility(key: String, month: SmallMonth, tracked: Bool) -> String {
        let name = CategoryTrendsText.monthTitle(key)

        guard tracked else {
            return "\(name), avant votre premier ticket"
        }

        return "\(name), \(purchases(month.count)), \(AppFormat.money(month.total))"
    }
}
