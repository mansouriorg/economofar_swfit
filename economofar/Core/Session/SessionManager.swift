import SwiftUI
import Combine

class SessionManager: ObservableObject {
    // Si @Published change, toute l'interface se met à jour automatiquement
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    
    // ✅ NEW: Stocker le token pour les appels API
    @Published var token: String?
    
    // État de chargement initial (pour le Splash Screen)
    @Published var isLoading: Bool = true
    
    init() {
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        // ICI: Plus tard, on vérifiera le Token dans le Keychain
        
        // Simulation d'un délai de chargement de 2 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Pour l'instant, on force "non connecté" après le chargement
            self.isLoggedIn = false
            self.isLoading = false
        }
    }
    
    // ✅ UPDATE: On accepte le token ici
    func login(user: User, token: String) {
        self.currentUser = user
        self.token = token // On sauvegarde le token
        self.isLoggedIn = true
    }
    
    func logout() {
        // Appelé quand on clique sur "Se déconnecter"
        self.currentUser = nil
        self.token = nil // On efface le token
        self.isLoggedIn = false
    }
}
