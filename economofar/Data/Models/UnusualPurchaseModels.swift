import Foundation

/// One purchase that is far above what the user usually spends.
struct UnusualPurchase: Codable {
    let date: String
    let merchant: String
    let category: String
    let amount: Double
    let usualAmount: Double
    let ratio: Double
    let basis: String
    let samples: Int

    var comparedWithMerchant: Bool {
        basis == "merchant"
    }
}

/// The purchases of the last days that look unusual.
struct UnusualPurchases: Codable {
    let days: Int
    let from: String
    let to: String
    let examined: Int
    let compared: Int
    let flaggedCount: Int
    let purchases: [UnusualPurchase]

    var periodText: String {
        "\(WeeklyDigestText.format(from, pattern: "d MMM")) - \(WeeklyDigestText.format(to, pattern: "d MMM yyyy"))"
    }
}

enum UnusualText {
    /// The ratio as a multiplier: 3 for 3.0, 2,6 for 2.6.
    static func ratio(_ value: Double) -> String {
        "×" + WeeklyDigestText.percent(value)
    }

    static func usual(_ purchase: UnusualPurchase) -> String {
        let place = purchase.comparedWithMerchant ? "dans ce commerce" : "dans cette catégorie"

        return "Habituellement \(AppFormat.money(purchase.usualAmount)) \(place) · \(purchase.samples) achats comparés"
    }

    static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }

        return String(first).uppercased() + text.dropFirst()
    }

    static func periodTitle(_ days: Int) -> String {
        "\(days) jours"
    }
}
