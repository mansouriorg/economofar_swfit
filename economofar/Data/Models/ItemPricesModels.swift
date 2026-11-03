import Foundation

// MARK: - API response of GET /api/analytics/item-prices

/// Where the price of an article is going: the server says "RISING" (up 2 percent or more since the
/// first day it was bought), "FALLING" (down 2 percent or more), "STEADY", or "NONE" when the article
/// was bought on a single day and there is nothing to compare.
enum ItemPriceTrend {
    case rising
    case falling
    case steady
    case compareOnly

    init(code: String) {
        switch code {
        case "RISING":
            self = .rising
        case "FALLING":
            self = .falling
        case "STEADY":
            self = .steady
        default:
            self = .compareOnly
        }
    }
}

/// One article whose price is followed. The prices are unit prices.
struct ItemPriceLine: Codable, Identifiable {
    /// The name without capitals, accents or extra spaces: the way the tickets are matched.
    let key: String
    /// The name the way the tickets write it most often.
    let name: String
    /// Lines of tickets with a price.
    let purchaseCount: Int
    /// Different days it was bought.
    let dayCount: Int
    let quantity: Int
    let spent: Double
    let averagePrice: Double
    let lowestPrice: Double
    let highestPrice: Double
    /// "2026-01-10"
    let firstDate: String
    let lastDate: String
    /// Nil when the article was bought on a single day.
    let firstPrice: Double?
    let lastPrice: Double?
    let change: Double?
    /// The change in percent of the first price, with one decimal.
    let changePercent: Double?
    let trend: String
    /// Named shops where it was bought.
    let merchantCount: Int
    /// Nil when it was bought in fewer than two shops, or at the same price in all of them.
    let cheapestMerchant: String?
    let cheapestPrice: Double?
    let gapPercent: Double?
    /// What the shops above the cheapest average price cost more, nil with fewer than two shops.
    let potentialSaving: Double?

    var id: String {
        key
    }

    var level: ItemPriceTrend {
        ItemPriceTrend(code: trend)
    }

    var hasTrend: Bool {
        changePercent != nil
    }

    var hasSaving: Bool {
        (potentialSaving ?? 0) > 0
    }
}

/// A shop where an article was bought.
struct ItemPriceShop: Codable, Identifiable {
    let name: String
    let purchaseCount: Int
    let quantity: Int
    /// The unit price paid there over the period.
    let averagePrice: Double
    let lastPrice: Double
    let lastDate: String
    /// True for the shops with the lowest average price when another shop is dearer.
    let cheapest: Bool

    var id: String {
        name
    }
}

/// The unit price of an article on one day.
struct ItemPricePoint: Codable, Identifiable {
    let date: String
    let price: Double
    let quantity: Int
    /// The shop when exactly one named shop was used that day.
    let merchant: String?
    /// The number of named shops that day.
    let merchantCount: Int

    var id: String {
        date
    }
}

struct ItemPricesOverview: Codable {
    let months: Int
    /// "2025-11-01"
    let from: String
    let to: String
    /// Tickets with at least one priced article.
    let ticketCount: Int
    /// Different articles seen.
    let itemCount: Int
    /// Articles bought on two different days or in two named shops.
    let trackedCount: Int
    let risingCount: Int
    let fallingCount: Int
    let steadyCount: Int
    /// Followed articles with nothing to compare over time: bought on a single day, in several shops.
    let compareOnlyCount: Int
    let onceCount: Int
    /// The change of the prices of the articles that have a trend, each weighted by what was spent on it.
    let basketChangePercent: Double?
    let potentialSaving: Double
    let savingItemCount: Int
    /// Followed articles that are not in the list: it holds the 100 with the most spending.
    let hiddenCount: Int
    let items: [ItemPriceLine]

    var hasItems: Bool {
        !items.isEmpty
    }

    var hasTickets: Bool {
        ticketCount > 0
    }
}

/// GET /api/analytics/item-prices/detail
struct ItemPriceDetail: Codable {
    let months: Int
    let item: ItemPriceLine
    let merchantTotal: Int
    /// From the cheapest to the dearest, 20 at most.
    let merchants: [ItemPriceShop]
    let pointCount: Int
    /// The latest days it was bought, the oldest first, 60 at most.
    let points: [ItemPricePoint]

    var hiddenShopCount: Int {
        max(merchantTotal - merchants.count, 0)
    }

    var hiddenPointCount: Int {
        max(pointCount - points.count, 0)
    }
}

// MARK: - Which articles the list shows

enum ItemPriceFilter: String, CaseIterable, Identifiable {
    case all
    case rising
    case falling
    case gaps

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return "Tous"
        case .rising:
            return "Hausses"
        case .falling:
            return "Baisses"
        case .gaps:
            return "Écarts"
        }
    }

    /// The articles that match, in the order that makes sense for the filter.
    func apply(_ items: [ItemPriceLine]) -> [ItemPriceLine] {
        switch self {
        case .all:
            return items
        case .rising:
            return items
                .filter { $0.level == .rising }
                .sorted { ($0.changePercent ?? 0) > ($1.changePercent ?? 0) }
        case .falling:
            return items
                .filter { $0.level == .falling }
                .sorted { ($0.changePercent ?? 0) < ($1.changePercent ?? 0) }
        case .gaps:
            return items
                .filter { $0.hasSaving }
                .sorted { ($0.potentialSaving ?? 0) > ($1.potentialSaving ?? 0) }
        }
    }
}

// MARK: - Text helpers

enum ItemPricesText {
    static func money(_ value: Double) -> String {
        AppFormat.money(value.isFinite ? value : 0)
    }

    /// "+0,20 €" for an increase, "-0,20 €" for a decrease.
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

    /// "1 achat", "5 achats"
    static func purchases(_ count: Int) -> String {
        count < 2 ? "\(count) achat" : "\(count) achats"
    }

    /// "1 jour", "5 jours"
    static func days(_ count: Int) -> String {
        count < 2 ? "\(count) jour" : "\(count) jours"
    }

    /// "17 oct. 2025", from "2025-10-17"
    static func dateText(_ iso: String) -> String {
        WeeklyDigestText.format(iso, pattern: "d MMM yyyy")
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

    static func icon(_ level: ItemPriceTrend) -> String {
        switch level {
        case .rising:
            return "arrow.up.right.circle.fill"
        case .falling:
            return "arrow.down.right.circle.fill"
        case .steady:
            return "equal.circle.fill"
        case .compareOnly:
            return "arrow.left.arrow.right.circle.fill"
        }
    }

    // MARK: The top card

    /// The big line of the top card.
    static func headline(_ overview: ItemPricesOverview) -> String {
        guard let basket = overview.basketChangePercent, basket.isFinite else {
            return overview.trackedCount < 2 ? "\(overview.trackedCount) article suivi" : "\(overview.trackedCount) articles suivis"
        }

        if basket > 0 {
            return "Prix en hausse de " + percentText(basket)
        }

        if basket < 0 {
            return "Prix en baisse de " + percentText(-basket)
        }

        return "Prix stables"
    }

    /// The sentence under the big line.
    static func summary(_ overview: ItemPricesOverview) -> String {
        if overview.trackedCount == 0 {
            return overview.itemCount < 2
                ? "\(overview.itemCount) article repéré, aucun acheté assez de fois pour suivre son prix."
                : "\(overview.itemCount) articles repérés, aucun acheté assez de fois pour suivre son prix."
        }

        let tracked = overview.trackedCount < 2 ? "\(overview.trackedCount) article suivi" : "\(overview.trackedCount) articles suivis"
        let seen = overview.itemCount < 2 ? "sur \(overview.itemCount) acheté" : "sur \(overview.itemCount) achetés"

        let steady = overview.steadyCount < 2 ? "\(overview.steadyCount) stable" : "\(overview.steadyCount) stables"

        return "\(tracked) \(seen) : \(overview.risingCount) en hausse, \(overview.fallingCount) en baisse, \(steady)."
    }

    /// What the basket line means.
    static let basketNote = "Moyenne de l'évolution des prix des articles suivis, chacun compté selon ce que vous y avez dépensé."

    // MARK: The list

    /// "Dernier prix 1,20 € · avant 1,00 €"
    static func priceLine(_ line: ItemPriceLine) -> String {
        guard let last = line.lastPrice, let first = line.firstPrice else {
            return "Prix moyen " + money(line.averagePrice)
        }

        return "Dernier prix \(money(last)) · avant \(money(first))"
    }

    /// "5 achats · dernier le 17 oct. 2025"
    static func activityLine(_ line: ItemPriceLine) -> String {
        "\(purchases(line.purchaseCount)) · dernier le \(dateText(line.lastDate))"
    }

    /// The cheapest shop of an article, when there is one.
    static func shopLine(_ line: ItemPriceLine) -> String? {
        guard let shop = line.cheapestMerchant, let price = line.cheapestPrice else {
            return nil
        }

        return "Le moins cher : \(shop), \(money(price)) en moyenne"
    }

    /// What VoiceOver reads for a row of the list.
    static func rowAccessibility(_ line: ItemPriceLine) -> String {
        var parts = [line.name, trendTitle(line), priceLine(line), activityLine(line)]

        if let shop = shopLine(line) {
            parts.append(shop)
        }

        return parts.joined(separator: ", ")
    }

    static func trendTitle(_ line: ItemPriceLine) -> String {
        switch line.level {
        case .rising:
            return "En hausse de " + percentText(line.changePercent)
        case .falling:
            return "En baisse de " + percentText(abs(line.changePercent ?? 0))
        case .steady:
            return "Stable"
        case .compareOnly:
            return "Comparé entre commerces"
        }
    }

    /// The label at the right of a row.
    static func badge(_ line: ItemPriceLine) -> String {
        switch line.level {
        case .rising, .falling, .steady:
            return signedPercent(line.changePercent)
        case .compareOnly:
            if let gap = line.gapPercent {
                return "Écart " + percentText(gap)
            }

            return "-"
        }
    }

    static func hiddenNote(hidden: Int, shown: Int) -> String {
        "Seuls les \(shown) articles sur lesquels vous avez le plus dépensé sont listés, sur \(shown + hidden) suivis. Les filtres et la recherche ne portent que sur ces articles."
    }

    static func listTitle(count: Int) -> String {
        count > 0 ? "Articles · \(count)" : "Articles"
    }

    static let searchPrompt = "Rechercher un article"

    static let noMatch = "Aucun article ne correspond."

    static let emptyHint = "Le prix d'un article est suivi dès qu'il figure sur des tickets de deux jours différents, ou de deux commerces. Ajoutez le détail des articles à vos tickets (en scannant le ticket ou à la main) et revenez ici : vous verrez ce qui a monté, ce qui a baissé, et où c'est moins cher."

    static let noTicketsHint = "Aucun ticket avec le détail des articles sur cette période."

    static let savingNote = "Économie possible : ce que les achats faits dans les commerces plus chers que le moins cher auraient coûté de moins, au prix moyen de ce dernier."

    static let method = "Un article est repéré par son nom sur les tickets enregistrés, sans tenir compte des majuscules, des accents ni des espaces : « Lait demi-écrémé » et « lait demi-ecreme » sont le même article. Le prix suivi est le prix à l'unité (le prix unitaire du ticket, sinon le total divisé par la quantité). La hausse ou la baisse compare le prix du dernier jour d'achat à celui du premier, à partir de 2 %. Les lignes sans prix ou nommées « Article » sont ignorées. Les noms de commerces inconnus ne servent pas aux comparaisons."

    // MARK: The detail

    /// The big line of the detail.
    static func detailHeadline(_ line: ItemPriceLine) -> String {
        money(line.lastPrice ?? line.averagePrice)
    }

    /// The sentence under the big line.
    static func detailSummary(_ line: ItemPriceLine) -> String {
        guard let first = line.firstPrice, let change = line.change, line.hasTrend else {
            return "Pas encore de prix à comparer dans le temps : \(purchases(line.purchaseCount)) en \(days(line.dayCount))."
        }

        switch line.level {
        case .rising:
            return "En hausse de \(percentText(line.changePercent)) (\(signedMoney(change))) depuis le \(dateText(line.firstDate)), où il coûtait \(money(first))."
        case .falling:
            return "En baisse de \(percentText(abs(line.changePercent ?? 0))) (\(signedMoney(change))) depuis le \(dateText(line.firstDate)), où il coûtait \(money(first))."
        default:
            return "Prix stable depuis le \(dateText(line.firstDate)), où il coûtait \(money(first))."
        }
    }

    /// "Moyenne 1,10 €"
    static func averageText(_ line: ItemPriceLine) -> String {
        money(line.averagePrice)
    }

    static let historyTitle = "Évolution du prix"

    static let shopsTitle = "Où l'acheter"

    static let pointsTitle = "Derniers achats"

    static func hiddenShopsNote(hidden: Int, shown: Int) -> String {
        "Seuls les \(shown) commerces les moins chers sont listés, sur \(shown + hidden)."
    }

    static func hiddenPointsNote(hidden: Int, shown: Int) -> String {
        "Seuls les \(shown) derniers jours d'achat sont listés, sur \(shown + hidden)."
    }

    /// "Aldi · 0,90 € en moyenne" for the cheapest shop; for the others how much dearer they are.
    static func shopDetail(_ shop: ItemPriceShop, cheapestPrice: Double?) -> String {
        var text = "\(purchases(shop.purchaseCount)) · dernier prix \(money(shop.lastPrice)) le \(dateText(shop.lastDate))"

        if let cheapestPrice, !shop.cheapest, cheapestPrice > 0 {
            let extra = shop.averagePrice - cheapestPrice

            if extra > 0 {
                let percent = (extra * 1000 / cheapestPrice).rounded() / 10

                text += " · \(signedMoney(extra)) (\(signedPercent(percent))) de plus en moyenne"
            }
        }

        return text
    }

    /// The shop of a day: its name, several shops, or none known.
    static func pointShop(_ point: ItemPricePoint) -> String {
        if let merchant = point.merchant, point.merchantCount == 1 {
            return merchant
        }

        return point.merchantCount > 1 ? "Plusieurs commerces" : "Enseigne inconnue"
    }

    /// "3 achetés" for a day, with the quantity.
    static func quantityText(_ quantity: Int) -> String {
        "\u{00D7}\(quantity)"
    }

    /// The sentence under the shops when there is something to save.
    static func savingText(_ line: ItemPriceLine) -> String? {
        guard line.hasSaving, let saving = line.potentialSaving, let shop = line.cheapestMerchant, let price = line.cheapestPrice else {
            return nil
        }

        return "En l'achetant toujours au prix moyen le plus bas (\(shop), \(money(price))), vous auriez économisé \(money(saving))."
    }

    static let detailMethod = "Le prix d'un jour est le montant dépensé ce jour-là divisé par la quantité achetée. La moyenne d'un commerce est calculée sur toute la période. Un même nom d'article peut désigner des formats différents d'un commerce à l'autre : comparez avec bon sens."
}
