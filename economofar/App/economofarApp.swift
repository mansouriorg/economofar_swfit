import SwiftUI

@main
struct economofarApp: App {
    // On crée l'instance unique du SessionManager ici
    @StateObject private var sessionManager = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Logique de routage
                if sessionManager.isLoading {
                    // 1️⃣ Splash Screen pendant la vérification du token
                    SplashView()
                        .transition(.opacity)
                    
                } else if sessionManager.isLoggedIn {
                    // 2️⃣ Redirection automatique si le token est valide
                    MainTabView()
                    
                } else {
                    // 3️⃣ Login si aucun token n'est trouvé ou si déconnecté
                    LoginView()
                }
            }
            // ✅ Injection UNIQUE pour toute la hiérarchie de l'app
            // Plus besoin de le remettre sur chaque vue individuellement
            .environmentObject(sessionManager)
            .animation(.easeInOut, value: sessionManager.isLoggedIn)
            .animation(.easeInOut, value: sessionManager.isLoading)
        }
    }
}
