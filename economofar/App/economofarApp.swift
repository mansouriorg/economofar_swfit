import SwiftUI

@main
struct economofarApp: App {
    // On crée l'instance unique du SessionManager ici
    @StateObject private var sessionManager = SessionManager()

    // Verrouillage Face ID (réglage dans Paramètres > Sécurité)
    @StateObject private var appLock = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase

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

                // 4️⃣ Écran de verrouillage par-dessus l'app
                if appLock.isLocked && sessionManager.isLoggedIn && !sessionManager.isLoading {
                    LockScreenView(manager: appLock)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            // ✅ Injection UNIQUE pour toute la hiérarchie de l'app
            .environmentObject(sessionManager)
            .animation(.easeInOut, value: sessionManager.isLoggedIn)
            .animation(.easeInOut, value: sessionManager.isLoading)
            .animation(.easeInOut, value: appLock.isLocked)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background {
                    appLock.lockIfNeeded()
                }
            }
        }
    }
}
