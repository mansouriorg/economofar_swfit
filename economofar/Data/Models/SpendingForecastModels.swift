import Foundation

// MARK: - API response of GET /api/analytics/forecast

struct SpendingForecast: Codable {
    /// "2026-10"
    let month: String
    let dayOfMonth: Int
    let daysInMonth: Int
    let daysRemaining: Int
    let spentSoFar: Double
    /// Regular payments (subscriptions...) still expected before the end of the month.
    let upcomingRecurring: Double
    /// Usual spending per day, without the regular payments.
    let dailyPace: Double
    let projectedTotal: Double
    let projectedLow: Double
    let projectedHigh: Double
    let previousMonthTotal: Double?
    let monthlyBudget: Double?
    /// "none", "onTrack", "atRisk", "projectedOver" or "exceeded"
    let budgetStatus: String
    let projectedOverBudget: Double?
    let dailyAllowance: Double?
    /// "2026-10-24"
    let exceedDate: String?
    /// "low", "medium" or "high"
    let confidence: String
    let upcoming: [ForecastUpcoming]

    var monthName: String {
        ForecastDateText.format(month + "-01", pattern: "LLLL")
    }

    var hasBudget: Bool {
        monthlyBudget != nil
    }

    var monthProgress: Double {
        guard daysInMonth > 0 else { return 0 }

        return min(max(Double(dayOfMonth) / Double(daysInMonth), 0), 1)
    }

    var rangeText: String {
        "Entre \(AppFormat.money(projectedLow)) et \(AppFormat.money(projectedHigh))"
    }

    var budgetStatusTitle: String {
        switch budgetStatus {
        case "onTrack":
            return "Dans le budget"
        case "atRisk":
            return "Proche du budget"
        case "projectedOver":
            return "Dépassement prévu"
        case "exceeded":
            return "Budget dépassé"
        default:
            return ""
        }
    }

    var budgetMessage: String? {
        guard let budget = monthlyBudget else { return nil }

        switch budgetStatus {
        case "exceeded":
            return "Vous avez déjà dépassé votre budget de \(AppFormat.money(max(spentSoFar - budget, 0)))."
        case "projectedOver":
            let over = projectedOverBudget ?? max(projectedTotal - budget, 0)
            let base = "À ce rythme, vous dépasserez votre budget d'environ \(AppFormat.money(over))"

            if let exceedDate {
                return base + ", vers le \(ForecastDateText.format(exceedDate, pattern: "d MMMM"))."
            }

            return base + "."
        case "atRisk":
            return "Vous devriez terminer le mois proche de votre budget. Il vous resterait environ \(AppFormat.money(max(budget - projectedTotal, 0)))."
        case "onTrack":
            return "Au rythme actuel, il vous resterait environ \(AppFormat.money(max(budget - projectedTotal, 0))) à la fin du mois."
        default:
            return nil
        }
    }

    var changeVersusPreviousText: String? {
        guard let previous = previousMonthTotal, previous > 0 else { return nil }

        let change = (projectedTotal - previous) / previous * 100

        if abs(change) < 1 {
            return "Stable"
        }

        let formatter = NumberFormatter()
        formatter.locale = AppFormat.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.positivePrefix = "+"

        let value = formatter.string(from: NSNumber(value: change)) ?? String(Int(change))

        return value + " %"
    }

    var confidenceText: String {
        switch confidence {
        case "high":
            return "Estimation fiable : elle s'appuie sur vos derniers mois et sur le rythme de ce mois-ci."
        case "medium":
            return "Estimation indicative : elle gagnera en précision avec vos prochains tickets."
        default:
            return "Estimation peu fiable : il y a encore peu de tickets enregistrés. Elle s'affinera avec le temps."
        }
    }
}

struct ForecastUpcoming: Codable, Identifiable {
    let merchantName: String
    let amount: Double
    /// "2026-10-20"
    let date: String

    var id: String { merchantName + date }

    var dateText: String {
        ForecastDateText.format(date, pattern: "d MMM")
    }
}

private enum ForecastDateText {
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
