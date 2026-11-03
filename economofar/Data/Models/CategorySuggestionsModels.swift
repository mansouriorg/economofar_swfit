import Foundation

// MARK: - API response of GET /api/analytics/category-suggestions

/// The tickets of one merchant that have no category, and the category suggested for all of them.
struct CategorySuggestionGroup: Codable {
    let merchant: String
    let category: String
    /// Percent of the merchant's categorized tickets that are in this category, with one decimal.
    let confidence: Double
    /// Tickets of the merchant already in this category.
    let supportCount: Int
    /// Tickets of the merchant that have a category at all.
    let categorizedCount: Int
    /// All the tickets of the merchant to fix.
    let ticketCount: Int
    let amount: Double
    /// The most recent tickets to fix, 200 at most.
    let ticketIds: [String]

    /// True when the tickets listed are not all the tickets to fix.
    var isPartial: Bool {
        ticketIds.count < ticketCount
    }
}

struct CategorySuggestions: Codable {
    let months: Int
    /// "2025-10-18"
    let from: String
    /// "2026-10-18"
    let to: String
    /// All the tickets of the period without category (no category or "Autre").
    let uncategorizedCount: Int
    let uncategorizedAmount: Double
    /// Those a suggestion covers.
    let suggestedCount: Int
    let suggestedAmount: Double
    /// The others: unknown merchant, or no reliable category for the merchant.
    let unresolvedCount: Int
    let unresolvedAmount: Double
    /// All the merchants with a suggestion; groups holds the first 50.
    let groupCount: Int
    let groups: [CategorySuggestionGroup]

    var hasUncategorized: Bool {
        uncategorizedCount > 0
    }

    var hasSuggestions: Bool {
        suggestedCount > 0
    }

    var hiddenGroupCount: Int {
        max(groupCount - groups.count, 0)
    }

    /// Tickets that the groups shown can fix at once.
    var fixableTicketCount: Int {
        groups.reduce(0) { $0 + $1.ticketIds.count }
    }
}

// MARK: - Text helpers

enum CategorySuggestionsText {
    /// "1 ticket", "5 tickets"
    static func tickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket" : "\(count) tickets"
    }

    /// "17 oct. 2025", from "2025-10-17"
    static func dateText(_ iso: String) -> String {
        let pieces = iso.split(separator: "-")

        guard pieces.count == 3,
              let year = Int(pieces[0]),
              let day = Int(pieces[2]) else {
            return iso
        }

        let key = "\(pieces[0])-\(pieces[1])"

        guard CategoryTrendsText.splitKey(key) != nil else {
            return iso
        }

        return "\(day) \(CategoryTrendsText.shortMonth(key)) \(year)"
    }

    /// "17 oct. 2025 - 17 oct. 2026"
    static func periodText(_ result: CategorySuggestions) -> String {
        "\(dateText(result.from)) - \(dateText(result.to))"
    }

    /// The big line of the top card.
    static func headline(_ result: CategorySuggestions) -> String {
        guard result.hasUncategorized else {
            return "Tout est classé"
        }

        guard result.hasSuggestions else {
            return "Aucune suggestion"
        }

        return "\(tickets(result.suggestedCount)) à classer"
    }

    /// The sentence under it.
    static func summary(_ result: CategorySuggestions) -> String {
        guard result.hasUncategorized else {
            return "Tous vos tickets ont une catégorie sur cette période."
        }

        guard result.hasSuggestions else {
            return "\(tickets(result.uncategorizedCount)) sans catégorie, mais aucune suggestion fiable pour le moment."
        }

        if result.suggestedCount == result.uncategorizedCount {
            return result.uncategorizedCount < 2
                ? "Votre ticket sans catégorie peut être classé d'après vos habitudes."
                : "Vos \(result.uncategorizedCount) tickets sans catégorie peuvent être classés d'après vos habitudes."
        }

        let verb = result.suggestedCount < 2 ? "peut être classé" : "peuvent être classés"

        return "\(tickets(result.suggestedCount)) sur \(result.uncategorizedCount) sans catégorie \(verb) d'après vos habitudes."
    }

    /// "3 tickets · 57,00 €"
    static func groupDetail(_ group: CategorySuggestionGroup) -> String {
        "\(tickets(group.ticketCount)) · \(AppFormat.money(group.amount))"
    }

    /// Why this category is suggested.
    static func reason(_ group: CategorySuggestionGroup) -> String {
        if group.supportCount == group.categorizedCount {
            return "Vos \(group.categorizedCount) tickets déjà classés pour cette enseigne sont tous en « \(group.category) »."
        }

        return "\(group.supportCount) de vos \(group.categorizedCount) tickets déjà classés pour cette enseigne sont en « \(group.category) » (\(WeeklyDigestText.percent(group.confidence))\u{00A0}%)."
    }

    /// "Classer 4 tickets"
    static func applyLabel(_ group: CategorySuggestionGroup) -> String {
        "Classer \(tickets(group.ticketIds.count))"
    }

    /// Said when a merchant has more tickets to fix than one call handles.
    static func partialNote(_ group: CategorySuggestionGroup) -> String {
        "Les \(group.ticketIds.count) plus récents sont classés d'abord, les autres apparaîtront ensuite."
    }

    /// "Et 1 autre enseigne", "Et 4 autres enseignes"
    static func more(_ rest: Int) -> String {
        rest == 1 ? "Et 1 autre enseigne" : "Et \(rest) autres enseignes"
    }

    static func confirmTitle(_ groups: [CategorySuggestionGroup]) -> String {
        let count = groups.reduce(0) { $0 + $1.ticketIds.count }

        if groups.count == 1, let group = groups.first {
            return "Classer \(tickets(count)) en « \(group.category) » ?"
        }

        return "Classer \(tickets(count)) ?"
    }

    static func confirmMessage(_ groups: [CategorySuggestionGroup]) -> String {
        if groups.count == 1, let group = groups.first {
            return "Chez \(group.merchant), les tickets sans catégorie recevront la catégorie « \(group.category) ». Vous pourrez modifier chaque ticket ensuite."
        }

        return "Chaque ticket recevra la catégorie que vous utilisez déjà pour la même enseigne. Vous pourrez modifier chaque ticket ensuite."
    }

    /// What is said once the tickets have been changed.
    static func appliedMessage(applied: Int, failed: Int, stopped: Bool) -> String {
        var text: String

        if applied == 0 {
            text = "Aucun ticket n'a pu être classé."
        } else if applied == 1 {
            text = "1 ticket classé."
        } else {
            text = "\(applied) tickets classés."
        }

        if failed > 0 && applied > 0 {
            text += failed == 1
                ? " 1 ticket n'a pas pu être modifié."
                : " \(failed) tickets n'ont pas pu être modifiés."
        }

        if stopped {
            text += " Le classement s'est arrêté, réessayez dans un instant."
        }

        return text
    }
}
