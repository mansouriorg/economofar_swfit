import SwiftUI

struct MainTabView: View {
    // On garde notre SessionManager accessible
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
            
            // Onglet 3 : Profil (On mettra un placeholder pour l'instant)
            Text("Paramètres à venir")
                .tabItem {
                    Label("Paramètres", systemImage: "gearshape.fill")
                }
        }
        // Couleur des icônes actives
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(SessionManager())
}
