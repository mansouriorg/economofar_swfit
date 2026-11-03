import Foundation

// MARK: - API response of GET /api/analytics/prices

struct PriceTrackerResponse: Codable {
    let items: [PriceTrend]
    let risingCount: Int
    let fallingCount: Int
    let stableCount: Int
}

struct PricePoint: Codable, Identifiable {
    /// "2026-10-16"
    let date: String
    let price: Double
    let merchantName: String?

    var id: String { date }

    var dateText: String {
        PriceDateText.format(date, pattern: "d MMM yyyy")
    }
}

struct PriceTrend: Codable, Identifiable {
    let name: String
    let purchaseCount: Int
    let firstDate: String
    let lastDate: String
    let firstPrice: Double
    let previousPrice: Double
    let lastPrice: Double
    let minPrice: Double
    let maxPrice: Double
    let averagePrice: Double
    /// Change in percent between the first and the last price.
    let changePercent: Double
    /// "up", "down" or "stable"
    let trend: String
    let lastMerchant: String?
    let cheaperMerchant: String?
    let cheaperPrice: Double?
    let history: [PricePoint]

    var id: String { name }

    var isUp: Bool { trend == "up" }
    var isDown: Bool { trend == "down" }

    var changeText: String {
        if trend == "stable" {
            return "Stable"
        }

        let formatter = NumberFormatter()
        formatter.locale = AppFormat.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"

        let value = formatter.string(from: NSNumber(value: changePercent)) ?? String(changePercent)

        return value + " %"
    }

    var subtitle: String {
        let count = "\(purchaseCount) achats"

        if let lastMerchant, !lastMerchant.isEmpty {
            return count + " · " + lastMerchant
        }

        return count
    }

    var periodText: String {
        PriceDateText.format(firstDate, pattern: "MMM yyyy") + " → " + PriceDateText.format(lastDate, pattern: "MMM yyyy")
    }

    var sparklineValues: [Double] {
        history.map { $0.price }
    }
}

private enum PriceDateText {
    static func format(_ iso: String, pattern: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        guard let date = parser.date(from: iso) else {
            return iso
        }

        let formatter = DateFormatter()
        formatter.locale = AppFormat.locale
        formatter.dateFormat = pattern

        return formatter.string(from: date)
    }
}
