import Foundation

// MARK: - API response of GET /api/analytics/shops

/// What changed lately in a shop, from the last 90 days against the 90 days before: the server says "NEW"
/// (the first purchase is within the last 90 days), "FADING" (two visit days or more in the 90 days
/// before, none since), "UP" or "DOWN" (a quarter more or less, 10 euros at least) or "STEADY".
enum ShopStatus {
    case new
    case fading
    case up
    case down
    case steady

    init(code: String) {
        switch code {
        case "NEW":
            self = .new
        case "FADING":
            self = .fading
        case "UP":
            self = .up
        case "DOWN":
            self = .down
        default:
            self = .steady
        }
    }
}

/// One shop of the period.
struct ShopLine: Codable, Identifiable {
    /// The name without capitals, accents or extra spaces: the way the tickets are matched.
    let key: String
    /// The name the way the tickets write it most often.
    let name: String
    let spent: Double
    /// Nil when nothing was spent in the period.
    let sharePercent: Double?
    let ticketCount: Int
    /// Different days with a purchase.
    let visitDays: Int
    let averageBasket: Double
    /// "2026-01-10"
    let firstDate: String
    let lastDate: String
    let daysSinceLast: Int
    /// Days between two visits on average, nil with a single visit day.
    let averageGapDays: Double?
    /// The last 90 days, and the 90 days before them.
    let recentSpent: Double
    let previousSpent: Double
    /// Nil when nothing was spent in the 90 days before.
    let changePercent: Double?
    let status: String

    var id: String {
        key
    }

    var level: ShopStatus {
        ShopStatus(code: status)
    }
}

struct ShopsOverview: Codable {
    let months: Int
    /// "2025-11-01"
    let from: String
    let to: String
    /// All the tickets of the period, the ones without a readable shop included.
    let totalSpent: Double
    let ticketCount: Int
    let shopCount: Int
    let unknownSpent: Double
    let unknownTicketCount: Int
    /// The part of the three biggest shops, nil when nothing was spent.
    let topShopsSharePercent: Double?
    /// True when the account has tickets older than 90 days: without them nothing can be said to have changed.
    let hasBaseline: Bool
    let newCount: Int
    let fadingCount: Int
    let upCount: Int
    let downCount: Int
    /// Shops that are not in the list: it holds the 100 with the most spending.
    let hiddenCount: Int
    let shops: [ShopLine]

    var hasShops: Bool {
        !shops.isEmpty
    }

    var hasTickets: Bool {
        ticketCount > 0
    }

    /// What was spent in the shops that are named.
    var namedSpent: Double {
        max(totalSpent - unknownSpent, 0)
    }
}

// MARK: - API response of GET /api/analytics/shops/detail

struct ShopMonth: Codable, Identifiable {
    /// "2026-10"
    let month: String
    let spent: Double
    let ticketCount: Int

    var id: String {
        month
    }
}

struct ShopCategory: Codable, Identifiable {
    let name: String
    let spent: Double
    let ticketCount: Int
    let sharePercent: Double?

    var id: String {
        name
    }
}

struct ShopTicket: Codable {
    /// Empty when the ticket has no id.
    let id: String
    let date: String
    let category: String
    let amount: Double
}

struct ShopDetail: Codable {
    let months: Int
    let from: String
    let to: String
    let shop: ShopLine
    /// The average ticket of all the shops of the period.
    let overallAverageBasket: Double?
    /// How far the average ticket of the shop is from it, in percent, negative when it is smaller.
    let basketGapPercent: Double?
    /// Every month of the period, the oldest first.
    let monthly: [ShopMonth]
    let categoryTotal: Int
    /// The biggest first, 10 at most.
    let categories: [ShopCategory]
    /// Seven numbers, Monday to Sunday: the different days with a purchase for each day of the week.
    let weekdayVisitDays: [Int]
    let hiddenTicketCount: Int
    /// The latest 20, the newest first.
    let tickets: [ShopTicket]

    var hiddenCategoryCount: Int {
        max(categoryTotal - categories.count, 0)
    }
}

// MARK: - Which shops the list shows

enum ShopFilter: String, CaseIterable, Identifiable {
    case all
    case new
    case fading
    case up
    case down

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return "Toutes"
        case .new:
            return "Nouvelles"
        case .fading:
            return "Délaissées"
        case .up:
            return "En hausse"
        case .down:
            return "En baisse"
        }
    }

    /// The shops that match, in the order that makes sense for the filter.
    func apply(_ shops: [ShopLine]) -> [ShopLine] {
        switch self {
        case .all:
            return shops
        case .new:
            return shops.filter { $0.level == .new }
        case .fading:
            return shops
                .filter { $0.level == .fading }
                .sorted { $0.previousSpent > $1.previousSpent }
        case .up:
            return shops
                .filter { $0.level == .up }
                .sorted { ($0.changePercent ?? 0) > ($1.changePercent ?? 0) }
        case .down:
            return shops
                .filter { $0.level == .down }
                .sorted { ($0.changePercent ?? 0) < ($1.changePercent ?? 0) }
        }
    }
}

// MARK: - Text helpers

enum ShopsText {
    static func money(_ value: Double) -> String {
        AppFormat.money(value.isFinite ? value : 0)
    }

    /// "+20,00 €" for an increase, "-20,00 €" for a decrease.
    static func signedMoney(_ value: Double) -> String {
        let text = money(value)

        return value > 0 ? "+" + text : text
    }

    /// "+20 %" for an increase, "-2,5 %" for a decrease.
    static func signedPercent(_ value: Double?) -> String {
        guard let value, value.isFinite else {
            return "-"
        }

        let text = WeeklyDigestText.percent(value) + "\u{00A0}%"

        return value > 0 ? "+" + text : text
    }

    /// "20 %", for a share without a sign.
    static func percentText(_ value: Double?) -> String {
        guard let value, value.isFinite else {
            return "-"
        }

        return WeeklyDigestText.percent(value) + "\u{00A0}%"
    }

    /// "1 visite", "5 visites"
    static func visits(_ count: Int) -> String {
        count < 2 ? "\(count) visite" : "\(count) visites"
    }

    /// "1 ticket", "5 tickets"
    static func tickets(_ count: Int) -> String {
        count < 2 ? "\(count) ticket" : "\(count) tickets"
    }

    /// "1 enseigne", "5 enseignes"
    static func shops(_ count: Int) -> String {
        count < 2 ? "\(count) enseigne" : "\(count) enseignes"
    }

    /// "17 oct. 2025", from "2025-10-17"
    static func dateText(_ iso: String) -> String {
        WeeklyDigestText.format(iso, pattern: "d MMM yyyy")
    }

    /// "oct. 2025", from "2025-10"
    static func monthText(_ month: String) -> String {
        WeeklyDigestText.format(month + "-01", pattern: "MMM yyyy")
    }

    /// "3 mois", "1 an", "2 ans"
    static func periodTitle(_ months: Int) -> String {
        switch months {
        case 12:
            return "1 an"
        case 24:
            return "2 ans"
        default:
            return "\(months) mois"
        }
    }

    static func icon(_ level: ShopStatus) -> String {
        switch level {
        case .new:
            return "sparkles"
        case .fading:
            return "moon.zzz.fill"
        case .up:
            return "arrow.up.right.circle.fill"
        case .down:
            return "arrow.down.right.circle.fill"
        case .steady:
            return "storefront.fill"
        }
    }

    /// "aujourd'hui", "hier", "il y a 5 jours"
    static func sinceLast(_ days: Int) -> String {
        switch days {
        case ...0:
            return "aujourd'hui"
        case 1:
            return "hier"
        default:
            return "il y a \(days) jours"
        }
    }

    /// "1 jour entre deux visites en moyenne", "10 jours entre deux visites en moyenne", nil with a single visit day.
    static func rhythm(_ gap: Double?) -> String? {
        guard let gap, gap.isFinite, gap > 0 else {
            return nil
        }

        if gap <= 1 {
            return "1 jour entre deux visites en moyenne"
        }

        return WeeklyDigestText.percent(gap) + " jours entre deux visites en moyenne"
    }

    // MARK: The top card

    /// The big line of the top card: what was spent over the period.
    static func headline(_ overview: ShopsOverview) -> String {
        money(overview.totalSpent)
    }

    /// The sentence under the big line.
    static func summary(_ overview: ShopsOverview) -> String {
        if overview.shopCount == 0 {
            return "Aucune enseigne lisible sur vos tickets de la période."
        }

        var text = "dépensés dans \(shops(overview.shopCount))."

        if overview.unknownTicketCount > 0 {
            text = "dépensés, dont \(money(overview.namedSpent)) dans \(shops(overview.shopCount))."
        }

        if overview.shopCount > 3, let top = overview.topShopsSharePercent {
            text += " Les trois premières pèsent \(percentText(top)) de vos dépenses."
        }

        return text
    }

    /// The sentence about the tickets whose shop could not be read, nil when there are none.
    static func unknownNote(_ overview: ShopsOverview) -> String? {
        guard overview.unknownTicketCount > 0 else {
            return nil
        }

        if overview.unknownTicketCount < 2 {
            return "\(overview.unknownTicketCount) ticket sans enseigne lisible (\(money(overview.unknownSpent))) est compté dans le total mais pas classé."
        }

        return "\(overview.unknownTicketCount) tickets sans enseigne lisible (\(money(overview.unknownSpent))) sont comptés dans le total mais pas classés."
    }

    static let noBaselineNote = "Pas encore assez d'historique pour repérer les nouvelles enseignes : il faut des tickets enregistrés sur au moins 3 jours différents, datant de plus de 90 jours."

    static let fadingPeriodNote = "Sur moins de 7 mois, toutes les enseignes délaissées ne sont pas visibles : choisissez 12 mois ou plus pour les compter."

    /// The number of new shops, "-" when there is not enough history to say.
    static func newValue(_ overview: ShopsOverview) -> String {
        overview.hasBaseline ? "\(overview.newCount)" : "-"
    }

    /// The number of fading shops, "-" when the period is too short to see them all.
    static func fadingValue(_ overview: ShopsOverview) -> String {
        overview.months >= 7 ? "\(overview.fadingCount)" : "-"
    }

    /// What VoiceOver reads in place of the "-" of a figure that is not available.
    static func spoken(_ value: String) -> String {
        value == "-" ? "non disponible" : value
    }

    // MARK: The list

    /// "5 visites · panier moyen 33,33 €"
    static func basketLine(_ line: ShopLine) -> String {
        "\(visits(line.visitDays)) · panier moyen \(money(line.averageBasket))"
    }

    /// "Dernier passage hier"
    static func lastVisitLine(_ line: ShopLine) -> String {
        "Dernier passage " + sinceLast(line.daysSinceLast)
    }

    /// "Dernier passage hier · 10 jours entre deux visites en moyenne"
    static func rhythmLine(_ line: ShopLine) -> String {
        var text = lastVisitLine(line)

        if let rhythm = rhythm(line.averageGapDays) {
            text += " · " + rhythm
        }

        return text
    }

    /// What changed lately, nil for a steady shop.
    static func statusLine(_ line: ShopLine) -> String? {
        switch line.level {
        case .new:
            return "Nouvelle : premier achat il y a moins de 90 jours"
        case .fading:
            return "Plus d'achat depuis 90 jours (\(money(line.previousSpent)) les 90 jours d'avant)"
        case .up:
            return "En hausse de \(percentText(line.changePercent)) sur 90 jours (\(signedMoney(line.recentSpent - line.previousSpent)))"
        case .down:
            return "En baisse de \(percentText(abs(line.changePercent ?? 0))) sur 90 jours (\(signedMoney(line.recentSpent - line.previousSpent)))"
        case .steady:
            return nil
        }
    }

    /// What VoiceOver reads for a row of the list.
    static func rowAccessibility(_ line: ShopLine) -> String {
        var parts = [line.name, money(line.spent), basketLine(line), rhythmLine(line)]

        if let share = line.sharePercent {
            parts.insert(percentText(share) + " des dépenses", at: 2)
        }

        if let status = statusLine(line) {
            parts.append(status)
        }

        return parts.joined(separator: ", ")
    }

    static func hiddenNote(hidden: Int, shown: Int) -> String {
        "Seules les \(shown) enseignes où vous avez le plus dépensé sont listées, sur \(shown + hidden). Les filtres et la recherche ne portent que sur ces enseignes."
    }

    static func listTitle(count: Int) -> String {
        count > 0 ? "Enseignes · \(count)" : "Enseignes"
    }

    static let searchPrompt = "Rechercher une enseigne"

    static let noMatch = "Aucune enseigne ne correspond."

    static let emptyHint = "Vos enseignes apparaissent dès que des tickets enregistrés portent le nom du magasin. Scannez vos tickets et revenez ici : vous verrez où vous dépensez le plus, ce qui est nouveau et ce que vous avez délaissé."

    static let noTicketsHint = "Aucun ticket enregistré sur cette période."

    static let method = "Une enseigne est repérée par son nom sur les tickets enregistrés, sans tenir compte des majuscules, des accents ni de la ponctuation : « Carrefour Market » et « CARREFOUR-MARKET » sont la même enseigne. Les tickets sans nom de magasin lisible ne sont pas classés. Le panier moyen est la dépense divisée par le nombre de tickets. Ce qui change compare les 90 derniers jours aux 90 jours d'avant, quelle que soit la période choisie, sur 24 mois d'historique : une enseigne est nouvelle si son premier achat date de moins de 90 jours, délaissée si elle comptait au moins deux jours de visite avant et aucun depuis, en hausse ou en baisse à partir d'un quart d'écart et de 10 € au moins."

    // MARK: The detail

    /// The big line of the detail.
    static func detailHeadline(_ line: ShopLine) -> String {
        money(line.spent)
    }

    /// The sentence under the big line.
    static func detailSummary(_ detail: ShopDetail, months: Int) -> String {
        let line = detail.shop

        var text = "dépensés en " + periodTitle(months) + " : \(tickets(line.ticketCount)) en \(visits(line.visitDays)), du \(dateText(line.firstDate)) au \(dateText(line.lastDate))."

        if let share = line.sharePercent {
            text += " Cela fait \(percentText(share)) de vos dépenses."
        }

        return text
    }

    /// The sentence about the average ticket, nil when there is nothing to compare.
    static func basketText(_ detail: ShopDetail) -> String? {
        guard let overall = detail.overallAverageBasket, overall > 0, let gap = detail.basketGapPercent else {
            return nil
        }

        let own = money(detail.shop.averageBasket)
        let all = money(overall)

        if gap > 0 {
            return "Panier moyen de \(own) : \(percentText(gap)) de plus que la moyenne de vos enseignes (\(all))."
        }

        if gap < 0 {
            return "Panier moyen de \(own) : \(percentText(-gap)) de moins que la moyenne de vos enseignes (\(all))."
        }

        return "Panier moyen de \(own) : comme la moyenne de vos enseignes (\(all))."
    }

    static let recentTitle = "Ces 90 derniers jours"

    static let previousTitle = "Les 90 jours d'avant"

    static let evolutionTitle = "Évolution"

    static let evolutionNote = "Ces deux périodes de 90 jours ne dépendent pas de la période choisie en haut."

    static let monthsTitle = "Mois par mois"

    static let categoriesTitle = "Ce que vous y achetez"

    static let weekdaysTitle = "Jours de visite"

    static let ticketsTitle = "Derniers tickets"

    /// "Mois le plus fort : oct. 2026, 50,00 €."
    static func bestMonthText(_ monthly: [ShopMonth]) -> String {
        var strongest: ShopMonth? = nil

        for month in monthly where month.spent > (strongest?.spent ?? 0) {
            strongest = month
        }

        if let strongest {
            return "Mois le plus fort : \(monthText(strongest.month)), \(money(strongest.spent))."
        }

        var busiest: ShopMonth? = nil

        for month in monthly where month.ticketCount > (busiest?.ticketCount ?? 0) {
            busiest = month
        }

        if let busiest {
            return "Mois le plus actif : \(monthText(busiest.month)), \(tickets(busiest.ticketCount))."
        }

        return "Aucun achat sur la période."
    }

    static let weekdayLetters = ["L", "M", "M", "J", "V", "S", "D"]

    static let weekdayNames = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

    /// What VoiceOver reads for the days of the week.
    static func weekdaysAccessibility(_ days: [Int]) -> String {
        var parts: [String] = []

        for (index, name) in weekdayNames.enumerated() {
            let count = index < days.count ? days[index] : 0
            parts.append("\(name) \(count)")
        }

        return "Jours de visite : " + parts.joined(separator: ", ")
    }

    static func hiddenCategoriesNote(_ detail: ShopDetail) -> String {
        "Seules les \(detail.categories.count) catégories les plus importantes sont listées, sur \(detail.categoryTotal)."
    }

    static func hiddenTicketsNote(_ detail: ShopDetail) -> String {
        "Seuls les \(detail.tickets.count) derniers tickets sont listés, sur \(detail.tickets.count + detail.hiddenTicketCount)."
    }

    static let detailMethod = "Les chiffres portent sur les tickets enregistrés de la période choisie. Les 90 derniers jours et les 90 jours d'avant ne dépendent pas de cette période. Vos tickets ne sont jamais modifiés."
}
