import SwiftUI

@main
struct economofarApp: App {
    // On injecte le SessionManager dans toute l'application
    @StateObject private var sessionManager = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            // Logique de démarrage
            if sessionManager.isLoading {
                // 1️⃣ Au lancement : On affiche le Splash Screen
                SplashView()
                    .transition(.opacity) // Petite transition douce quand il disparaît
                
            } else if sessionManager.isLoggedIn {
                // 2️⃣ Si connecté : On va sur l'App principale (TabBar)
                MainTabView()
                    .environmentObject(sessionManager)
                
            } else {
                // 3️⃣ Sinon : On va sur le Login
                LoginView()
                    .environmentObject(sessionManager)
            }
        }
    }
}
