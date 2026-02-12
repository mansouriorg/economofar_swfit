import Foundation
import SwiftUI
import Combine

class SessionManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var token: String?
    @Published var isLoading: Bool = true
    
    // ✅ Utilisation de la même clé que dans AuthService pour la cohérence
    private let tokenKey = "jwt_token"
    
    init() {
        print("🚀 [SessionManager] Initialisation...")
        checkLoginStatus()
    }
    
    // MARK: - Session Logic
    
    func checkLoginStatus() {
        // 1. On vérifie si un token existe physiquement sur le disque
        if let savedToken = UserDefaults.standard.string(forKey: tokenKey) {
            print("🔑 [SessionManager] Token trouvé dans UserDefaults: \(savedToken.prefix(10))...")
            
            // On met à jour l'état en mémoire
            self.token = savedToken
            self.isLoggedIn = true
            
            // NOTE: Idéalement, ici tu devrais faire un appel API rapide
            // pour récupérer les infos du User (Profile) avec ce token.
        } else {
            print("ℹ️ [SessionManager] Aucun token trouvé au démarrage.")
            self.isLoggedIn = false
        }
        
        // 2. On laisse le Splash Screen visible un court instant
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                self.isLoading = false
            }
            print("🏁 [SessionManager] Chargement initial terminé. isLoggedIn: \(self.isLoggedIn)")
        }
    }
    
    /// ✅ Utilisé par le LoginView pour synchroniser la session après un succès API
    func setSession(token: String, user: User? = nil) {
        print("🔓 [SessionManager] Mise à jour de la session active")
        
        self.token = token
        self.currentUser = user
        self.isLoggedIn = true
        
        // Sauvegarde physique pour que l'app s'en souvienne au prochain démarrage
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    func logout() {
        print("🔒 [SessionManager] Fermeture de la session et nettoyage...")
        
        self.token = nil
        self.currentUser = nil
        self.isLoggedIn = false
        
        // Suppression physique du token
        UserDefaults.standard.removeObject(forKey: tokenKey)
        
        // Nettoyage optionnel des cookies de session
        URLCache.shared.removeAllCachedResponses()
    }
}
