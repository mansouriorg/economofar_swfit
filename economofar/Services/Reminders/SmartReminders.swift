import Foundation
import UserNotifications

// MARK: - What the reminders need from the server

private struct ReminderRecurring: Decodable {
    let merchantName: String
    let typicalAmount: Double
    let intervalDays: Int
    let nextExpectedDate: String
}

private struct ReminderRecurringResponse: Decodable {
    let items: [ReminderRecurring]
}

private struct ReminderGoal: Decodable {
    let id: Int
    let name: String
    let remainingAmount: Double
    let deadline: String?
    let monthlyNeeded: Double?
    let status: String
}

// MARK: - A reminder that will be scheduled

struct PlannedReminder: Equatable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
}

/// Counts the "versions" of the reminders so that a download that finishes late
/// (after a logout, or after the user turned the reminders off) can be ignored.
private actor ReminderGate {
    private var generation = 0

    func current() -> Int {
        generation
    }

    func bump() {
        generation += 1
    }
}

/// Shows the reminder as a banner even when the app is open.
final class SmartReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SmartReminderDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// Local reminders (no server push needed), rebuilt from the server every time the app opens:
/// - the day before a regular payment (monthly or less often), at 9:00
/// - 7 days and 1 day before the deadline of a savings goal, at 9:00
/// - on the 1st of the next two months, with the amount to put aside for the goals
/// The user can turn them off in the Settings.
enum SmartReminders {
    static let enabledKey = "smart_reminders_enabled"

    private static let recurringPrefix = "economofar.smart.recurring."
    private static let goalPrefix = "economofar.smart.goal."
    private static let monthlyPrefix = "economofar.smart.monthly."
    private static let allPrefixes = [recurringPrefix, goalPrefix, monthlyPrefix]

    private static let reminderHour = 9
    private static let minIntervalDays = 20
    private static let maxRecurring = 4
    private static let maxGoals = 3
    private static let goalOffsets = [7, 1]
    private static let monthlyCount = 2

    private static let gate = ReminderGate()

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    // MARK: Refresh

    /// Downloads the data and rebuilds the reminders. Never throws.
    /// A category whose data cannot be downloaded keeps its current reminders.
    static func refresh(token: String?) async {
        guard let token, !token.isEmpty else { return }

        ensureDelegate()

        guard isEnabled else {
            await gate.bump()
            await removePending(prefixes: allPrefixes)
            return
        }

        let generation = await gate.current()
        let now = Date()
        var plans: [(prefix: String, items: [PlannedReminder])] = []

        if let response = try? await APIClient.shared.get(
            "/api/analytics/recurring",
            token: token,
            as: ReminderRecurringResponse.self
        ) {
            plans.append((prefix: recurringPrefix, items: planRecurring(response.items, now: now)))
        }

        if let goals = try? await APIClient.shared.get(
            "/api/savings-goals",
            token: token,
            as: [ReminderGoal].self
        ) {
            plans.append((prefix: goalPrefix, items: planGoals(goals, now: now)))
            plans.append((prefix: monthlyPrefix, items: planMonthly(goals, now: now)))
        }

        guard !plans.isEmpty, !Task.isCancelled else { return }

        await apply(plans, generation: generation)
    }

    /// Removes the pending reminders (called when the user logs out).
    static func clear() {
        Task {
            await gate.bump()
            await removePending(prefixes: allPrefixes)
        }
    }

    private static func ensureDelegate() {
        let center = UNUserNotificationCenter.current()

        if center.delegate == nil {
            center.delegate = SmartReminderDelegate.shared
        }
    }

    /// False when the reminders were turned off or cleared since `generation` was read.
    private static func isCurrent(_ generation: Int) async -> Bool {
        guard isEnabled else { return false }
        return await gate.current() == generation
    }

    // MARK: Planning

    private static func planRecurring(_ items: [ReminderRecurring], now: Date) -> [PlannedReminder] {
        var dated: [(item: ReminderRecurring, due: Date)] = []

        for item in items where item.intervalDays >= minIntervalDays && item.typicalAmount > 0 {
            if let due = parseDay(item.nextExpectedDate) {
                dated.append((item: item, due: due))
            }
        }

        dated.sort { $0.due < $1.due }

        var result: [PlannedReminder] = []

        for entry in dated {
            if result.count >= maxRecurring {
                break
            }

            guard let fire = fireDate(daysBefore: 1, of: entry.due, now: now) else { continue }

            let merchant = entry.item.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = merchant.isEmpty ? "un paiement régulier" : merchant

            result.append(PlannedReminder(
                identifier: recurringPrefix + String(result.count) + "." + slug(merchant) + "." + isoDay(entry.due),
                title: "Paiement à venir",
                body: "Demain : \(label), environ \(AppFormat.money(entry.item.typicalAmount)).",
                fireDate: fire
            ))
        }

        return result
    }

    private static func planGoals(_ goals: [ReminderGoal], now: Date) -> [PlannedReminder] {
        var dated: [(goal: ReminderGoal, deadline: Date)] = []

        for goal in goals where goal.status != "completed" && goal.status != "overdue" && goal.remainingAmount > 0 {
            if let text = goal.deadline, let deadline = parseDay(text) {
                dated.append((goal: goal, deadline: deadline))
            }
        }

        dated.sort { $0.deadline < $1.deadline }

        var result: [PlannedReminder] = []

        for entry in dated.prefix(maxGoals) {
            for offset in goalOffsets {
                guard let fire = fireDate(daysBefore: offset, of: entry.deadline, now: now) else { continue }

                let remaining = AppFormat.money(entry.goal.remainingAmount)
                let body: String

                if offset == 1 {
                    body = "« \(entry.goal.name) » : l'échéance est demain. Il reste \(remaining) à épargner."
                } else {
                    body = "« \(entry.goal.name) » : plus qu'une semaine. Il reste \(remaining) à épargner."
                }

                result.append(PlannedReminder(
                    identifier: goalPrefix + String(entry.goal.id) + "." + String(offset),
                    title: "Objectif d'épargne",
                    body: body,
                    fireDate: fire
                ))
            }
        }

        return result
    }

    private static func planMonthly(_ goals: [ReminderGoal], now: Date) -> [PlannedReminder] {
        let calendar = Calendar.current

        var active: [(needed: Double, deadline: Date)] = []

        for goal in goals where goal.status != "completed" && goal.status != "overdue" {
            if let needed = goal.monthlyNeeded, needed > 0,
               let text = goal.deadline, let deadline = parseDay(text) {
                active.append((needed: needed, deadline: deadline))
            }
        }

        guard !active.isEmpty else { return [] }

        var result: [PlannedReminder] = []
        var cursor = now

        for _ in 0..<4 {
            if result.count >= monthlyCount {
                break
            }

            let monthParts = calendar.dateComponents([.year, .month], from: cursor)

            guard let monthStart = calendar.date(from: monthParts),
                  let fire = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: monthStart),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                break
            }

            cursor = nextMonth

            guard fire > now.addingTimeInterval(60) else { continue }

            var total = 0.0

            for entry in active where entry.deadline > fire {
                total += entry.needed
            }

            guard total > 0 else { continue }

            result.append(PlannedReminder(
                identifier: monthlyPrefix + String(format: "%04ld%02ld", monthParts.year ?? 0, monthParts.month ?? 0),
                title: "Épargne du mois",
                body: "Pensez à mettre de côté environ \(AppFormat.money(total)) ce mois-ci pour vos objectifs d'épargne.",
                fireDate: fire
            ))
        }

        return result
    }

    /// 9:00 on the day that is `days` before `day`, or nil when that moment is already past.
    private static func fireDate(daysBefore days: Int, of day: Date, now: Date) -> Date? {
        let calendar = Calendar.current

        guard let target = calendar.date(byAdding: .day, value: -days, to: day),
              let fire = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: target),
              fire > now.addingTimeInterval(60) else {
            return nil
        }

        return fire
    }

    // MARK: Scheduling

    private static func apply(_ plans: [(prefix: String, items: [PlannedReminder])], generation: Int) async {
        let center = UNUserNotificationCenter.current()

        guard await isCurrent(generation) else { return }

        await removePending(prefixes: plans.map { $0.prefix })

        var planned: [PlannedReminder] = []

        for plan in plans {
            planned.append(contentsOf: plan.items)
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

        guard await isCurrent(generation) else { return }

        let calendar = Calendar.current

        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    private static func removePending(prefixes: [String]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let identifiers = pending
            .map { $0.identifier }
            .filter { identifier in prefixes.contains(where: { identifier.hasPrefix($0) }) }

        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: Text and dates

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func parseDay(_ value: String) -> Date? {
        dayFormatter.date(from: value)
    }

    private static func isoDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static func slug(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(24))
    }
}
