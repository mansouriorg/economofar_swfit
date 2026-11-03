import Foundation

// MARK: - API response of GET /api/analytics/budget-tracking

/// One ticket of a category in the month.
struct BudgetTrackingTicket: Codable, Identifiable {
    let id: UUID
    /// The merchant as the page shows it: "Enseigne inconnue" when it is not known.
    let merchant: String
    /// "2026-10-17"
    let date: String
    /// The total of the ticket, nil when the ticket has no total.
    let amount: Double?
}

/// Where a budget stands: the server says "OK", "WARNING" (80 % of the budget or more, up to the
/// budget) or "OVER" (more than the budget).
enum BudgetTrackingLevel {
    case ok
    case warning
    case over

    init(status: String) {
        switch status {
        case "OVER":
            self = .over
        case "WARNING":
            self = .warning
        default:
            self = .ok
        }
    }
}

/// The budget of one category and what was spent in it during the month.
struct BudgetTrackingLine: Codable, Identifiable {
    /// The name without the spaces around it and without capitals: the way the budgets screen matches
    /// a ticket with a budget.
    let key: String
    /// The name of the budget as it was saved.
    let name: String
    let budget: Double
    let spent: Double
    /// Budget minus spending, negative when the budget is exceeded.
    let remaining: Double
    /// Spending divided by the budget, with one decimal, it can be above 100.
    let percentUsed: Double
    let status: String
    let ticketCount: Int
    /// What the month would reach at the same daily pace. Nil for a month that has ended, before the
    /// 5th day of the current month, and when nothing was spent.
    let projected: Double?
    let projectedOver: Bool
    /// What can still be spent each day up to the end of the month, today included. Nil for a month
    /// that has ended and when nothing remains.
    let dailyAllowance: Double?
    /// The 10 latest tickets, the most recent day first.
    let recent: [BudgetTrackingTicket]

    var id: String {
        key
    }

    var level: BudgetTrackingLevel {
        BudgetTrackingLevel(status: status)
    }

    var hasMoreTickets: Bool {
        recent.count < ticketCount
    }
}

/// A category that has spending in the month and no budget.
struct BudgetTrackingOther: Codable, Identifiable {
    /// Empty for the tickets without category.
    let key: String
    let name: String
    let ticketCount: Int
    let amount: Double

    var id: String {
        key
    }

    var hasNoCategory: Bool {
        key.isEmpty
    }
}

struct BudgetTrackingOverview: Codable {
    /// "2026-10"
    let month: String
    let currentMonth: Bool
    /// The months next to this one that can be asked for, nil at the end of the range.
    let previousMonth: String?
    let nextMonth: String?
    let dayOfMonth: Int
    let daysInMonth: Int
    /// Days up to the end of the month, today included, 0 for a month that has ended.
    let daysLeft: Int
    /// All the tickets of the month, with or without a budget.
    let ticketCount: Int
    let monthSpent: Double
    let budgetTotal: Double
    let budgetSpent: Double
    let budgetRemaining: Double
    /// Nil when there is no budget.
    let percentUsed: Double?
    let warningCount: Int
    let overCount: Int
    /// The exceeded budgets first, then the ones close to the limit, then the others.
    let budgets: [BudgetTrackingLine]
    /// All the categories with spending and no budget; others holds the 10 with most spending.
    let otherCount: Int
    let otherSpent: Double
    let others: [BudgetTrackingOther]

    var hasBudgets: Bool {
        !budgets.isEmpty
    }

    var hasTickets: Bool {
        ticketCount > 0
    }

    var hiddenOtherCount: Int {
        max(otherCount - others.count, 0)
    }

    var calmCount: Int {
        max(budgets.count - warningCount - overCount, 0)
    }
}

// MARK: - Text helpers

enum BudgetTrackingText {
    static func money(_ value: Double) -> String {
        AppFormat.money(value.isFinite ? value : 0)
    }

    /// "1 ticket", "5 tickets"
    static func tickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket" : "\(count) tickets"
    }

    /// "Octobre 2026", from "2026-10"
    static func monthTitle(_ month: String) -> String {
        let text = WeeklyDigestText.format(month + "-01", pattern: "MMMM yyyy")

        guard let first = text.first else {
            return text
        }

        return first.uppercased() + text.dropFirst()
    }

    /// "17 oct. 2025", from "2025-10-17"
    static func dateText(_ iso: String) -> String {
        WeeklyDigestText.format(iso, pattern: "d MMM yyyy")
    }

    /// "80 %", or "-" when it is not known.
    static func percentText(_ value: Double?) -> String {
        guard let value, value.isFinite else {
            return "-"
        }

        return WeeklyDigestText.percent(value) + "\u{00A0}%"
    }

    /// Length of a progress bar, from 0 to 1. A budget that is exceeded fills the bar.
    static func fraction(spent: Double, budget: Double) -> Double {
        guard budget > 0, budget.isFinite, spent.isFinite else {
            return 0
        }

        return min(max(spent / budget, 0), 1)
    }

    static func statusTitle(_ line: BudgetTrackingLine) -> String {
        switch line.level {
        case .ok:
            return "Dans le budget"
        case .warning:
            return line.remaining > 0 ? "Bientôt atteint" : "Budget atteint"
        case .over:
            return "Budget dépassé"
        }
    }

    static func icon(_ level: BudgetTrackingLevel) -> String {
        switch level {
        case .ok:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .over:
            return "xmark.octagon.fill"
        }
    }

    /// "80,00 € sur 100,00 €"
    static func spentText(_ line: BudgetTrackingLine) -> String {
        "\(money(line.spent)) sur \(money(line.budget))"
    }

    /// "Reste 20,00 €", "Dépassé de 5,00 €"
    static func remainingText(_ line: BudgetTrackingLine) -> String {
        if line.remaining < 0 {
            return "Dépassé de \(money(-line.remaining))"
        }

        if line.remaining == 0 {
            return "Rien de disponible"
        }

        return "Reste \(money(line.remaining))"
    }

    /// What VoiceOver reads for a row of the list.
    static func rowAccessibility(_ line: BudgetTrackingLine) -> String {
        "\(line.name), \(statusTitle(line)), \(spentText(line)), \(percentText(line.percentUsed)), \(remainingText(line))"
    }

    /// The big line of the top card.
    static func headline(_ overview: BudgetTrackingOverview) -> String {
        guard overview.hasBudgets else {
            return overview.monthSpent > 0 ? money(overview.monthSpent) : "Aucune dépense"
        }

        if overview.budgetRemaining < 0 {
            return "Dépassé de \(money(-overview.budgetRemaining))"
        }

        return "Reste \(money(overview.budgetRemaining))"
    }

    /// The sentence under the big line.
    static func summary(_ overview: BudgetTrackingOverview) -> String {
        guard overview.hasBudgets else {
            return "Aucun budget pour l'instant : fixez une limite par catégorie sur l'écran « Budgets par catégorie »."
        }

        return "\(money(overview.budgetSpent)) dépensés sur \(money(overview.budgetTotal)) de budgets, soit \(percentText(overview.percentUsed))."
    }

    /// Where the month stands.
    static func monthProgress(_ overview: BudgetTrackingOverview) -> String {
        if overview.currentMonth {
            let days = overview.daysLeft < 2 ? "\(overview.daysLeft) jour restant" : "\(overview.daysLeft) jours restants"

            return "Jour \(overview.dayOfMonth) sur \(overview.daysInMonth) · \(days), aujourd'hui compris."
        }

        return "Mois terminé : \(overview.daysInMonth) jours."
    }

    static let projectionTitle = "À ce rythme, fin de mois"

    /// "Au-dessus du budget de 100,00 €" or "Dans le budget de 100,00 €"
    static func projectionDetail(_ line: BudgetTrackingLine) -> String {
        if line.projectedOver {
            return "Au-dessus du budget de \(money(line.budget))"
        }

        return "Dans le budget de \(money(line.budget))"
    }

    /// "11 jours restants, aujourd'hui compris"
    static func allowanceDetail(daysLeft: Int) -> String {
        daysLeft < 2 ? "\(daysLeft) jour restant, aujourd'hui compris" : "\(daysLeft) jours restants, aujourd'hui compris"
    }

    static func listTitle(count: Int) -> String {
        count > 0 ? "Budgets · \(count)" : "Budgets"
    }

    static func othersTitle(count: Int) -> String {
        count > 0 ? "Dépenses sans budget · \(count)" : "Dépenses sans budget"
    }

    /// "5 tickets", with what can be done for a category that has no budget.
    static func otherDetail(_ other: BudgetTrackingOther) -> String {
        if other.hasNoCategory {
            return "\(tickets(other.ticketCount)) · sans catégorie, donc sans budget possible"
        }

        return "\(tickets(other.ticketCount)) · pas de budget pour cette catégorie"
    }

    static func hiddenNote(hidden: Int, shown: Int) -> String {
        "Seules les \(shown) catégories avec le plus de dépenses sont affichées, sur \(shown + hidden)."
    }

    static func recentNote(shown: Int, total: Int) -> String {
        "Les \(shown) plus récents sur \(total) sont affichés."
    }

    static let manageTitle = "Modifier mes budgets"

    static let manageSubtitle = "Ajouter, changer ou supprimer une limite par catégorie"

    static let noBudgetHint = "Vous n'avez pas encore de budget. Un budget est une limite mensuelle par catégorie, par exemple 250 € pour l'alimentation : créez-en sur l'écran « Budgets par catégorie » et vous voyez ici où vous en êtes, jour après jour."

    static let emptyMonthHint = "Aucun ticket enregistré ce mois-ci. Dès qu'il y en a, vous voyez ici où vous en êtes dans chaque budget."

    static let noTicketsInCategory = "Aucun ticket de cette catégorie sur ce mois."

    static let notFound = "Ce budget n'existe plus ou n'apparaît plus dans les chiffres de ce mois."

    static let method = "Les budgets sont ceux de l'écran « Budgets par catégorie » et valent pour chaque mois. Les dépenses sont celles de vos tickets enregistrés, comptées comme sur cet écran : un ticket appartient au budget de la même catégorie, sans tenir compte des majuscules ni des espaces autour du nom, et le mois entier est compté, jours à venir compris. Un remboursement vient en déduction."

    /// The server shows a projection from this day of the month.
    static let projectionFromDay = 5

    static let paceNote = "La projection prolonge le rythme de dépenses du mois ; elle apparaît à partir du 5 du mois."

    static let othersNote = "Pour fixer un budget à l'une de ces catégories, ouvrez « Budgets par catégorie »."
}
