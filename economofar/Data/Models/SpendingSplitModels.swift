import Foundation

// MARK: - API response of GET /api/analytics/spending-split

/// Where a category counts in the split of the spending.
enum SpendingSplitGroup: String {
    case need = "NEED"
    case want = "WANT"
    case savings = "SAVINGS"
    case unsorted = "UNSORTED"
    case excluded = "EXCLUDED"

    init(code: String) {
        self = SpendingSplitGroup(rawValue: code) ?? .unsorted
    }
}

/// Where a slice stands against its target: "OK", "OVER" (a need or a want above its share of the
/// income), "UNDER" (savings below their share) or "NONE" (no target, or no income to compare with), which is read as neutral.
enum SpendingSplitLevel {
    case ok
    case over
    case under
    case neutral

    init(status: String) {
        switch status {
        case "OK":
            self = .ok
        case "OVER":
            self = .over
        case "UNDER":
            self = .under
        default:
            self = .neutral
        }
    }
}

/// One slice of the split: the needs, the wants, the savings or what is not classified yet.
struct SpendingSplitSlice: Codable, Identifiable {
    /// "NEED", "WANT", "SAVINGS" or "UNSORTED"
    let code: String
    /// The share of the income the 50/30/20 rule gives to the slice, nil for what is not classified.
    let targetPercent: Double?
    /// What was spent in the slice. For the savings: what is left of the income, negative when more was
    /// spent than earned. Nil for the savings when the month has no income.
    let amount: Double?
    /// The amount in percent of the income, nil without income.
    let percentOfIncome: Double?
    let targetAmount: Double?
    /// Amount minus the target amount, nil without income and for what is not classified.
    let difference: Double?
    let status: String
    /// The part of the slice in the spending that counts, nil when nothing was spent.
    let share: Double?
    let categoryCount: Int

    var id: String {
        code
    }

    var group: SpendingSplitGroup {
        SpendingSplitGroup(code: code)
    }

    var level: SpendingSplitLevel {
        SpendingSplitLevel(status: status)
    }
}

/// A category that has tickets in the month.
struct SpendingSplitCategory: Codable, Identifiable {
    /// The name without the spaces around it and without capitals; empty for the tickets without category.
    let key: String
    let name: String
    /// Where the category counts now: "NEED", "WANT", "UNSORTED" or "EXCLUDED".
    let group: String
    /// Where the app proposes to put it: "NEED", "WANT" or "UNSORTED".
    let defaultGroup: String
    /// A choice of the person decides the group.
    let custom: Bool
    /// A group can be chosen for it; not for the tickets without category.
    let editable: Bool
    let ticketCount: Int
    let amount: Double

    var id: String {
        key
    }

    var currentGroup: SpendingSplitGroup {
        SpendingSplitGroup(code: group)
    }

    var proposedGroup: SpendingSplitGroup {
        SpendingSplitGroup(code: defaultGroup)
    }
}

struct SpendingSplitOverview: Codable {
    /// "2026-10"
    let month: String
    let currentMonth: Bool
    /// The months next to this one that can be asked for, nil at the end of the range.
    let previousMonth: String?
    let nextMonth: String?
    /// All the tickets of the month.
    let ticketCount: Int
    /// The income declared for the month.
    let income: Double
    let hasIncome: Bool
    /// The spending that counts: needs, wants and what is not classified.
    let spent: Double
    /// The spending of the categories that were left out of the calculation.
    let excluded: Double
    let excludedCategoryCount: Int
    /// The needs, the wants, the savings and what is not classified, in this order.
    let groups: [SpendingSplitSlice]
    /// All the categories with tickets; categories holds the first 60.
    let categoryCount: Int
    let categories: [SpendingSplitCategory]

    func slice(_ group: SpendingSplitGroup) -> SpendingSplitSlice? {
        groups.first { $0.code == group.rawValue }
    }

    var hasTickets: Bool {
        ticketCount > 0
    }

    var hiddenCategoryCount: Int {
        max(categoryCount - categories.count, 0)
    }

    var unsortedCount: Int {
        slice(.unsorted)?.categoryCount ?? 0
    }

    /// The unsorted categories the person can classify: the tickets without category, and the names that
    /// are too long, have no menu.
    var classifiableUnsortedCount: Int {
        let locked = categories.filter { $0.currentGroup == .unsorted && !$0.editable }.count

        return max(unsortedCount - locked, 0)
    }

    var hasUnsortedSpending: Bool {
        classifiableUnsortedCount > 0
    }

    /// What is left of the income, nil without income.
    var saved: Double? {
        slice(.savings)?.amount
    }
}

/// Body of POST /api/analytics/spending-split/rules
struct SpendingSplitRuleBody: Encodable {
    let category: String
    /// "NEED", "WANT" or "EXCLUDED", or "DEFAULT" to go back to the proposed group.
    let group: String
}

// MARK: - Text helpers

enum SpendingSplitText {
    static func money(_ value: Double) -> String {
        AppFormat.money(value.isFinite ? value : 0)
    }

    /// "1 ticket", "5 tickets"
    static func tickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket" : "\(count) tickets"
    }

    /// "1 catégorie", "5 catégories"
    static func categories(_ count: Int) -> String {
        count < 2 ? "\(count) catégorie" : "\(count) catégories"
    }

    /// "Octobre 2026", from "2026-10"
    static func monthTitle(_ month: String) -> String {
        let text = WeeklyDigestText.format(month + "-01", pattern: "MMMM yyyy")

        guard let first = text.first else {
            return text
        }

        return first.uppercased() + text.dropFirst()
    }

    /// "35 %", or "-" when it is not known.
    static func percentText(_ value: Double?) -> String {
        guard let value, value.isFinite else {
            return "-"
        }

        return WeeklyDigestText.percent(value) + "\u{00A0}%"
    }

    /// Length of a progress bar, from 0 to 1.
    static func fraction(amount: Double?, target: Double?) -> Double {
        guard let amount, let target, target > 0, target.isFinite, amount.isFinite else {
            return 0
        }

        return min(max(amount / target, 0), 1)
    }

    static func title(_ group: SpendingSplitGroup) -> String {
        switch group {
        case .need:
            return "Besoins"
        case .want:
            return "Envies"
        case .savings:
            return "Épargne"
        case .unsorted:
            return "À classer"
        case .excluded:
            return "Hors calcul"
        }
    }

    /// The name of a group in a choice: "Besoin", "Envie".
    static func choiceTitle(_ group: SpendingSplitGroup) -> String {
        switch group {
        case .need:
            return "Besoin"
        case .want:
            return "Envie"
        case .savings:
            return "Épargne"
        case .unsorted:
            return "À classer"
        case .excluded:
            return "Hors calcul"
        }
    }

    static func icon(_ group: SpendingSplitGroup) -> String {
        switch group {
        case .need:
            return "house.fill"
        case .want:
            return "gift.fill"
        case .savings:
            return "eurosign.circle.fill"
        case .unsorted:
            return "questionmark.circle.fill"
        case .excluded:
            return "minus.circle.fill"
        }
    }

    /// The big line of the top card.
    static func headline(_ overview: SpendingSplitOverview) -> String {
        guard overview.hasIncome, let saved = overview.saved else {
            return overview.spent > 0 ? "Dépenses : " + money(overview.spent) : "Aucune dépense"
        }

        if saved < 0 {
            return "Déficit : " + money(-saved)
        }

        return "Épargne : " + money(saved)
    }

    /// The sentence under the big line.
    static func summary(_ overview: SpendingSplitOverview) -> String {
        guard overview.hasIncome else {
            return noIncomeHint
        }

        return "Revenus \(money(overview.income)) moins dépenses \(money(overview.spent))."
    }

    static func savedShare(_ overview: SpendingSplitOverview) -> String? {
        guard overview.hasIncome, let slice = overview.slice(.savings), let saved = slice.amount, saved >= 0 else {
            return nil
        }

        return "\(percentText(slice.percentOfIncome)) de vos revenus mis de côté"
    }

    /// What a row says about its place in the income and its target.
    static func detail(_ slice: SpendingSplitSlice, hasIncome: Bool) -> String {
        guard let target = slice.targetPercent else {
            if hasIncome {
                return "\(percentText(slice.percentOfIncome)) de vos revenus · \(categories(slice.categoryCount))"
            }

            return categories(slice.categoryCount)
        }

        let targetText = percentText(target)

        guard hasIncome else {
            if slice.group == .savings {
                return "Objectif : \(targetText) de vos revenus au moins"
            }

            if slice.share == nil {
                return "Objectif : \(targetText) de vos revenus au plus"
            }

            return "\(percentText(slice.share)) des dépenses · objectif \(targetText) des revenus au plus"
        }

        if slice.group == .savings {
            return "\(percentText(slice.percentOfIncome)) de vos revenus · objectif \(targetText) au moins"
        }

        return "\(percentText(slice.percentOfIncome)) de vos revenus · objectif \(targetText) au plus"
    }

    /// Where a row stands: what is left before the limit, what is over, what is missing.
    static func standing(_ slice: SpendingSplitSlice) -> String? {
        guard let difference = slice.difference else {
            return nil
        }

        if slice.group == .savings {
            if let amount = slice.amount, amount < 0 {
                return "Vous dépensez \(money(-amount)) de plus que vous ne gagnez"
            }

            switch slice.level {
            case .under:
                return "Il manque \(money(-difference)) pour atteindre l'objectif"
            default:
                return difference == 0 ? "Objectif atteint" : "Objectif dépassé de \(money(difference))"
            }
        }

        switch slice.level {
        case .over:
            return "Dépassé de \(money(difference))"
        default:
            return difference == 0 ? "Limite atteinte" : "Il reste \(money(-difference)) dans cette limite"
        }
    }

    /// What VoiceOver reads for a row of the slices.
    static func rowAccessibility(_ slice: SpendingSplitSlice, hasIncome: Bool) -> String {
        let amount = slice.amount.map { money($0) } ?? "inconnu"
        var parts = [title(slice.group), amount, detail(slice, hasIncome: hasIncome)]

        if let standing = standing(slice) {
            parts.append(standing)
        }

        return parts.joined(separator: ", ")
    }

    /// Under a category: its tickets and where it counts.
    static func categoryDetail(_ category: SpendingSplitCategory) -> String {
        let group = category.currentGroup

        if category.key.isEmpty {
            return "\(tickets(category.ticketCount)) · sans catégorie, donc à classer"
        }

        if !category.editable {
            return "\(tickets(category.ticketCount)) · nom trop long pour être classé"
        }

        if category.custom {
            return "\(tickets(category.ticketCount)) · \(choiceTitle(group)), choisi par vous"
        }

        if group == .unsorted {
            return "\(tickets(category.ticketCount)) · à classer"
        }

        return "\(tickets(category.ticketCount)) · \(choiceTitle(group)), classement proposé"
    }

    static func categoryAccessibility(_ category: SpendingSplitCategory) -> String {
        "\(category.name), \(money(category.amount)), \(categoryDetail(category))"
    }

    static let categoriesTitle = "Catégories du mois"

    static func hiddenNote(hidden: Int, shown: Int) -> String {
        "Seules les \(shown) premières catégories sont listées, sur \(shown + hidden). Les trois parts comptent toutes les catégories."
    }

    static func excludedLine(amount: Double, count: Int) -> String {
        "Hors calcul : \(money(amount)) (\(categories(count)))"
    }

    static func unsortedHint(count: Int) -> String {
        count < 2
            ? "1 catégorie n'est pas classée : choisissez ci-dessous si c'est un besoin ou une envie."
            : "\(count) catégories ne sont pas classées : choisissez ci-dessous si ce sont des besoins ou des envies."
    }

    static let noIncomeHint = "Aucun revenu pour ce mois : déclarez vos revenus dans Réglages, section Revenus (« Revenus et bilan »), pour comparer vos dépenses à la règle 50/30/20."

    static let currentMonthHint = "Mois en cours : vos revenus du mois sont comptés en entier, mais seules les dépenses déjà enregistrées le sont. L'épargne affichée peut encore baisser."

    static let emptyMonthHint = "Aucun ticket enregistré ce mois-ci. Dès qu'il y en a, vous voyez ici comment ils se répartissent."

    static let chooseHint = "Touchez les trois points d'une catégorie pour en faire un besoin, une envie, ou pour la laisser hors calcul (des dépenses professionnelles remboursées, par exemple)."

    static let noCategoryHint = "Ouvrez ces tickets et donnez-leur une catégorie pour pouvoir les classer."

    static let longNameHint = "Raccourcissez le nom de cette catégorie sur ses tickets pour pouvoir la classer."

    static let savedButNotRefreshed = "Votre choix est enregistré, mais les chiffres n'ont pas pu être actualisés. Tirez l'écran vers le bas pour les actualiser."

    static let method = "La règle 50/30/20 propose de consacrer environ 50 % de vos revenus aux besoins, 30 % aux envies et 20 % à l'épargne. Les revenus sont ceux que vous avez déclarés pour le mois, les dépenses celles de vos tickets enregistrés, comptées comme sur l'écran « Revenus et bilan » : un remboursement vient en déduction. L'épargne est ce qui reste des revenus une fois les dépenses retirées. Alimentation, Transport, Santé et Maison sont proposés comme besoins ; Shopping, Loisirs et Restaurant comme envies ; les autres catégories restent à classer, jamais devinées."
}
