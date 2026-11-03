import SwiftUI

/// Rebuilds the everyday reminders when the main screen opens, every time the app comes back
/// and when it goes to the background (so that a purchase recorded meanwhile is taken into account).
struct DailyRoutineRemindersModifier: ViewModifier {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task {
                await DailyRoutineReminders.refresh(token: sessionManager.token, reason: .opened)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task {
                        await DailyRoutineReminders.refresh(token: sessionManager.token, reason: .opened)
                    }
                } else if newPhase == .background {
                    Task {
                        await DailyRoutineReminders.refresh(token: sessionManager.token, reason: .leaving)
                    }
                }
            }
    }
}

/// The three switches shown in the Settings, with the same look as the other switches.
struct DailyRoutineRemindersRows: View {
    var body: some View {
        VStack(spacing: 0) {
            DailyRoutineToggleRow(
                icon: "moon.stars.fill",
                title: "Rappel du soir",
                subtitle: "À 20h, pensez à noter vos achats du jour",
                key: DailyRoutineReminders.eveningKey,
                defaultValue: DailyRoutineReminders.eveningDefault
            )

            DailyRoutineDivider()

            DailyRoutineToggleRow(
                icon: "sun.max.fill",
                title: "Budget du matin",
                subtitle: "À 8h30, ce que vous pouvez dépenser aujourd’hui",
                key: DailyRoutineReminders.morningKey,
                defaultValue: DailyRoutineReminders.morningDefault
            )

            DailyRoutineDivider()

            DailyRoutineToggleRow(
                icon: "chart.bar.doc.horizontal",
                title: "Résumé du dimanche",
                subtitle: "Le dimanche à 19h, votre semaine en un coup d’œil",
                key: DailyRoutineReminders.weeklyKey,
                defaultValue: DailyRoutineReminders.weeklyDefault
            )
        }
    }
}

private struct DailyRoutineDivider: View {
    var body: some View {
        Divider()
            .background(EconomofarUI.border)
            .padding(.leading, 76)
    }
}

private struct DailyRoutineToggleRow: View {
    @EnvironmentObject var sessionManager: SessionManager
    @AppStorage private var enabled: Bool

    let icon: String
    let title: String
    let subtitle: String

    init(icon: String, title: String, subtitle: String, key: String, defaultValue: Bool) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        _enabled = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(EconomofarUI.accent.opacity(0.11))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $enabled)
                .labelsHidden()
                .accessibilityLabel(title)
                .tint(EconomofarUI.accent)
        }
        .padding(16)
        .onChange(of: enabled) { isOn in
            Task {
                await DailyRoutineReminders.refresh(
                    token: sessionManager.token,
                    reason: isOn ? .switchChanged : .leaving
                )
            }
        }
    }
}
