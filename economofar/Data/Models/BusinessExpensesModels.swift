import Foundation

// MARK: - API response of GET /api/analytics/business-expenses

/// One business ticket.
struct BusinessTicket: Codable, Identifiable {
    let id: UUID
    /// The merchant as the page shows it: "Enseigne inconnue" when it is not known.
    let merchant: String
    /// "2026-10-17"
    let date: String
    let amount: Double
}

/// The business tickets that carry the same expense report, project or client.
struct BusinessGroup: Codable, Identifiable {
    /// The name without case, accents and punctuation: it does not change when the label is
    /// written in another way.
    let key: String
    let name: String
    let ticketCount: Int
    let amount: Double
    /// VAT of these tickets.
    let vat: Double
    /// The 10 latest tickets, the most recent first.
    let recent: [BusinessTicket]

    var id: String {
        key
    }
}

/// The business tickets of the period grouped by one label, with the tickets that lack it.
struct BusinessSection: Codable {
    /// All the groups; groups holds the 20 with most spending.
    let groupCount: Int
    let groups: [BusinessGroup]
    /// Business tickets without this label.
    let missingCount: Int
    let missingAmount: Double
    /// The 10 latest of them, the most recent first.
    let missing: [BusinessTicket]

    var hiddenCount: Int {
        max(groupCount - groups.count, 0)
    }
}

struct BusinessExpenses: Codable {
    /// "month", "quarter", "year" or "previous-year"
    let period: String
    /// "2026-01-01"
    let from: String
    /// "2026-10-18"
    let to: String
    /// Business tickets of the period.
    let ticketCount: Int
    let totalAmount: Double
    /// All the tickets of the period, business or not.
    let allTicketCount: Int
    let allAmount: Double
    /// Percent of all the spending of the period that is business, with one decimal. Null when
    /// nothing was spent.
    let share: Double?
    let vatTotal: Double
    /// VAT of the deductible tickets.
    let deductibleVat: Double
    let deductibleCount: Int
    let deductibleAmount: Double
    let reimbursableCount: Int
    let reimbursableAmount: Double
    let reports: BusinessSection
    let projects: BusinessSection
    let clients: BusinessSection

    var hasBusiness: Bool {
        ticketCount > 0
    }

    var hasTickets: Bool {
        allTicketCount > 0
    }

    func section(_ kind: BusinessSectionKind) -> BusinessSection {
        switch kind {
        case .reports:
            return reports
        case .projects:
            return projects
        case .clients:
            return clients
        }
    }
}

// MARK: - Choices

/// What the business tickets are grouped by.
enum BusinessSectionKind: String, CaseIterable, Identifiable {
    case reports
    case projects
    case clients

    var id: String {
        rawValue
    }

    /// Title of the choice and of the list.
    var title: String {
        switch self {
        case .reports:
            return "Notes de frais"
        case .projects:
            return "Projets"
        case .clients:
            return "Clients"
        }
    }

    /// Title of the row of the tickets that have no label.
    var missingTitle: String {
        switch self {
        case .reports:
            return "Sans note de frais"
        case .projects:
            return "Sans projet"
        case .clients:
            return "Sans client"
        }
    }

    /// Said when a ticket needs its label.
    var missingAdvice: String {
        switch self {
        case .reports:
            return "Ouvrez un ticket et renseignez sa référence de note de frais dans la carte « Business & comptabilité »."
        case .projects:
            return "Ouvrez un ticket et renseignez son projet dans la carte « Business & comptabilité »."
        case .clients:
            return "Ouvrez un ticket et renseignez son client dans la carte « Business & comptabilité »."
        }
    }

    /// Said when every business ticket of the period has its label.
    var allSetMessage: String {
        switch self {
        case .reports:
            return "Tous les tickets professionnels de la période ont maintenant une note de frais."
        case .projects:
            return "Tous les tickets professionnels de la période ont maintenant un projet."
        case .clients:
            return "Tous les tickets professionnels de la période ont maintenant un client."
        }
    }

    var icon: String {
        switch self {
        case .reports:
            return "doc.text.fill"
        case .projects:
            return "folder.fill"
        case .clients:
            return "person.2.fill"
        }
    }
}

/// A period of the page: the value the API takes and the words on the choice.
struct BusinessPeriodOption: Identifiable {
    let value: String
    let title: String

    var id: String { value }

    static let all: [BusinessPeriodOption] = [
        BusinessPeriodOption(value: "month", title: "Mois"),
        BusinessPeriodOption(value: "quarter", title: "Trimestre"),
        BusinessPeriodOption(value: "year", title: "Année"),
        BusinessPeriodOption(value: "previous-year", title: "N-1")
    ]
}

// MARK: - Text helpers

enum BusinessExpensesText {
    /// "1 ticket", "5 tickets"
    static func tickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket" : "\(count) tickets"
    }

    /// "17 oct. 2025", from "2025-10-17"
    static func dateText(_ iso: String) -> String {
        WeeklyDigestText.format(iso, pattern: "d MMM yyyy")
    }

    /// "1 janv. 2026 - 18 oct. 2026"
    static func periodText(_ result: BusinessExpenses) -> String {
        "\(dateText(result.from)) - \(dateText(result.to))"
    }

    /// "49,6 %", or "-" when the share is not known.
    static func shareText(_ share: Double?) -> String {
        guard let share, share.isFinite else {
            return "-"
        }

        return WeeklyDigestText.percent(share) + "\u{00A0}%"
    }

    /// The big line of the top card.
    static func headline(_ result: BusinessExpenses) -> String {
        guard result.hasBusiness else {
            return "Aucun frais pro"
        }

        return AppFormat.money(result.totalAmount)
    }

    /// The sentence under it.
    static func summary(_ result: BusinessExpenses) -> String {
        guard result.hasTickets else {
            return "Aucun ticket enregistré sur cette période."
        }

        guard result.hasBusiness else {
            return result.allTicketCount == 1
                ? "Le seul ticket de la période n'est pas marqué professionnel."
                : "Aucun des \(result.allTicketCount) tickets de la période n'est marqué professionnel."
        }

        guard let share = result.share else {
            return "\(professionalTickets(result.ticketCount)) sur la période."
        }

        return "\(shareText(share)) de vos dépenses, en \(tickets(result.ticketCount))."
    }

    /// "1 ticket professionnel", "5 tickets professionnels"
    static func professionalTickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket professionnel" : "\(count) tickets professionnels"
    }

    static func money(_ value: Double) -> String {
        AppFormat.money(value.isFinite ? value : 0)
    }

    /// "Dont 28,33 € sur les tickets déductibles"
    static func vatDetail(_ result: BusinessExpenses) -> String {
        "Dont \(money(result.deductibleVat)) sur les tickets déductibles"
    }

    /// "3 tickets · TVA 28,33 €"
    static func rowDetail(_ group: BusinessGroup) -> String {
        var text = tickets(group.ticketCount)

        if group.vat > 0 {
            text += " · TVA \(money(group.vat))"
        }

        return text
    }

    /// Share of a group in the business spending of the period, from 0 to 1.
    static func fraction(_ amount: Double, of total: Double) -> Double {
        guard total > 0, amount.isFinite else {
            return 0
        }

        return min(max(amount / total, 0), 1)
    }

    /// "49,6 %" of the business spending, or "-" when there is none.
    static func groupShareText(_ amount: Double, of total: Double) -> String {
        guard total > 0, amount.isFinite else {
            return "-"
        }

        let percent = (min(max(amount / total, 0), 1) * 1000).rounded() / 10

        return shareText(percent)
    }

    static func listTitle(_ kind: BusinessSectionKind, count: Int) -> String {
        count > 0 ? "\(kind.title) · \(count)" : kind.title
    }

    /// The sentence of the top card of a group.
    static func groupSummary(amount: Double, total: Double, count: Int) -> String {
        guard total > 0, amount.isFinite else {
            return "\(tickets(count)) sur la période."
        }

        return "\(groupShareText(amount, of: total)) de vos frais pros, en \(tickets(count))."
    }

    /// What VoiceOver reads for a row of the list.
    static func groupAccessibility(_ group: BusinessGroup, total: Double) -> String {
        var text = "\(group.name), \(rowDetail(group)), \(money(group.amount))"

        if total > 0 {
            text += ", \(groupShareText(group.amount, of: total)) des frais pros"
        }

        return text
    }

    /// Said when the list holds only the first groups.
    static func hiddenNote(hidden: Int, shown: Int) -> String {
        "Seules les \(shown) lignes avec le plus de dépenses sont affichées, sur \(shown + hidden)."
    }

    /// "5 tickets à compléter"
    static func missingDetail(count: Int) -> String {
        count < 2 ? "\(count) ticket à compléter" : "\(count) tickets à compléter"
    }

    static func missingDetail(_ section: BusinessSection) -> String {
        missingDetail(count: section.missingCount)
    }

    /// Said when a group or the tickets without label have more tickets than the page lists.
    static func recentNote(shown: Int, total: Int) -> String {
        "Les \(shown) plus récents sur \(total) sont affichés."
    }

    static let emptyHint = "Dès que vos tickets sont enregistrés, vous les retrouvez ici."

    static let noBusinessHint = "Aucun ticket professionnel sur cette période. Ouvrez un ticket et choisissez « Professionnel » dans la carte « Business & comptabilité » : il est alors compté ici."

    static let notFound = "Cette ligne n'apparaît plus dans la liste des frais pros de la période choisie."

    static let method = "Seuls les tickets marqués « Professionnel » sont comptés. Un projet, un client ou une note de frais écrits de plusieurs façons (majuscules, accents, ponctuation) sont regroupés. Touchez une ligne pour voir ses derniers tickets."
}
