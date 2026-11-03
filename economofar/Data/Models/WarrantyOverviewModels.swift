import Foundation

// MARK: - API response of GET /api/analytics/warranties

/// A saved ticket that has a warranty date.
struct WarrantyOverviewItem: Codable, Identifiable {
    let id: UUID
    let merchant: String
    /// The note of the ticket on one line, cut after 120 characters and ended with an ellipsis when it is longer. Null when there is none.
    let note: String?
    let amount: Double
    /// "2026-07-09". Null when the ticket has no purchase date.
    let purchaseDate: String?
    /// "2027-07-09": the last day of the warranty.
    let warrantyDate: String
    /// Days from today to the last day: 0 on the last day, negative once it is over.
    let daysLeft: Int

    var isExpired: Bool {
        daysLeft < 0
    }
}

struct WarrantyOverview: Codable {
    /// "2026-10-18"
    let today: String
    /// A warranty ends soon when it ends within this many days (30, 60 or 90).
    let soonDays: Int
    /// All the warranties ending soon; soon holds the first 100.
    let soonCount: Int
    /// All the other warranties still running.
    let activeCount: Int
    /// All the warranties that ended in the last 12 months.
    let expiredCount: Int
    /// The warranties that ended earlier: only counted.
    let olderCount: Int
    /// Total of the tickets whose warranty is still running.
    let protectedAmount: Double
    /// The ones that end first come first.
    let soon: [WarrantyOverviewItem]
    let active: [WarrantyOverviewItem]
    /// The ones that ended last come first.
    let expired: [WarrantyOverviewItem]

    /// Warranties still running.
    var coveredCount: Int {
        soonCount + activeCount
    }

    /// True when at least one ticket has a warranty date.
    var hasAny: Bool {
        soonCount + activeCount + expiredCount + olderCount > 0
    }
}

// MARK: - Text helpers

enum WarrantyOverviewText {
    /// "1 garantie", "5 garanties"
    static func warranties(_ count: Int) -> String {
        count < 2 ? "\(count) garantie" : "\(count) garanties"
    }

    private static let farAway = 1_000_000

    private static func months(_ days: Int) -> Int {
        Int((Double(days) / 30.4375).rounded())
    }

    private static func years(_ days: Int) -> Int {
        Int((Double(days) / 365.25).rounded())
    }

    /// "Expire aujourd'hui", "Expire demain", "Expire dans 30 jours", "Expire dans 6 mois", "Expirée hier", "Expirée depuis 12 jours"
    static func remaining(_ daysLeft: Int) -> String {
        let days = min(max(daysLeft, -farAway), farAway)

        if days >= 0 {
            switch days {
            case 0:
                return "Expire aujourd'hui"
            case 1:
                return "Expire demain"
            case 2..<90:
                return "Expire dans \(days) jours"
            case 90..<730:
                return "Expire dans \(months(days)) mois"
            default:
                let count = years(days)

                return count < 2 ? "Expire dans 1 an" : "Expire dans \(count) ans"
            }
        }

        let ago = -days

        switch ago {
        case 1:
            return "Expirée hier"
        case 2..<90:
            return "Expirée depuis \(ago) jours"
        case 90..<730:
            return "Expirée depuis \(months(ago)) mois"
        default:
            let count = years(ago)

            return count < 2 ? "Expirée depuis 1 an" : "Expirée depuis \(count) ans"
        }
    }

    /// "9 juil. 2026", from "2026-07-09"
    static func dateText(_ iso: String) -> String {
        WeeklyDigestText.format(iso, pattern: "d MMM yyyy")
    }

    /// "Achat du 9 juil. 2026", or nil when the ticket has no purchase date.
    static func purchaseLine(_ item: WarrantyOverviewItem) -> String? {
        guard let purchaseDate = item.purchaseDate, purchaseDate.isEmpty == false else {
            return nil
        }

        return "Achat du \(dateText(purchaseDate))"
    }

    /// "Expire dans 30 jours · jusqu'au 17 nov. 2026", "Expirée hier · le 17 oct. 2026"
    static func endLine(_ item: WarrantyOverviewItem) -> String {
        let date = dateText(item.warrantyDate)

        if item.isExpired {
            return "\(remaining(item.daysLeft)) · le \(date)"
        }

        return "\(remaining(item.daysLeft)) · jusqu'au \(date)"
    }

    /// The big line of the top card.
    static func headline(_ result: WarrantyOverview) -> String {
        guard result.hasAny else {
            return "Aucune garantie"
        }

        guard result.coveredCount > 0 else {
            return "Aucune garantie en cours"
        }

        return "\(warranties(result.coveredCount)) en cours"
    }

    /// The sentence under it.
    static func summary(_ result: WarrantyOverview) -> String {
        guard result.hasAny else {
            return "Aucune garantie à suivre pour le moment."
        }

        guard result.coveredCount > 0 else {
            return "Toutes les garanties enregistrées sont terminées."
        }

        var text = result.protectedAmount > 0
            ? "\(AppFormat.money(result.protectedAmount)) d'achats encore couverts"
            : "Aucun montant enregistré pour ces tickets"

        if result.soonCount == 1 {
            text += ", dont 1 garantie se termine dans les \(result.soonDays) jours"
        } else if result.soonCount > 1 {
            text += ", dont \(result.soonCount) garanties se terminent dans les \(result.soonDays) jours"
        }

        return text + "."
    }

    /// What the choice of the period means.
    static func soonCaption(_ soonDays: Int) -> String {
        "Une garantie est « bientôt expirée » quand elle se termine dans les \(soonDays) jours."
    }

    static func soonTitle(_ count: Int) -> String {
        "Bientôt expirées · \(count)"
    }

    static func activeTitle(_ count: Int) -> String {
        "En cours · \(count)"
    }

    static func expiredTitle(_ count: Int) -> String {
        "Expirées récemment · \(count)"
    }

    /// Said when a list holds only the first warranties.
    static func partialNote(shown: Int, total: Int) -> String {
        "Les \(shown) premières sur \(total) sont affichées."
    }

    /// Said for the warranties that ended more than a year ago.
    static func olderNote(_ count: Int) -> String {
        count == 1
            ? "1 garantie terminée depuis plus d'un an n'est pas affichée."
            : "\(count) garanties terminées depuis plus d'un an ne sont pas affichées."
    }

    static let emptyHint = "Ajoutez une date de garantie (AAAA-MM-JJ) dans le détail d'un ticket pour la suivre ici."
}
