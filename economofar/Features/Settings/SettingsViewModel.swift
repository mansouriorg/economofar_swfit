import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var preferences: NotificationPreferences = .defaultPreferences
    @Published var notifications: [AppNotification] = []

    @Published var monthlyBudgetText: String = ""
    @Published var currency: String = AppFormat.currencyCode

    @Published var isLoadingPreferences = false
    @Published var isLoadingNotifications = false
    @Published var isSavingBudget = false

    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let notificationService: AppNotificationService

    init(notificationService: AppNotificationService = .shared) {
        self.notificationService = notificationService
    }

    func load() async {
        await loadPreferences()
        await loadBudget()
    }

    func loadPreferences() async {
        isLoadingPreferences = true
        errorMessage = nil

        do {
            preferences = try await notificationService.fetchPreferences()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingPreferences = false
    }

    func loadNotifications() async {
        isLoadingNotifications = true
        errorMessage = nil

        do {
            notifications = try await notificationService.fetchNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingNotifications = false
    }

    func updatePreferences(_ request: UpdateNotificationPreferencesRequest) async {
        errorMessage = nil
        successMessage = nil

        do {
            preferences = try await notificationService.updatePreferences(request)
            successMessage = "Préférences mises à jour."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        do {
            let updatedNotification = try await notificationService.markNotificationAsRead(id: notification.id)

            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index] = updatedNotification
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadBudget() async {
        errorMessage = nil

        do {
            let budget = try await notificationService.fetchBudget()

            if let amount = budget?.monthlyAmount {
                monthlyBudgetText = String(format: "%.2f", amount)
            }

            currency = AppFormat.currencyCode
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveBudget() async {
        let cleanedValue = monthlyBudgetText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let amount = Double(cleanedValue), amount > 0 else {
            errorMessage = "Veuillez saisir un budget valide."
            return
        }

        isSavingBudget = true
        errorMessage = nil
        successMessage = nil

        do {
            let budget = try await notificationService.updateBudget(
                monthlyAmount: amount,
                currency: currency
            )

            if let amount = budget.monthlyAmount {
                monthlyBudgetText = String(format: "%.2f", amount)
            }

            currency = AppFormat.currencyCode

            successMessage = "Budget mensuel enregistré."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSavingBudget = false
    }
}
