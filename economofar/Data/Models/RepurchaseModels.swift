import Foundation

// MARK: - API response of GET /api/analytics/repurchase

/// Where an article stands in its buying rhythm: the server says "DUE" (the usual number of days between
/// two purchases has passed), "SOON" (three quarters of it have passed), "OK" or "LAPSED" (more than three
/// cycles without a purchase: the article is probably not bought any more).
enum RepurchaseStatus {
    case due
    case soon
    case ok
    case lapsed

    init(code: String) {
        switch code {
        case "DUE":
            self = .due
        case "SOON":
            self = .soon
        case "LAPSED":
            self = .lapsed
        default:
            self = .ok
        }
    }
}

/// One article that is bought at a regular rhythm.
struct RepurchaseLine: Codable, Identifiable {
    /// The name without capitals, accents or punctuation: the way the tickets are matched.
    let key: String
    /// The spelling the tickets write most often.
    let name: String
    let status: String
    /// The usual number of days between two purchase days.
    let cycleDays: Int
    let minIntervalDays: Int
    let maxIntervalDays: Int
    /// Different days the article was bought.
    let purchaseDays: Int
    let totalQuantity: Int
    /// The quantity bought on an average purchase day.
    let averageQuantity: Double
    let spent: Double
    let averageSpend: Double
    /// What the article costs in 30 days at its rhythm.
    let monthlyEstimate: Double
    /// "2026-01-10"
    let firstDate: String
    let lastDate: String
    /// The last purchase day plus the cycle.
    let nextDate: String
    let daysSinceLast: Int
    /// Negative once the expected day is past.
    let daysUntilNext: Int
    /// Nil when no ticket names a shop.
    let usualShop: String?

    var id: String {
        key
    }

    var level: RepurchaseStatus {
        RepurchaseStatus(code: status)
    }
}

struct RepurchaseOverview: Codable {
    let months: Int
    /// "2025-11-01"
    let from: String
    let to: String
    /// Articles bought on at least 3 different days.
    let followedCount: Int
    /// Articles with a regular rhythm.
    let articleCount: Int
    /// Followed articles whose purchases are too far apart from each other to tell a rhythm.
    let irregularCount: Int
    let dueCount: Int
    let soonCount: Int
    let okCount: Int
    let lapsedCount: Int
    /// What the articles that are still bought cost in 30 days.
    let estimatedMonthly: Double
    /// Articles that are not in the list: it holds the first 100.
    let hiddenCount: Int
    let articles: [RepurchaseLine]

    var hasArticles: Bool {
        !articles.isEmpty
    }

    /// Articles that are still bought.
    var activeCount: Int {
        max(articleCount - lapsedCount, 0)
    }
}

// MARK: - API response of GET /api/analytics/repurchase/detail

struct RepurchasePurchase: Codable {
    /// Empty when the ticket has no id.
    let id: String
    let date: String
    let quantity: Int
    let amount: Double
    /// Empty when the ticket names no shop.
    let shop: String
}

struct RepurchaseShop: Codable, Identifiable {
    let name: String
    let purchaseDays: Int

    var id: String {
        name
    }
}

struct RepurchaseDetail: Codable {
    let months: Int
    let from: String
    let to: String
    let article: RepurchaseLine
    /// Days between two purchase days, the oldest first, 30 at most.
    let intervals: [Int]
    let hiddenIntervalCount: Int
    /// The latest 20, the newest first.
    let purchases: [RepurchasePurchase]
    let hiddenPurchaseCount: Int
    /// The shops where it is bought, the one with most purchase days first, 5 at most.
    let shops: [RepurchaseShop]
}

// MARK: - Which articles the list shows

enum RepurchaseFilter: String, CaseIterable, Identifiable {
    case all
    case due
    case soon
    case ok
    case lapsed

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return "Tous"
        case .due:
            return "À racheter"
        case .soon:
            return "Bientôt"
        case .ok:
            return "Pas pressé"
        case .lapsed:
            return "Plus achetés"
        }
    }

    /// The articles that match, in the order of the server.
    func apply(_ articles: [RepurchaseLine]) -> [RepurchaseLine] {
        switch self {
        case .all:
            return articles
        case .due:
            return articles.filter { $0.level == .due }
        case .soon:
            return articles.filter { $0.level == .soon }
        case .ok:
            return articles.filter { $0.level == .ok }
        case .lapsed:
            return articles.filter { $0.level == .lapsed }
        }
    }
}

// MARK: - Text helpers

enum RepurchaseText {
    static func money(_ value: Double) -> String {
        AppFormat.money(value.isFinite ? value : 0)
    }

    /// "1 jour", "5 jours"
    static func days(_ count: Int) -> String {
        count < 2 ? "\(max(count, 0)) jour" : "\(count) jours"
    }

    /// "1 article", "5 articles"
    static func articles(_ count: Int) -> String {
        count < 2 ? "\(count) article" : "\(count) articles"
    }

    /// "1 achat", "5 achats"
    static func purchases(_ count: Int) -> String {
        count < 2 ? "\(count) achat" : "\(count) achats"
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

    /// "Tous les jours", "Tous les 7 jours"
    static func cycleText(_ cycleDays: Int) -> String {
        cycleDays <= 1 ? "Tous les jours" : "Tous les \(cycleDays) jours"
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

    static func icon(_ level: RepurchaseStatus) -> String {
        switch level {
        case .due:
            return "cart.badge.plus"
        case .soon:
            return "clock.fill"
        case .ok:
            return "checkmark.circle.fill"
        case .lapsed:
            return "moon.zzz.fill"
        }
    }

    static func statusTitle(_ level: RepurchaseStatus) -> String {
        switch level {
        case .due:
            return "À racheter"
        case .soon:
            return "Bientôt"
        case .ok:
            return "Pas pressé"
        case .lapsed:
            return "Plus acheté"
        }
    }

    /// "Dernier achat hier"
    static func lastLine(_ line: RepurchaseLine) -> String {
        "Dernier achat " + sinceLast(line.daysSinceLast)
    }

    /// What is expected next: "À racheter aujourd'hui", "Prochain achat dans 3 jours", "Plus acheté depuis 120 jours".
    static func nextLine(_ line: RepurchaseLine) -> String {
        let remaining = line.daysUntilNext

        switch line.level {
        case .lapsed:
            return "Plus acheté depuis " + days(line.daysSinceLast)
        case .due:
            if remaining == 0 {
                return "À racheter aujourd'hui"
            }

            if remaining < 0 {
                return "Attendu depuis " + days(-remaining)
            }

            return "À racheter"
        case .soon, .ok:
            if remaining == 1 {
                return "Prochain achat demain"
            }

            if remaining > 1 {
                return "Prochain achat dans " + days(remaining)
            }

            return "Prochain achat attendu"
        }
    }

    /// "Tous les 7 jours · 5 achats"
    static func rhythmLine(_ line: RepurchaseLine) -> String {
        cycleText(line.cycleDays) + " · " + purchases(line.purchaseDays)
    }

    /// "environ 4,71 € par mois"
    static func monthlyLine(_ line: RepurchaseLine) -> String {
        "environ " + money(line.monthlyEstimate) + " par mois"
    }

    /// What VoiceOver reads for a row of the list.
    static func rowAccessibility(_ line: RepurchaseLine) -> String {
        var parts = [line.name, nextLine(line), rhythmLine(line), lastLine(line), monthlyLine(line)]

        if let shop = line.usualShop, !shop.isEmpty {
            parts.append("surtout chez " + shop)
        }

        return parts.joined(separator: ", ")
    }

    /// What VoiceOver reads in place of the "-" of a figure that is not available.
    static func spoken(_ value: String) -> String {
        value == "-" ? "non disponible" : value
    }

    // MARK: The top card

    /// The big line of the top card: what the articles that are still bought cost in a month.
    static func headline(_ overview: RepurchaseOverview) -> String {
        money(overview.estimatedMonthly)
    }

    /// The sentence under the big line.
    static func summary(_ overview: RepurchaseOverview) -> String {
        if overview.articleCount == 0 {
            return "Aucun article n'est acheté à un rythme régulier sur la période."
        }

        if overview.activeCount == 0 {
            return "Vous n'achetez plus aucun de vos articles réguliers."
        }

        let plural = overview.activeCount > 1 ? "s" : ""

        if overview.estimatedMonthly <= 0 {
            return "\(articles(overview.activeCount)) acheté\(plural) régulièrement, sans prix lisible sur vos tickets : le coût par mois n'est pas calculé."
        }

        var text = "par mois environ pour \(articles(overview.activeCount)) acheté\(plural) régulièrement."

        if overview.dueCount > 0 {
            text += " " + (overview.dueCount < 2 ? "1 est à racheter." : "\(overview.dueCount) sont à racheter.")
        }

        return text
    }

    /// The sentence about the articles bought on several days but without a rhythm, nil when there are none.
    static func irregularNote(_ overview: RepurchaseOverview) -> String? {
        guard overview.irregularCount > 0 else {
            return nil
        }

        if overview.irregularCount < 2 {
            return "1 article acheté sur au moins 3 jours n'est pas listé : ses achats sont trop irréguliers pour dégager un rythme."
        }

        return "\(overview.irregularCount) articles achetés sur au moins 3 jours ne sont pas listés : leurs achats sont trop irréguliers pour dégager un rythme."
    }

    // MARK: The list

    static func hiddenNote(hidden: Int, shown: Int) -> String {
        "Seuls les \(shown) premiers articles sont listés, sur \(shown + hidden). Les filtres et la recherche ne portent que sur ces articles."
    }

    static func listTitle(count: Int) -> String {
        count > 0 ? "Articles · \(count)" : "Articles"
    }

    static let searchPrompt = "Rechercher un article"

    static let noMatch = "Aucun article ne correspond."

    static let emptyHint = "Un article apparaît ici dès qu'il a été acheté sur au moins 3 jours différents, à intervalles à peu près réguliers. Scannez vos tickets pendant quelques semaines et revenez ici : vous verrez ce que vous rachetez, à quel rythme et ce qu'il est temps de racheter."

    static let method = "Un article est repéré par son nom sur les tickets enregistrés, sans tenir compte des majuscules, des accents ni de la ponctuation. Il faut au moins 3 jours d'achat différents. Le rythme est le délai habituel entre deux jours d'achat (la valeur du milieu) ; il n'est retenu que si au moins les deux tiers des délais s'en écartent d'au plus la moitié. L'article est à racheter une fois ce délai écoulé, bientôt après les trois quarts du délai, et plus acheté après trois délais sans achat. Le coût par mois est le montant d'un achat moyen ramené à 30 jours, sans les articles plus achetés. Vos tickets ne sont jamais modifiés."

    // MARK: The detail

    /// The big line of the detail.
    static func detailHeadline(_ line: RepurchaseLine) -> String {
        nextLine(line)
    }

    /// The sentence under the big line.
    static func detailSummary(_ line: RepurchaseLine, months: Int) -> String {
        var text = "\(cycleText(line.cycleDays)) en général : \(purchases(line.purchaseDays)) en \(periodTitle(months)), du \(dateText(line.firstDate)) au \(dateText(line.lastDate))."

        if line.level != .lapsed {
            text += " Prochain achat attendu le \(dateText(line.nextDate))."
        }

        return text
    }

    /// The sentence of the banner that tells where the article stands.
    static func statusBanner(_ line: RepurchaseLine) -> String {
        switch line.level {
        case .due:
            return "Le délai habituel de \(days(line.cycleDays)) est écoulé : c'est le moment de racheter cet article."
        case .soon:
            return "Plus que \(days(max(line.daysUntilNext, 0))) avant le prochain achat habituel."
        case .ok:
            return "Vous avez acheté cet article \(sinceLast(line.daysSinceLast)) : rien ne presse."
        case .lapsed:
            return "Cet article n'a pas été acheté depuis \(days(line.daysSinceLast)), plus de trois fois son délai habituel : il n'est plus compté dans le coût par mois."
        }
    }

    /// "de 5 à 9 jours", "toujours 7 jours"
    static func spreadText(_ line: RepurchaseLine) -> String {
        if line.minIntervalDays == line.maxIntervalDays {
            return "toujours " + days(line.minIntervalDays)
        }

        return "de \(line.minIntervalDays) à " + days(line.maxIntervalDays)
    }

    /// "1,5" or "2"
    static func quantityText(_ value: Double) -> String {
        WeeklyDigestText.percent(value)
    }

    static let figuresTitle = "En chiffres"

    static let intervalsTitle = "Délais entre vos achats"

    static let purchasesTitle = "Derniers achats"

    static let shopsTitle = "Où vous l'achetez"

    /// What VoiceOver reads for the chart of the delays.
    static func intervalsAccessibility(_ intervals: [Int], cycleDays: Int) -> String {
        let values = intervals.map { String($0) }.joined(separator: ", ")

        return "Délais en jours entre vos achats, du plus ancien au plus récent : \(values). Rythme habituel : \(days(cycleDays))."
    }

    static func intervalsCaption(_ line: RepurchaseLine) -> String {
        if line.minIntervalDays == line.maxIntervalDays {
            return "Rythme habituel : \(days(line.cycleDays)), toujours le même délai."
        }

        return "Rythme habituel : \(days(line.cycleDays)), délais de \(line.minIntervalDays) à \(days(line.maxIntervalDays))."
    }

    static func hiddenIntervalsNote(_ detail: RepurchaseDetail) -> String {
        "Seuls les \(detail.intervals.count) derniers délais sont affichés, sur \(detail.intervals.count + detail.hiddenIntervalCount)."
    }

    static func hiddenPurchasesNote(_ detail: RepurchaseDetail) -> String {
        "Seuls les \(detail.purchases.count) derniers achats sont listés, sur \(detail.purchases.count + detail.hiddenPurchaseCount)."
    }

    /// "Achat attendu le" for an article that is overdue, "Prochain achat attendu" otherwise
    static func nextDateTitle(_ line: RepurchaseLine) -> String {
        line.level == .due ? "Achat attendu le" : "Prochain achat attendu"
    }

    /// "5 achats" for a shop
    static func shopLine(_ shop: RepurchaseShop) -> String {
        purchases(shop.purchaseDays)
    }

    static let detailMethod = "Les chiffres portent sur les tickets enregistrés de la période choisie. Un jour où l'article figure sur plusieurs tickets compte pour un seul achat. Vos tickets ne sont jamais modifiés."
}
