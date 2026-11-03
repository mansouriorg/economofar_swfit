import Foundation

// MARK: - API response of GET /api/analytics/daily-budget

enum DailyBudgetLevel {
    case noBudget
    case good
    case tight
    case over
    case exhausted
}

struct DailyBudget: Codable {
    /// "2026-10-17"
    let date: String
    /// "none", "good", "tight", "over" or "exhausted"
    let status: String
    /// Days left in the month, today included.
    let daysLeft: Int
    let monthlyBudget: Double?
    let dailyBudget: Double?
    /// Spending of today without the regular payments.
    let spentToday: Double
    /// Regular payments (rent, subscriptions...) recorded today. They are planned, so they do not use the daily budget.
    let recurringToday: Double
    let remainingToday: Double?
    let tomorrowBudget: Double?
    /// Negative when the budget is already passed.
    let monthRemaining: Double?
    /// Regular payments still expected until the end of the month, today included.
    let upcomingRecurring: Double

    var hasBudget: Bool {
        dailyBudget != nil
    }

    var level: DailyBudgetLevel {
        switch status {
        case "none":
            return .noBudget
        case "good":
            return .good
        case "tight":
            return .tight
        case "over":
            return .over
        case "exhausted":
            return .exhausted
        default:
            guard let daily = dailyBudget else { return .noBudget }

            if daily <= 0 { return .exhausted }
            if (remainingToday ?? 0) < 0 { return .over }

            return .good
        }
    }

    /// Share of the day's budget already used, between 0 and 1.
    var usedFraction: Double {
        guard let daily = dailyBudget, daily > 0 else {
            return spentToday > 0 ? 1 : 0
        }

        let value = spentToday / daily

        return value.isFinite ? min(max(value, 0), 1) : 0
    }

    var daysLeftText: String {
        daysLeft <= 1 ? "Dernier jour du mois" : "\(daysLeft) jours, aujourd'hui compris"
    }

    // MARK: Home row

    var rowValue: String {
        switch level {
        case .noBudget:
            return "Définir"
        case .exhausted:
            return "Atteint"
        case .over:
            return AppFormat.money(remainingToday ?? 0)
        case .good, .tight:
            return AppFormat.money(max(remainingToday ?? 0, 0))
        }
    }

    var rowSubtitle: String {
        let daily = AppFormat.money(dailyBudget ?? 0)
        let spent = AppFormat.money(spentToday)

        switch level {
        case .noBudget:
            return "Définissez un budget mensuel pour le voir"
        case .exhausted:
            return "Budget du mois atteint ou réservé aux paiements à venir"
        case .over:
            return "Dépassé · \(spent) dépensés sur \(daily)"
        case .tight:
            if (remainingToday ?? 0) <= 0 {
                return "Atteint · \(spent) sur \(daily)"
            }

            return "Presque atteint · \(spent) sur \(daily)"
        case .good:
            if spentToday > 0 {
                return "\(spent) dépensés sur \(daily)"
            }

            return "Rien dépensé pour l'instant · budget de \(daily)"
        }
    }

    // MARK: Screen

    var heroLabel: String {
        switch level {
        case .noBudget:
            return "Budget du jour"
        case .exhausted:
            return "Budget du mois atteint"
        case .over:
            return "Dépassement du jour"
        case .good, .tight:
            return "Il vous reste aujourd'hui"
        }
    }

    var heroValue: String {
        switch level {
        case .noBudget:
            return "–"
        case .exhausted:
            return AppFormat.money(0)
        case .over:
            return AppFormat.money(abs(remainingToday ?? 0))
        case .good, .tight:
            return AppFormat.money(max(remainingToday ?? 0, 0))
        }
    }

    var heroCaption: String {
        switch level {
        case .noBudget:
            return "Aucun budget mensuel défini"
        case .exhausted:
            return "Plus rien à répartir sur le reste du mois"
        case .over, .good, .tight:
            return "Sur un budget de \(AppFormat.money(dailyBudget ?? 0)) aujourd'hui"
        }
    }

    var message: String {
        switch level {
        case .noBudget:
            return "Définissez un budget mensuel dans Réglages pour savoir combien vous pouvez dépenser chaque jour."
        case .exhausted:
            return "Votre budget du mois est déjà atteint ou réservé aux paiements réguliers à venir. Rien n'est disponible pour aujourd'hui."
        case .over:
            if let tomorrowBudget {
                return "Vous avez dépassé votre budget du jour. Demain, vous pourrez dépenser \(AppFormat.money(tomorrowBudget))."
            }

            return "Vous avez dépassé votre budget du jour."
        case .tight:
            if (remainingToday ?? 0) <= 0 {
                return "Vous avez utilisé tout votre budget du jour."
            }

            return "Attention, vous avez presque utilisé votre budget du jour."
        case .good:
            if spentToday > 0 {
                return "Vous êtes dans votre budget du jour."
            }

            return "Vous pouvez dépenser jusqu'à \(AppFormat.money(dailyBudget ?? 0)) aujourd'hui sans quitter votre budget."
        }
    }
}
