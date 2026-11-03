import Foundation

// MARK: - Where the budget of an event stands, and where the event is in time

/// The server says "NO_BUDGET", "OK", "NEAR" (80 percent of the budget or more), or "OVER".
enum SpendingEventState {
    case noBudget
    case ok
    case near
    case over

    init(code: String) {
        switch code {
        case "OK":
            self = .ok
        case "NEAR":
            self = .near
        case "OVER":
            self = .over
        default:
            self = .noBudget
        }
    }
}

/// The server says "UPCOMING", "ONGOING", "DONE" or "UNDATED" (an event without dates).
enum SpendingEventTiming {
    case upcoming
    case ongoing
    case done
    case undated

    init(code: String) {
        switch code {
        case "UPCOMING":
            self = .upcoming
        case "ONGOING":
            self = .ongoing
        case "DONE":
            self = .done
        default:
            self = .undated
        }
    }
}

// MARK: - API responses of /api/events

/// An event of the person and where its spending stands. Amounts are in euros.
struct SpendingEventLine: Codable, Identifiable {
    let id: Int
    let name: String
    /// The name of an SF Symbol, one of SpendingEventIcons.all.
    let icon: String
    let budget: Double?
    /// "2026-10-10"
    let startDate: String?
    let endDate: String?
    let archived: Bool
    /// What the saved tickets of the event add up to.
    let spent: Double
    let ticketCount: Int
    /// Different days with a purchase.
    let purchaseDays: Int
    let firstDate: String?
    let lastDate: String?
    /// The budget minus the spending, negative when the budget is passed.
    let remaining: Double?
    /// The spending in percent of the budget, with one decimal.
    let usedPercent: Double?
    let state: String
    let timing: String
    /// The length of the event, when it has a start and an end.
    let dayCount: Int?
    /// Days since the start, up to today or to the end.
    let elapsedDays: Int?
    /// Days from today (or from the start) to the end, today included.
    let daysLeft: Int?
    /// What is left of the budget divided by the days left.
    let dailyAllowance: Double?
    let averagePerDay: Double?
    /// The total at the pace of the days gone by, only for an event in progress of known length.
    let projected: Double?
    let projectedOver: Bool

    var level: SpendingEventState {
        SpendingEventState(code: state)
    }

    var phase: SpendingEventTiming {
        SpendingEventTiming(code: timing)
    }

    var hasBudget: Bool {
        budget != nil
    }

    var hasDates: Bool {
        startDate != nil
    }
}

struct SpendingEventsOverview: Codable {
    /// Events that are not archived.
    let activeCount: Int
    let archivedCount: Int
    let ongoingCount: Int
    let overBudgetCount: Int
    let nearBudgetCount: Int
    /// The spending of the events that are not archived.
    let totalSpent: Double
    let events: [SpendingEventLine]

    var activeEvents: [SpendingEventLine] {
        events.filter { !$0.archived }
    }

    var archivedEvents: [SpendingEventLine] {
        events.filter { $0.archived }
    }

    var isEmpty: Bool {
        events.isEmpty
    }
}

struct SpendingEventCategory: Codable, Identifiable {
    let name: String
    let spent: Double
    let ticketCount: Int
    /// Nil when nothing was spent.
    let sharePercent: Double?

    var id: String {
        name
    }
}

struct SpendingEventMerchant: Codable, Identifiable {
    let name: String
    let spent: Double
    let ticketCount: Int

    var id: String {
        name
    }
}

struct SpendingEventDay: Codable, Identifiable {
    /// "2026-10-10"
    let date: String
    let spent: Double
    let ticketCount: Int

    var id: String {
        date
    }
}

struct SpendingEventTicket: Codable, Identifiable {
    let id: String
    let merchant: String
    let category: String
    let amount: Double
    let date: String
}

/// GET /api/events/{id}
struct SpendingEventDetail: Codable {
    let event: SpendingEventLine
    let categoryTotal: Int
    /// 30 at most, the biggest first.
    let categories: [SpendingEventCategory]
    let merchantTotal: Int
    /// The 5 where most was spent.
    let merchants: [SpendingEventMerchant]
    let hiddenDayCount: Int
    /// The latest 60 days with spending, the oldest first.
    let days: [SpendingEventDay]
    let hiddenTicketCount: Int
    /// The latest 100 tickets, the newest first.
    let tickets: [SpendingEventTicket]

    var hiddenCategoryCount: Int {
        max(categoryTotal - categories.count, 0)
    }

    var hiddenMerchantCount: Int {
        max(merchantTotal - merchants.count, 0)
    }
}

struct SpendingEventCandidate: Codable, Identifiable {
    let id: String
    let merchant: String
    let category: String
    let amount: Double
    let date: String
    /// True when the date is within the dates of the event.
    let inWindow: Bool
}

/// GET /api/events/{id}/candidates: the saved tickets that are in no event yet.
struct SpendingEventCandidates: Codable {
    let query: String
    let windowed: Bool
    let from: String
    let to: String
    let hiddenCount: Int
    let tickets: [SpendingEventCandidate]
}

// MARK: - What is sent to the server

struct SpendingEventBody: Encodable {
    let name: String
    let icon: String
    let budget: Double?
    let startDate: String?
    let endDate: String?
    /// Only read when an event is changed: nil keeps what the event has.
    let archived: Bool?
}

struct SpendingEventTicketsBody: Encodable {
    let ticketIds: [String]
}

struct SpendingEventTicketRemoveBody: Encodable {
    let ticketId: String
}

struct SpendingEventNoBody: Encodable {
}

// MARK: - Icons

struct SpendingEventIcon: Identifiable {
    let symbol: String
    let title: String

    var id: String {
        symbol
    }
}

enum SpendingEventIcons {
    static let defaultSymbol = "calendar"

    /// The icons the server accepts.
    static let all: [SpendingEventIcon] = [
        SpendingEventIcon(symbol: "calendar", title: "Événement"),
        SpendingEventIcon(symbol: "airplane", title: "Voyage"),
        SpendingEventIcon(symbol: "house.fill", title: "Maison"),
        SpendingEventIcon(symbol: "gift.fill", title: "Cadeau"),
        SpendingEventIcon(symbol: "heart.fill", title: "Couple"),
        SpendingEventIcon(symbol: "car.fill", title: "Voiture"),
        SpendingEventIcon(symbol: "graduationcap.fill", title: "Études"),
        SpendingEventIcon(symbol: "cart.fill", title: "Courses"),
        SpendingEventIcon(symbol: "star.fill", title: "Fête"),
        SpendingEventIcon(symbol: "briefcase.fill", title: "Travail"),
        SpendingEventIcon(symbol: "wrench.and.screwdriver.fill", title: "Travaux"),
        SpendingEventIcon(symbol: "fork.knife", title: "Repas"),
        SpendingEventIcon(symbol: "camera.fill", title: "Photos"),
        SpendingEventIcon(symbol: "sportscourt.fill", title: "Sport")
    ]

    /// An icon that is not one of the list (an older version of the server) shows as the default one.
    static func symbol(_ name: String) -> String {
        all.contains { $0.symbol == name } ? name : defaultSymbol
    }
}

// MARK: - The dates the server reads and writes

enum SpendingEventDates {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// "2026-10-10", the day of the date in the time zone of the phone.
    static func text(_ date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(_ text: String?) -> Date? {
        guard let text else {
            return nil
        }

        return formatter.date(from: text)
    }
}

// MARK: - Text helpers

enum SpendingEventsText {
    static func money(_ value: Double) -> String {
        AppFormat.money(value.isFinite ? value : 0)
    }

    /// "+0,20 €" for an increase, "-0,20 €" for a decrease.
    static func signedMoney(_ value: Double) -> String {
        let text = money(value)

        return value > 0 ? "+" + text : text
    }

    /// "20 %", "2,5 %"
    static func percentText(_ value: Double?) -> String {
        guard let value, value.isFinite else {
            return "-"
        }

        return WeeklyDigestText.percent(value) + "\u{00A0}%"
    }

    /// "17 oct. 2025", from "2025-10-17"
    static func dateText(_ iso: String) -> String {
        WeeklyDigestText.format(iso, pattern: "d MMM yyyy")
    }

    /// "1 jour", "5 jours"
    static func days(_ count: Int) -> String {
        count < 2 ? "\(count) jour" : "\(count) jours"
    }

    /// "1 ticket", "5 tickets"
    static func tickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket" : "\(count) tickets"
    }

    /// "10 oct. 2026 – 20 oct. 2026", "Depuis le 10 oct. 2026", "Sans dates"
    static func period(_ line: SpendingEventLine) -> String {
        guard let start = line.startDate else {
            return "Sans dates"
        }

        guard let end = line.endDate else {
            return "Depuis le " + dateText(start)
        }

        if start == end {
            return dateText(start)
        }

        return dateText(start) + " – " + dateText(end)
    }

    /// Where the event is in time: "En cours · 5 jours restants", "À venir", "Terminé"...
    static func timingTitle(_ line: SpendingEventLine) -> String {
        switch line.phase {
        case .ongoing:
            if let left = line.daysLeft {
                return left == 1 ? "En cours · dernier jour" : "En cours · \(left) jours restants"
            }

            if let elapsed = line.elapsedDays {
                return "En cours depuis \(days(elapsed))"
            }

            return "En cours"
        case .upcoming:
            if let length = line.dayCount {
                return "À venir · \(days(length))"
            }

            return "À venir"
        case .done:
            return "Terminé"
        case .undated:
            return "Sans dates"
        }
    }

    /// The label of the budget state, nil without budget.
    static func stateTitle(_ line: SpendingEventLine) -> String? {
        switch line.level {
        case .noBudget:
            return nil
        case .ok:
            return "Dans le budget"
        case .near:
            return "Budget presque atteint"
        case .over:
            return "Budget dépassé de " + money(abs(line.remaining ?? 0))
        }
    }

    /// "120,00 € sur 500,00 €"
    static func budgetLine(_ line: SpendingEventLine) -> String {
        guard let budget = line.budget else {
            return money(line.spent)
        }

        return money(line.spent) + " sur " + money(budget)
    }

    /// What VoiceOver reads for an event of the list.
    static func rowAccessibility(_ line: SpendingEventLine) -> String {
        var parts = [line.name, period(line), timingTitle(line), budgetLine(line), tickets(line.ticketCount)]

        if let state = stateTitle(line) {
            parts.append(state)
        }

        if line.archived {
            parts.append("Archivé")
        }

        return parts.joined(separator: ", ")
    }

    // MARK: The top card of the list

    static func headline(_ overview: SpendingEventsOverview) -> String {
        money(overview.totalSpent)
    }

    static func summary(_ overview: SpendingEventsOverview) -> String {
        if overview.activeCount == 0 {
            return "Aucun événement en cours de suivi."
        }

        let count = overview.activeCount < 2 ? "\(overview.activeCount) événement" : "\(overview.activeCount) événements"
        var text = "dépensés sur \(count)"

        if overview.ongoingCount > 0 {
            text += overview.ongoingCount < 2 ? ", 1 en cours" : ", \(overview.ongoingCount) en cours"
        }

        return text + "."
    }

    static func alertText(_ overview: SpendingEventsOverview) -> String? {
        if overview.overBudgetCount > 0 {
            return overview.overBudgetCount < 2
                ? "1 événement a dépassé son budget."
                : "\(overview.overBudgetCount) événements ont dépassé leur budget."
        }

        if overview.nearBudgetCount > 0 {
            return overview.nearBudgetCount < 2
                ? "1 événement a presque atteint son budget."
                : "\(overview.nearBudgetCount) événements ont presque atteint leur budget."
        }

        return nil
    }

    static let emptyTitle = "Aucun événement"

    static let emptyHint = "Un événement regroupe des tickets : un voyage, des travaux, un mariage, une fête... Donnez-lui un budget et des dates si vous voulez, ajoutez-y vos tickets, et vous verrez ce que l'événement vous coûte, par catégorie, par commerce et par jour."

    static let archivedTitle = "Archivés"

    static let method = "Seuls les tickets enregistrés comptent. Un ticket fait partie d'un seul événement à la fois ; le retirer d'un événement ne le supprime pas. Le budget est presque atteint à partir de 80 % ; « À ce rythme » prolonge la dépense des jours écoulés sur toute la durée de l'événement, quand il a une date de fin et qu'au moins 3 jours (et un quart de sa durée) sont passés."

    // MARK: The detail

    static func heroSubtitle(_ line: SpendingEventLine) -> String {
        guard let budget = line.budget else {
            return "\(tickets(line.ticketCount)) · \(days(line.purchaseDays)) d'achats"
        }

        return "sur un budget de \(money(budget)) (\(percentText(line.usedPercent)))"
    }

    static func remainingText(_ line: SpendingEventLine) -> String? {
        guard let remaining = line.remaining else {
            return nil
        }

        if remaining < 0 {
            return "Dépassé de " + money(-remaining)
        }

        return "Il reste " + money(remaining)
    }

    static func allowanceText(_ line: SpendingEventLine) -> String? {
        guard let allowance = line.dailyAllowance, let left = line.daysLeft else {
            return nil
        }

        return "Soit \(money(allowance)) par jour pendant \(days(left))."
    }

    static func paceText(_ line: SpendingEventLine) -> String? {
        guard let projected = line.projected else {
            return nil
        }

        var text = "À ce rythme : \(money(projected)) au total"

        if line.projectedOver, let budget = line.budget {
            text += ", \(money(projected - budget)) de plus que le budget"
        }

        return text + "."
    }

    static func averageText(_ line: SpendingEventLine) -> String? {
        guard let average = line.averagePerDay else {
            return nil
        }

        return "Moyenne : \(money(average)) par jour"
    }

    static let categoriesTitle = "Par catégorie"

    static let merchantsTitle = "Où vous avez dépensé"

    static let daysTitle = "Par jour"

    static let ticketsTitle = "Tickets"

    static func hiddenCategoriesNote(_ detail: SpendingEventDetail) -> String {
        "Seules les \(detail.categories.count) catégories les plus importantes sont listées, sur \(detail.categoryTotal)."
    }

    static func hiddenMerchantsNote(_ detail: SpendingEventDetail) -> String {
        "Seuls les \(detail.merchants.count) commerces où vous avez le plus dépensé sont listés, sur \(detail.merchantTotal)."
    }

    static func hiddenDaysNote(_ detail: SpendingEventDetail) -> String {
        "Seuls les \(detail.days.count) derniers jours avec des achats sont affichés, sur \(detail.days.count + detail.hiddenDayCount)."
    }

    static func hiddenTicketsNote(_ detail: SpendingEventDetail) -> String {
        "Seuls les \(detail.tickets.count) derniers tickets sont listés, sur \(detail.tickets.count + detail.hiddenTicketCount)."
    }

    static let noTicketsTitle = "Aucun ticket"

    static let noTicketsHint = "Ajoutez les tickets de cet événement : ils sont choisis parmi vos tickets enregistrés qui ne font partie d'aucun autre événement."

    // MARK: The choice of tickets

    static let pickerTitle = "Ajouter des tickets"

    static let pickerSearchPrompt = "Rechercher un commerce"

    static let pickerEmpty = "Aucun ticket à ajouter."

    static let pickerEmptyHint = "Seuls les tickets enregistrés qui ne sont dans aucun événement sont proposés. Cherchez un commerce pour remonter plus loin dans le temps."

    static func pickerNote(_ candidates: SpendingEventCandidates) -> String {
        if candidates.query.isEmpty {
            return candidates.windowed
                ? "Les tickets des dates de l'événement sont en premier, puis les plus récents (180 jours)."
                : "Les tickets des 180 derniers jours. Cherchez un commerce pour remonter plus loin."
        }

        return "Les tickets de tous les jours dont le commerce contient « \(candidates.query) »."
    }

    static func pickerHidden(_ count: Int) -> String {
        "Encore \(count) tickets : précisez la recherche pour les voir."
    }

    static func addButton(_ count: Int) -> String {
        count == 0 ? "Choisissez des tickets" : (count < 2 ? "Ajouter 1 ticket" : "Ajouter \(count) tickets")
    }

    static let maxPerCall = 50

    // MARK: The form

    static let nameLimit = 60

    static let maxEvents = 30

    static let maxBudget = 10_000_000.0

    static let maxSpanDays = 3660

    /// What is wrong with the form, nil when the server can take it. The server checks again.
    static func problem(name: String, budgetText: String, start: Date?, end: Date?) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "Donnez un nom à l'événement."
        }

        if trimmed.unicodeScalars.count > nameLimit {
            return "Le nom est trop long : \(nameLimit) caractères au maximum."
        }

        let budgetInput = budgetText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !budgetInput.isEmpty {
            guard let budget = parseBudget(budgetInput) else {
                return "Le budget n'est pas un nombre."
            }

            if budget <= 0 {
                return "Le budget doit être supérieur à zéro."
            }

            if budget > maxBudget {
                return "Le budget est trop élevé : 10 millions au maximum."
            }
        }

        guard let start else {
            return nil
        }

        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: start)

        if year < 2000 || year > 2100 {
            return "La date de début doit être entre 2000 et 2100."
        }

        if let end {
            if calendar.component(.year, from: end) > 2100 {
                return "La date de fin doit être entre 2000 et 2100."
            }

            let first = calendar.startOfDay(for: start)
            let last = calendar.startOfDay(for: end)

            if last < first {
                return "La date de fin précède la date de début."
            }

            let span = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1

            if span > maxSpanDays {
                return "L'événement est trop long : 3 660 jours au maximum."
            }
        }

        return nil
    }

    /// The budget written in the form, nil when empty. A comma is read as a decimal point.
    static func parseBudget(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else {
            return nil
        }

        return value
    }

    /// The text of the form for a budget, "250" or "250,5".
    static func budgetFieldText(_ value: Double?) -> String {
        guard let value else {
            return ""
        }

        if value == value.rounded() {
            return String(Int(value))
        }

        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }
}
