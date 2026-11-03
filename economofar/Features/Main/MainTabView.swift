import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            // Onglet 1 : Dashboard
            DashboardView()
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }

            // Onglet 2 : Historique (données réelles du serveur : recherche, filtres, exports)
            NavigationStack {
                AdvancedHistoryView()
            }
            .tabItem {
                Label("Historique", systemImage: "list.bullet.clipboard")
            }

            // Onglet 3 : Analyses (catégories, tendance mensuelle, top commerçants)
            AnalyticsView()
                .tabItem {
                    Label("Analyses", systemImage: "chart.bar.xaxis")
                }

            // Onglet 4 : Paramètres
            SettingsView()
                .tabItem {
                    Label("Paramètres", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
        .modifier(SmartRemindersModifier())
        .modifier(DailyRoutineRemindersModifier())
        .task {
            await WarrantyReminders.refresh(token: sessionManager.token)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    await WarrantyReminders.refresh(token: sessionManager.token)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SessionManager())
}
