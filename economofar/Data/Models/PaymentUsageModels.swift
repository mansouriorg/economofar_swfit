import Foundation

// MARK: - API response of GET /api/analytics/payment-methods

/// One ticket paid with a payment method.
struct PaymentUsageTicket: Codable, Identifiable {
    let id: UUID
    /// The merchant as the page shows it: "Enseigne inconnue" when it is not known.
    let merchant: String
    /// "2026-10-17"
    let date: String
    let amount: Double
}

/// What was paid with a payment method during one calendar month.
struct PaymentUsageMonth: Codable, Identifiable {
    /// "2026-10"
    let month: String
    let ticketCount: Int
    let amount: Double

    var id: String {
        month
    }
}

/// What was paid with a payment method in one category.
struct PaymentUsageCategory: Codable, Identifiable {
    let name: String
    let ticketCount: Int
    let amount: Double

    var id: String {
        name
    }
}

/// The tickets of the period that were paid in the same way.
struct PaymentUsageMethod: Codable, Identifiable {
    /// The name without case, accents and punctuation: it does not change when the method is
    /// written in another way.
    let key: String
    let name: String
    let ticketCount: Int
    let amount: Double
    /// Spending divided by the tickets that have an amount. Null when none has.
    let average: Double?
    /// Percent of all the spending of the period, with one decimal. Null when nothing was spent.
    let share: Double?
    /// "2026-09-03"
    let firstDate: String
    /// "2026-11-18"
    let lastDate: String
    let daysSinceLast: Int
    /// Every calendar month of the period, the oldest first, the months without ticket included.
    let months: [PaymentUsageMonth]
    /// All the categories that were paid with this method; categories holds the 5 with most spending.
    let categoryCount: Int
    let categories: [PaymentUsageCategory]
    /// The 10 latest tickets, the most recent day first.
    let recent: [PaymentUsageTicket]

    var id: String {
        key
    }
}

struct PaymentUsage: Codable {
    /// Length of the period in calendar months, the current one included.
    let months: Int
    /// "2026-09-01"
    let from: String
    /// "2026-11-20"
    let to: String
    /// All the tickets of the period, with or without a payment method.
    let ticketCount: Int
    let totalAmount: Double
    /// All the payment methods; methods holds the 20 with most spending.
    let methodCount: Int
    let methods: [PaymentUsageMethod]
    /// Tickets without payment method.
    let unspecifiedCount: Int
    let unspecifiedAmount: Double
    /// The 10 latest of them, the most recent day first.
    let unspecified: [PaymentUsageTicket]

    var hasTickets: Bool {
        ticketCount > 0
    }

    var hiddenCount: Int {
        max(methodCount - methods.count, 0)
    }
}

// MARK: - Choices

/// A length of period of the page: the number of months the API takes and the words on the choice.
struct PaymentUsageMonthsOption: Identifiable {
    let value: Int
    let title: String

    var id: Int { value }

    static let all: [PaymentUsageMonthsOption] = [
        PaymentUsageMonthsOption(value: 3, title: "3 mois"),
        PaymentUsageMonthsOption(value: 12, title: "12 mois"),
        PaymentUsageMonthsOption(value: 24, title: "24 mois")
    ]
}

// MARK: - Text helpers

enum PaymentUsageText {
    /// "1 ticket", "5 tickets"
    static func tickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket" : "\(count) tickets"
    }

    static func money(_ value: Double) -> String {
        AppFormat.money(value.isFinite ? value : 0)
    }

    /// "17 oct. 2025", from "2025-10-17"
    static func dateText(_ iso: String) -> String {
        WeeklyDigestText.format(iso, pattern: "d MMM yyyy")
    }

    /// "1 sept. 2026 - 20 nov. 2026"
    static func periodText(_ usage: PaymentUsage) -> String {
        "\(dateText(usage.from)) - \(dateText(usage.to))"
    }

    /// "3 mois"
    static func monthsText(_ months: Int) -> String {
        "\(months) mois"
    }

    /// "sept.", from "2026-09"
    static func monthLabel(_ month: String) -> String {
        WeeklyDigestText.format(month + "-01", pattern: "MMM")
    }

    /// "septembre 2026 : 120,00 €, 3 tickets", what VoiceOver reads for a bar.
    static func monthAccessibility(_ month: PaymentUsageMonth) -> String {
        let name = WeeklyDigestText.format(month.month + "-01", pattern: "MMMM yyyy")

        if month.ticketCount == 0 {
            return "\(name) : aucun ticket"
        }

        return "\(name) : \(money(month.amount)), \(tickets(month.ticketCount))"
    }

    /// "45,8 %", or "-" when the share is not known.
    static func shareText(_ share: Double?) -> String {
        guard let share, share.isFinite else {
            return "-"
        }

        return WeeklyDigestText.percent(share) + "\u{00A0}%"
    }

    /// Percent of the total with one decimal, nil when nothing was spent.
    static func percent(_ amount: Double, of total: Double) -> Double? {
        guard total > 0, total.isFinite, amount.isFinite else {
            return nil
        }

        return (min(max(amount / total, 0), 1) * 1000).rounded() / 10
    }

    /// Length of a share bar, from 0 to 1.
    static func fraction(_ share: Double?) -> Double {
        guard let share, share.isFinite else {
            return 0
        }

        return min(max(share / 100, 0), 1)
    }

    /// Height of the bar of a month compared with the biggest month, from 0 to 1.
    static func barFraction(_ amount: Double, maximum: Double) -> Double {
        guard maximum > 0, maximum.isFinite, amount.isFinite else {
            return 0
        }

        return min(max(amount / maximum, 0), 1)
    }

    /// "25,00 €", or "-" when no ticket has an amount.
    static func averageText(_ average: Double?) -> String {
        guard let average, average.isFinite else {
            return "-"
        }

        return money(average)
    }

    /// The big line of the top card.
    static func headline(_ usage: PaymentUsage) -> String {
        usage.totalAmount > 0 ? money(usage.totalAmount) : "Aucune dépense"
    }

    /// "3 moyens de paiement utilisés"
    static func methodsUsed(_ count: Int) -> String {
        count < 2 ? "\(count) moyen de paiement utilisé" : "\(count) moyens de paiement utilisés"
    }

    /// The sentence under the big line.
    static func summary(_ usage: PaymentUsage) -> String {
        guard usage.hasTickets else {
            return "Aucun ticket enregistré sur cette période."
        }

        if usage.methodCount == 0 {
            return "\(tickets(usage.ticketCount)) sur \(monthsText(usage.months)), sans moyen de paiement renseigné."
        }

        return "\(tickets(usage.ticketCount)) sur \(monthsText(usage.months)), \(methodsUsed(usage.methodCount))."
    }

    /// The method with most spending in the period, or "-" when no ticket has one.
    static func mainMethodText(_ usage: PaymentUsage) -> String {
        usage.methods.first?.name ?? "-"
    }

    /// "3 tickets · panier moyen 40,00 €"
    static func rowDetail(_ method: PaymentUsageMethod) -> String {
        var text = tickets(method.ticketCount)

        if let average = method.average, average.isFinite, average > 0 {
            text += " · panier moyen \(money(average))"
        }

        return text
    }

    /// What VoiceOver reads for a row of the list.
    static func rowAccessibility(_ method: PaymentUsageMethod) -> String {
        var text = "\(method.name), \(rowDetail(method)), \(money(method.amount))"

        if method.share != nil {
            text += ", \(shareText(method.share)) des dépenses"
        }

        return text
    }

    /// The sentence of the top card of a method.
    static func methodSummary(share: Double?, count: Int) -> String {
        guard let share, share.isFinite else {
            return "\(tickets(count)) sur la période."
        }

        return "\(shareText(share)) de vos dépenses, en \(tickets(count))."
    }

    /// "aujourd'hui", "hier", "il y a 12 jours"
    static func sinceText(_ days: Int) -> String {
        if days <= 0 {
            return "aujourd'hui"
        }

        if days == 1 {
            return "hier"
        }

        return "il y a \(days) jours"
    }

    /// "Dernier paiement : il y a 2 jours (18 nov. 2026)."
    static func lastPaymentText(date: String, days: Int) -> String {
        "Dernier paiement : \(sinceText(days)) (\(dateText(date)))."
    }

    /// The icon of a payment method, from its key.
    static func icon(forKey key: String) -> String {
        if key.contains("espece") || key.contains("cash") {
            return "banknote.fill"
        }

        if key.contains("cheque") {
            return "doc.text.fill"
        }

        if key.contains("virement") || key.contains("prelevement") {
            return "building.columns.fill"
        }

        if key.contains("applepay") || key.contains("googlepay") {
            return "iphone"
        }

        if key == "autre" || key == "autres" {
            return "ellipsis.circle.fill"
        }

        return "creditcard.fill"
    }

    static let unspecifiedTitle = "Sans moyen de paiement"

    /// "5 tickets à compléter"
    static func unspecifiedDetail(count: Int) -> String {
        count < 2 ? "\(count) ticket à compléter" : "\(count) tickets à compléter"
    }

    /// Said when the list holds only the first methods.
    static func hiddenNote(hidden: Int, shown: Int) -> String {
        "Seuls les \(shown) moyens de paiement avec le plus de dépenses sont affichés, sur \(shown + hidden)."
    }

    /// Said when a method has more categories than the page lists.
    static func categoriesNote(shown: Int, total: Int) -> String {
        "Seules les \(shown) catégories avec le plus de dépenses sont affichées, sur \(total)."
    }

    /// Said when a method or the tickets without method have more tickets than the page lists.
    static func recentNote(shown: Int, total: Int) -> String {
        "Les \(shown) plus récents sur \(total) sont affichés."
    }

    static func listTitle(count: Int) -> String {
        count > 0 ? "Par moyen de paiement · \(count)" : "Par moyen de paiement"
    }

    static let monthNote = "Le mois en cours n'est pas terminé."

    static let noAmount = "Les tickets de ce moyen de paiement n'ont pas de montant : il n'y a rien à tracer."

    static let unspecifiedAdvice = "Ouvrez un ticket, choisissez son moyen de paiement puis enregistrez : il est alors compté dans la ligne correspondante."

    static let allSetMessage = "Tous les tickets de la période ont maintenant un moyen de paiement."

    static let emptyHint = "Dès que vos tickets sont enregistrés, vous retrouvez ici ce que vous payez par carte, en espèces ou par virement."

    static let noMethodHint = "Aucun ticket de cette période n'a de moyen de paiement. Ouvrez un ticket, choisissez-le (carte, espèces, virement…) puis enregistrez : il est alors compté ici."

    static let notFound = "Ce moyen de paiement n'apparaît plus dans la période choisie."

    static let method = "Un moyen de paiement écrit de plusieurs façons (majuscules, accents, ponctuation) est regroupé. Touchez une ligne pour voir les mois, les catégories et les derniers tickets. Seuls les montants positifs sont comptés."
}
