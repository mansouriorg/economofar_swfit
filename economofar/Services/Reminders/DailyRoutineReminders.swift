import Foundation
import UserNotifications

// MARK: - What the routine reminders need from the server

private struct RoutineDay: Decodable {
    let date: String?
    let status: String?
    let spentToday: Double?
    let recurringToday: Double?
    let remainingToday: Double?
    let tomorrowBudget: Double?
}

/// Counts the "versions" of the reminders: only the most recent refresh may schedule something,
/// so an older download that finishes late (or a logout) can never overwrite a newer result.
private actor RoutineGate {
    private var generation = 0

    @discardableResult
    func advance() -> Int {
        generation += 1
        return generation
    }

    func current() -> Int {
        generation
    }
}

/// Why the reminders are rebuilt. It decides whether iOS may be asked for the permission:
/// - opened: the app opened or came back. Asked only once a purchase is recorded today.
/// - leaving: the app goes to the background. Never asked (the alert could not be shown).
/// - switchChanged: the user touched one of the switches. Asked right away.
enum RoutineRefreshReason {
    case opened
    case leaving
    case switchChanged
}

/// Everyday local reminders (no server push needed), rebuilt every time the app opens or
/// goes to the background:
/// - evening, 20:00, up to 3 evenings: "note your purchases of the day" (today's one is skipped
///   when a purchase is already recorded today, and so are the Sundays when the Sunday summary
///   is on)
/// - morning, 8:30, the next morning only: what can be spent today to stay in the monthly budget
/// - Sunday, 19:00, for the next 2 Sundays: the weekly summary is available
/// Each one has its own switch in the Settings. They are planned with the existing
/// PlannedReminder type and use their own identifiers, so they never touch the other reminders.
enum DailyRoutineReminders {
    static let eveningKey = "routine_evening_enabled"
    static let morningKey = "routine_morning_enabled"
    static let weeklyKey = "routine_weekly_enabled"

    static let eveningDefault = true
    static let morningDefault = false
    static let weeklyDefault = true

    private static let recordedDayKey = "routine_recorded_day"

    private static let eveningPrefix = "economofar.routine.evening."
    private static let morningPrefix = "economofar.routine.morning."
    private static let weeklyPrefix = "economofar.routine.weekly."
    private static let allPrefixes = [eveningPrefix, morningPrefix, weeklyPrefix]

    private static let eveningHour = 20
    private static let eveningDays = 3
    private static let morningHour = 8
    private static let morningMinute = 30
    private static let weeklyHour = 19
    private static let weeklyCount = 2
    private static let sundayWeekday = 1

    private static let eveningTexts = [
        "Avez-vous noté vos achats du jour ? Quelques secondes suffisent.",
        "Un ticket dans la poche ? Scannez-le ou saisissez-le pour garder votre budget à jour.",
        "Pensez à enregistrer les achats d'aujourd'hui pour que votre budget reste juste."
    ]

    private static let gate = RoutineGate()

    static var eveningEnabled: Bool {
        flag(eveningKey, fallback: eveningDefault)
    }

    static var morningEnabled: Bool {
        flag(morningKey, fallback: morningDefault)
    }

    static var weeklyEnabled: Bool {
        flag(weeklyKey, fallback: weeklyDefault)
    }

    private static var anyEnabled: Bool {
        eveningEnabled || morningEnabled || weeklyEnabled
    }

    private static func flag(_ key: String, fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    // MARK: Refresh

    /// Downloads today's budget and rebuilds the reminders. Never throws.
    /// A reminder whose data cannot be downloaded keeps its current notification.
    static func refresh(token: String?, reason: RoutineRefreshReason = .opened) async {
        guard let token, !token.isEmpty else { return }

        ensureDelegate()

        let evening = eveningEnabled
        let morning = morningEnabled
        let weekly = weeklyEnabled

        guard evening || morning || weekly else {
            await gate.advance()
            await removePending(prefixes: allPrefixes, keeping: [])
            return
        }

        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()

        if current.authorizationStatus == .denied {
            return
        }

        let generation = await gate.advance()
        let now = Date()

        var day: RoutineDay?

        if evening || morning {
            day = try? await APIClient.shared.get(
                "/api/analytics/daily-budget",
                token: token,
                as: RoutineDay.self
            )
        }

        guard !Task.isCancelled, await isCurrent(generation) else { return }

        let recorded = recordedToday(day, now: now)

        var plans: [(prefix: String, items: [PlannedReminder])] = []

        plans.append((
            prefix: eveningPrefix,
            items: evening ? planEvening(recorded: recorded, skipSunday: weekly, now: now) : []
        ))
        plans.append((prefix: weeklyPrefix, items: weekly ? planWeekly(now: now) : []))

        if !morning {
            plans.append((prefix: morningPrefix, items: []))
        } else if let day, day.date == isoDay(now) {
            plans.append((prefix: morningPrefix, items: planMorning(day, now: now)))
        }

        let mayAsk = reason == .switchChanged || (reason == .opened && recorded)

        await apply(plans, generation: generation, mayAsk: mayAsk)
    }

    /// Removes the pending reminders (called when the user logs out).
    static func clear() {
        Task {
            await gate.advance()
            UserDefaults.standard.removeObject(forKey: recordedDayKey)
            await removePending(prefixes: allPrefixes, keeping: [])
        }
    }

    private static func ensureDelegate() {
        let center = UNUserNotificationCenter.current()

        if center.delegate == nil {
            center.delegate = SmartReminderDelegate.shared
        }
    }

    /// False when every reminder was turned off, or a newer refresh started, since `generation`.
    private static func isCurrent(_ generation: Int) async -> Bool {
        guard anyEnabled else { return false }
        return await gate.current() == generation
    }

    // MARK: Planning

    /// True when a purchase (or a regular payment) is recorded today. The server answer wins when
    /// it is about today; otherwise (offline, other date) the last known answer of today is used.
    private static func recordedToday(_ day: RoutineDay?, now: Date) -> Bool {
        let today = isoDay(now)
        let defaults = UserDefaults.standard

        if let day, day.date == today {
            let recorded = (day.spentToday ?? 0) > 0 || (day.recurringToday ?? 0) > 0

            if recorded {
                defaults.set(today, forKey: recordedDayKey)
            } else {
                defaults.removeObject(forKey: recordedDayKey)
            }

            return recorded
        }

        return defaults.string(forKey: recordedDayKey) == today
    }

    private static func planEvening(recorded: Bool, skipSunday: Bool, now: Date) -> [PlannedReminder] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        var result: [PlannedReminder] = []

        for offset in 0..<eveningDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: eveningHour, minute: 0, second: 0, of: date),
                  fire > now.addingTimeInterval(60) else {
                continue
            }

            if offset == 0 && recorded {
                continue
            }

            if skipSunday && calendar.component(.weekday, from: fire) == sundayWeekday {
                continue
            }

            let ordinal = calendar.ordinality(of: .day, in: .era, for: fire) ?? 0

            result.append(PlannedReminder(
                identifier: eveningPrefix + isoDay(fire),
                title: "Vos achats du jour",
                body: eveningTexts[ordinal % eveningTexts.count],
                fireDate: fire
            ))
        }

        return result
    }

    /// The first morning that is still to come: today when the app is opened before 8:30,
    /// otherwise tomorrow. Nothing is planned without a monthly budget.
    private static func planMorning(_ day: RoutineDay, now: Date) -> [PlannedReminder] {
        guard let status = day.status, status != "none" else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        for offset in 0..<2 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: morningHour, minute: morningMinute, second: 0, of: date),
                  fire > now.addingTimeInterval(60) else {
                continue
            }

            let amount = offset == 0 ? day.remainingToday : day.tomorrowBudget

            guard let amount else { return [] }

            let exhausted = offset == 1 || status == "exhausted"

            return [PlannedReminder(
                identifier: morningPrefix + isoDay(fire),
                title: "Budget du jour",
                body: morningBody(amount: amount, exhausted: exhausted),
                fireDate: fire
            )]
        }

        return []
    }

    private static func morningBody(amount: Double, exhausted: Bool) -> String {
        if amount > 0 {
            return "Vous pouvez dépenser environ \(AppFormat.money(amount)) aujourd'hui pour rester dans votre budget du mois."
        }

        if exhausted {
            return "Le budget du mois est atteint ou réservé à vos paiements à venir : limitez vos dépenses aujourd'hui."
        }

        return "Votre part du jour est déjà utilisée : gardez un œil sur vos dépenses."
    }

    private static func planWeekly(now: Date) -> [PlannedReminder] {
        let calendar = Calendar.current
        let components = DateComponents(hour: weeklyHour, minute: 0, weekday: sundayWeekday)

        var result: [PlannedReminder] = []
        var cursor = now.addingTimeInterval(60)

        for _ in 0..<weeklyCount {
            guard let fire = calendar.nextDate(after: cursor, matching: components, matchingPolicy: .nextTime) else {
                break
            }

            result.append(PlannedReminder(
                identifier: weeklyPrefix + isoDay(fire),
                title: "Résumé de la semaine",
                body: "Votre résumé de la semaine est disponible : retrouvez-le dans l'onglet Analyses.",
                fireDate: fire
            ))

            cursor = fire
        }

        return result
    }

    // MARK: Scheduling

    /// Adds the new reminders first (the same identifier replaces the old one) and only then removes
    /// the old ones that are no longer planned, so an interrupted refresh never leaves the user
    /// with nothing.
    private static func apply(
        _ plans: [(prefix: String, items: [PlannedReminder])],
        generation: Int,
        mayAsk: Bool
    ) async {
        let center = UNUserNotificationCenter.current()

        guard await isCurrent(generation) else { return }

        let prefixes = plans.map { $0.prefix }

        var planned: [PlannedReminder] = []

        for plan in plans {
            planned.append(contentsOf: plan.items)
        }

        guard !planned.isEmpty else {
            await removePending(prefixes: prefixes, keeping: [])
            return
        }

        var settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined && mayAsk {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }

        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
            return
        }

        let calendar = Calendar.current

        for item in planned {
            guard await isCurrent(generation) else { return }

            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)

            try? await center.add(request)
        }

        guard await isCurrent(generation) else { return }

        await removePending(prefixes: prefixes, keeping: Set(planned.map { $0.identifier }))
    }

    private static func removePending(prefixes: [String], keeping: Set<String>) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let identifiers = pending
            .map { $0.identifier }
            .filter { identifier in
                prefixes.contains(where: { identifier.hasPrefix($0) }) && !keeping.contains(identifier)
            }

        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: Dates

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func isoDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
