import SwiftUI

@main
struct economofarApp: App {
    // On injecte le SessionManager dans toute l'application
    // @StateObject garantit que cet objet survit tant que l'app est ouverte
    @StateObject private var sessionManager = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            // Le Switch logique : Qui décide quel écran afficher ?
            if sessionManager.isLoggedIn {
                // ✅ Si connecté -> On affiche le vrai Tableau de Bord
                DashboardView()
                    .environmentObject(sessionManager)
                    // Transition fluide lors du changement d'état
                    .transition(.opacity)
                
            } else {
                // ❌ Sinon -> On affiche l'écran de connexion
                LoginView()
                    .environmentObject(sessionManager)
                    .transition(.opacity)
            }
        }
    }
}
