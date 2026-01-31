import SwiftUI

@main
struct economofarApp: App {
    // On injecte le SessionManager dans toute l'application
    @StateObject private var sessionManager = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            // Le Switch logique
            if sessionManager.isLoggedIn {
                // ✅ Affichage direct de la TabBar (Sans transition)
                MainTabView()
                    .environmentObject(sessionManager)
                
            } else {
                // ❌ Affichage direct du Login (Sans transition)
                LoginView()
                    .environmentObject(sessionManager)
            }
        }
    }
}
