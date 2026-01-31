import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        TabView {
            // Onglet 1 : Dashboard
            DashboardView()
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }
            
            // Onglet 2 : Historique
            HistoryView()
                .tabItem {
                    Label("Historique", systemImage: "list.bullet.clipboard")
                }
            
            // ✅ Onglet 3 : Paramètres (Mis à jour)
            SettingsView()
                .tabItem {
                    Label("Paramètres", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(SessionManager())
}
