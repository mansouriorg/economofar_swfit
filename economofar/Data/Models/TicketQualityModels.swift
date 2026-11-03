import Foundation

// MARK: - API response of GET /api/analytics/quality

/// How many tickets have one kind of problem.
struct QualityIssueCount: Codable, Identifiable {
    /// UNKNOWN_MERCHANT, NO_CATEGORY, DUPLICATE, MISSING_AMOUNT or FUTURE_DATE
    let type: String
    let count: Int

    var id: String { type }
}

/// A saved ticket that deserves a look.
struct QualityTicket: Codable, Identifiable {
    let id: UUID
    /// "2026-10-17"
    let date: String
    let merchant: String
    let category: String
    /// Null when the ticket has no amount.
    let amount: Double?
    let issues: [String]
}

struct TicketQuality: Codable {
    let months: Int
    let from: String
    let to: String
    /// Number of tickets looked at.
    let examined: Int
    /// Number of tickets with at least one problem.
    let flaggedCount: Int
    /// Always the 5 kinds of problem, in a fixed order.
    let counts: [QualityIssueCount]
    /// At most 100 flagged tickets, the most recent first.
    let tickets: [QualityTicket]

    var okCount: Int {
        max(examined - flaggedCount, 0)
    }

    var periodText: String {
        "\(WeeklyDigestText.format(from, pattern: "d MMM yyyy")) - \(WeeklyDigestText.format(to, pattern: "d MMM yyyy"))"
    }
}

// MARK: - Text helpers

enum QualityText {
    static func title(_ type: String) -> String {
        switch type {
        case "UNKNOWN_MERCHANT":
            return "Commerçant inconnu"
        case "NO_CATEGORY":
            return "Catégorie à préciser"
        case "DUPLICATE":
            return "Doublon possible"
        case "MISSING_AMOUNT":
            return "Montant absent ou nul"
        case "FUTURE_DATE":
            return "Date dans le futur"
        default:
            return type
        }
    }

    static func icon(_ type: String) -> String {
        switch type {
        case "UNKNOWN_MERCHANT":
            return "questionmark.circle.fill"
        case "NO_CATEGORY":
            return "tag.fill"
        case "DUPLICATE":
            return "doc.on.doc.fill"
        case "MISSING_AMOUNT":
            return "eurosign.circle.fill"
        case "FUTURE_DATE":
            return "calendar.badge.exclamationmark"
        default:
            return "exclamationmark.circle.fill"
        }
    }

    static func explanation(_ type: String) -> String {
        switch type {
        case "UNKNOWN_MERCHANT":
            return "Le nom du commerçant est absent ou inconnu (par exemple « Analyse en cours ») : les analyses par commerçant ne peuvent pas utiliser ce ticket."
        case "NO_CATEGORY":
            return "La catégorie est vide ou « Autre » : ce ticket pèse peu dans les budgets par catégorie et dans les comparaisons."
        case "DUPLICATE":
            return "Un autre ticket a le même commerce, le même montant et le même jour. Si c'est un doublon, supprimez-en un."
        case "MISSING_AMOUNT":
            return "Le montant est absent ou nul : ce ticket compte pour très peu dans les analyses. Ouvrez-le et saisissez le montant."
        case "FUTURE_DATE":
            return "La date est dans le futur : la plupart des analyses ne comptent pas ce ticket. Corrigez la date."
        default:
            return ""
        }
    }

    static func periodTitle(_ months: Int) -> String {
        "\(months) mois"
    }

    /// "1 ticket", "5 tickets".
    static func ticketCount(_ count: Int) -> String {
        count > 1 ? "\(count) tickets" : "\(count) ticket"
    }
}
