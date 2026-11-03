import Foundation

// MARK: - API response of GET /api/analytics/category-profiles

/// What the tickets of a category came to at one merchant.
struct CategoryMerchant: Codable, Identifiable {
    /// "Enseigne inconnue" for the tickets whose merchant is not known.
    let name: String
    /// Number of tickets of the merchant in the category.
    let ticketCount: Int
    let amount: Double

    var id: String {
        name
    }
}

/// One ticket of a category.
struct CategoryTicket: Codable, Identifiable {
    let id: UUID
    /// The merchant as the profile shows it: "Enseigne inconnue" when it is not known.
    let merchant: String
    /// "2026-10-17"
    let date: String
    let amount: Double
}

/// Everything the tickets of the period say about one category.
struct CategoryProfile: Codable, Identifiable {
    /// The name without case, accents and punctuation: it does not change when the category is
    /// written in another way.
    let key: String
    let category: String
    /// Number of tickets.
    let ticketCount: Int
    /// Number of different days with a ticket.
    let activeDays: Int
    let total: Double
    /// Total divided by the tickets that have an amount. Null when none has.
    let average: Double?
    /// Percent of all the spending of the period, with one decimal. Null when nothing was spent.
    let share: Double?
    let firstDate: String
    let lastDate: String
    /// Days from the last ticket to today: 0 when it is dated today.
    let daysSinceLast: Int
    /// Days between two days with a ticket, on average. Null with fewer than 2 such days.
    let daysBetweenPurchases: Int?
    /// Known merchants of the category.
    let merchantCount: Int
    /// Tickets without a known merchant.
    let unknownCount: Int
    /// The 5 entries with most spending.
    let merchants: [CategoryMerchant]
    /// The 10 latest tickets, the most recent first.
    let recent: [CategoryTicket]

    var id: String {
        key
    }

    /// True when the tickets listed are not all the tickets of the category.
    var hasMoreTickets: Bool {
        recent.count < ticketCount
    }
}

struct CategoryProfiles: Codable {
    let months: Int
    /// "2025-10-18"
    let from: String
    /// "2026-10-18"
    let to: String
    let ticketCount: Int
    let totalAmount: Double
    /// All the categories; categories holds the 100 with most spending.
    let categoryCount: Int
    let categories: [CategoryProfile]

    var hasTickets: Bool {
        ticketCount > 0
    }

    var hiddenCount: Int {
        max(categoryCount - categories.count, 0)
    }
}

// MARK: - Text helpers

enum CategoryProfilesText {
    static let unknownMerchant = "Enseigne inconnue"

    /// "1 ticket", "5 tickets"
    static func tickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket" : "\(count) tickets"
    }

    /// "17 oct. 2025", from "2025-10-17"
    static func dateText(_ iso: String) -> String {
        WeeklyDigestText.format(iso, pattern: "d MMM yyyy")
    }

    /// "17 oct. 2025 - 17 oct. 2026"
    static func periodText(_ result: CategoryProfiles) -> String {
        "\(dateText(result.from)) - \(dateText(result.to))"
    }

    /// The big line of the top card.
    static func headline(_ result: CategoryProfiles) -> String {
        guard result.hasTickets else {
            return "Aucun ticket"
        }

        return result.categoryCount < 2 ? "1 catégorie" : "\(result.categoryCount) catégories"
    }

    /// The sentence under it.
    static func summary(_ result: CategoryProfiles) -> String {
        guard result.hasTickets else {
            return "Aucun ticket enregistré sur cette période."
        }

        return "\(AppFormat.money(result.totalAmount)) dépensés sur \(tickets(result.ticketCount))."
    }

    /// "5 tickets · panier moyen 20,88 €"
    static func rowDetail(_ profile: CategoryProfile) -> String {
        var text = tickets(profile.ticketCount)

        if let average = profile.average {
            text += " · panier moyen \(AppFormat.money(average))"
        }

        return text
    }

    /// "49,6 %", or "-" when the share is not known.
    static func shareText(_ share: Double?) -> String {
        guard let share else {
            return "-"
        }

        return WeeklyDigestText.percent(share) + "\u{00A0}%"
    }

    /// Share of the spending, from 0 to 1, for the little bar of a row.
    static func shareFraction(_ share: Double?) -> Double {
        guard let share, share.isFinite else {
            return 0
        }

        return min(max(share / 100, 0), 1)
    }

    /// "Aujourd'hui", "Hier", "Il y a 12 jours", "Il y a 5 mois"
    static func lastPurchase(_ daysSinceLast: Int) -> String {
        let days = min(max(daysSinceLast, 0), 1_000_000)

        switch days {
        case 0:
            return "Aujourd'hui"
        case 1:
            return "Hier"
        case 2..<60:
            return "Il y a \(days) jours"
        default:
            let months = Int((Double(days) / 30.4375).rounded())

            return "Il y a \(months) mois"
        }
    }

    /// "Tous les 12 jours", short enough for the value of a row.
    static func rhythm(_ profile: CategoryProfile) -> String {
        guard let gap = profile.daysBetweenPurchases else {
            return profile.ticketCount < 2 ? "Un seul ticket" : "Un seul jour"
        }

        return gap <= 1 ? "Chaque jour" : "Tous les \(gap) jours"
    }

    /// "5 jours avec un ticket"
    static func activeDaysText(_ profile: CategoryProfile) -> String {
        profile.activeDays < 2 ? "\(profile.activeDays) jour avec un ticket" : "\(profile.activeDays) jours avec un ticket"
    }

    /// The sentence of the top card of a category.
    static func profileSummary(_ profile: CategoryProfile) -> String {
        guard let share = profile.share else {
            return "\(tickets(profile.ticketCount)) sur la période."
        }

        return "\(shareText(share)) de vos dépenses, en \(tickets(profile.ticketCount))."
    }

    static func isUnknown(_ merchant: CategoryMerchant) -> Bool {
        merchant.name == unknownMerchant
    }

    /// Share of a merchant in the spending of the category, from 0 to 1.
    static func merchantFraction(_ merchant: CategoryMerchant, in profile: CategoryProfile) -> Double {
        guard profile.total > 0, merchant.amount.isFinite else {
            return 0
        }

        return min(max(merchant.amount / profile.total, 0), 1)
    }

    /// The known merchants that are listed.
    static func listedMerchants(_ profile: CategoryProfile) -> Int {
        profile.merchants.filter { isUnknown($0) == false }.count
    }

    /// Said when the page lists only the merchants with most spending, or nil when it lists them all.
    static func merchantsNote(_ profile: CategoryProfile) -> String? {
        let listed = listedMerchants(profile)

        guard listed > 0, profile.merchantCount > listed else {
            return nil
        }

        return listed < 2
            ? "Seule l'enseigne avec le plus de dépenses est affichée, sur \(profile.merchantCount)."
            : "Les \(listed) enseignes avec le plus de dépenses sont affichées, sur \(profile.merchantCount)."
    }

    /// Said when some tickets have no known merchant, or nil.
    static func unknownNote(_ profile: CategoryProfile) -> String? {
        guard profile.unknownCount > 0 else {
            return nil
        }

        return "\(tickets(profile.unknownCount)) sans enseigne connue."
    }

    static func listTitle(shown: Int) -> String {
        "Catégories · \(shown)"
    }

    /// Said when the list holds only the first categories.
    static func hiddenNote(hidden: Int, shown: Int) -> String {
        hidden == 1
            ? "Et 1 autre catégorie, avec moins de dépenses que les \(shown) affichées."
            : "Et \(hidden) autres catégories, avec moins de dépenses que les \(shown) affichées."
    }

    /// Said when a category has more tickets than the page lists.
    static func recentNote(shown: Int, total: Int) -> String {
        "Les \(shown) plus récents sur \(total) sont affichés."
    }

    static let emptyHint = "Dès que vos tickets sont enregistrés, vous les retrouvez ici, regroupés par catégorie."

    static let notFound = "Cette catégorie n'a plus de ticket sur la période choisie."
}
