import SwiftUI

/// Rebuilds the smart reminders when the main screen opens and every time the app comes back.
struct SmartRemindersModifier: ViewModifier {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task {
                await SmartReminders.refresh(token: sessionManager.token)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task {
                        await SmartReminders.refresh(token: sessionManager.token)
                    }
                }
            }
    }
}

/// The on/off switch shown in the Settings, with the same look as the other switches.
struct SmartRemindersToggleRow: View {
    @EnvironmentObject var sessionManager: SessionManager
    @AppStorage(SmartReminders.enabledKey) private var enabled = true

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(EconomofarUI.accent.opacity(0.11))
                    .frame(width: 46, height: 46)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Rappels intelligents")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text("Paiements à venir et échéances d'épargne, sur cet iPhone")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $enabled)
                .labelsHidden()
                .tint(EconomofarUI.accent)
        }
        .padding(16)
        .onChange(of: enabled) { _ in
            Task {
                await SmartReminders.refresh(token: sessionManager.token)
            }
        }
    }
}
