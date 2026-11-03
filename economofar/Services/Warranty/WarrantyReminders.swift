import Foundation
import UserNotifications

/// Shows the reminder as a banner even when the app is open.
final class WarrantyNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WarrantyNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// Local reminders (no server needed): 30 days and 7 days before a warranty ends, at 9:00.
/// The list of reminders is rebuilt from the server every time the app opens
/// and every time the warranty screen changes.
enum WarrantyReminders {
    private static let identifierPrefix = "economofar.warranty."
    private static let offsetsInDays = [30, 7]
    private static let maxWarranties = 30

    /// Downloads the warranties and rebuilds the reminders. Never throws.
    static func refresh(token: String?) async {
        guard let token, !token.isEmpty else { return }

        guard let warranties = try? await WarrantyService.shared.fetchAll(token: token) else {
            return
        }

        await sync(warranties)
    }

    static func sync(_ warranties: [Warranty]) async {
        let center = UNUserNotificationCenter.current()

        if center.delegate == nil {
            center.delegate = WarrantyNotificationDelegate.shared
        }

        await removeAll(center: center)

        let calendar = Calendar.current
        let now = Date()

        var planned: [(identifier: String, title: String, body: String, components: DateComponents)] = []

        let upcoming = warranties
            .filter { $0.daysLeft >= 0 }
            .sorted { $0.daysLeft < $1.daysLeft }
            .prefix(maxWarranties)

        for warranty in upcoming {
            guard let endDate = warranty.endDateValue else { continue }

            for offset in offsetsInDays {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: endDate) else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = 9
                components.minute = 0

                guard let fireDate = calendar.date(from: components),
                      fireDate > now.addingTimeInterval(60) else {
                    continue
                }

                var product = ""

                if let note = warranty.note, !note.isEmpty {
                    product = " (" + String(note.prefix(40)) + ")"
                }

                planned.append((
                    identifier: identifierPrefix + warranty.ticketId + "." + String(offset),
                    title: "Garantie bientôt terminée",
                    body: "La garantie de votre achat chez \(warranty.title)\(product) se termine dans \(offset) jours (\(warranty.endDateText)).",
                    components: components
                ))
            }
        }

        guard !planned.isEmpty else { return }

        var settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }

        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
            return
        }

        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: false)
            let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    /// Removes the pending warranty reminders (called when the user logs out).
    static func clear() {
        Task {
            await removeAll(center: UNUserNotificationCenter.current())
        }
    }

    private static func removeAll(center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()

        let identifiers = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix(identifierPrefix) }

        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
}
