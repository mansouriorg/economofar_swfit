import Foundation

enum NotificationType: String, Codable, CaseIterable {
    case ticketAnalysisCompleted = "TICKET_ANALYSIS_COMPLETED"
    case monthlySpendingSummary = "MONTHLY_SPENDING_SUMMARY"
    case unusualSpending = "UNUSUAL_SPENDING"
    case budgetExceeded = "BUDGET_EXCEEDED"
    case weeklyExpenseReport = "WEEKLY_EXPENSE_REPORT"

    var title: String {
        switch self {
        case .ticketAnalysisCompleted:
            return "Analyse de ticket terminée"
        case .monthlySpendingSummary:
            return "Résumé mensuel"
        case .unusualSpending:
            return "Dépense inhabituelle"
        case .budgetExceeded:
            return "Budget dépassé"
        case .weeklyExpenseReport:
            return "Rapport hebdomadaire"
        }
    }

    var iconName: String {
        switch self {
        case .ticketAnalysisCompleted:
            return "doc.text.viewfinder"
        case .monthlySpendingSummary:
            return "calendar"
        case .unusualSpending:
            return "exclamationmark.triangle"
        case .budgetExceeded:
            return "chart.line.uptrend.xyaxis"
        case .weeklyExpenseReport:
            return "calendar.badge.clock"
        }
    }
}

struct NotificationPreferences: Codable, Equatable {
    var id: Int?
    var ticketAnalysisCompleted: Bool
    var monthlySpendingSummary: Bool
    var unusualSpending: Bool
    var budgetExceeded: Bool
    var weeklyExpenseReport: Bool
    var inAppEnabled: Bool
    var pushEnabled: Bool
    var emailEnabled: Bool

    static let defaultPreferences = NotificationPreferences(
        id: nil,
        ticketAnalysisCompleted: true,
        monthlySpendingSummary: true,
        unusualSpending: true,
        budgetExceeded: true,
        weeklyExpenseReport: true,
        inAppEnabled: true,
        pushEnabled: false,
        emailEnabled: false
    )
}

struct UpdateNotificationPreferencesRequest: Codable {
    var ticketAnalysisCompleted: Bool?
    var monthlySpendingSummary: Bool?
    var unusualSpending: Bool?
    var budgetExceeded: Bool?
    var weeklyExpenseReport: Bool?
    var inAppEnabled: Bool?
    var pushEnabled: Bool?
    var emailEnabled: Bool?

    init(
        ticketAnalysisCompleted: Bool? = nil,
        monthlySpendingSummary: Bool? = nil,
        unusualSpending: Bool? = nil,
        budgetExceeded: Bool? = nil,
        weeklyExpenseReport: Bool? = nil,
        inAppEnabled: Bool? = nil,
        pushEnabled: Bool? = nil,
        emailEnabled: Bool? = nil
    ) {
        self.ticketAnalysisCompleted = ticketAnalysisCompleted
        self.monthlySpendingSummary = monthlySpendingSummary
        self.unusualSpending = unusualSpending
        self.budgetExceeded = budgetExceeded
        self.weeklyExpenseReport = weeklyExpenseReport
        self.inAppEnabled = inAppEnabled
        self.pushEnabled = pushEnabled
        self.emailEnabled = emailEnabled
    }
}

struct AppNotification: Codable, Identifiable {
    let id: Int
    let type: NotificationType
    let title: String
    let body: String
    let metadata: String?
    let readAt: String?
    let createdAt: String?

    var isRead: Bool {
        readAt != nil
    }
}

struct UserBudget: Codable {
    let id: Int?
    let monthlyAmount: Double?
    let currency: String?
}

struct UpdateBudgetRequest: Codable {
    let monthlyAmount: Double
    let currency: String
}
