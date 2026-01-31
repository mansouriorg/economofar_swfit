import SwiftUI
import Combine

class SessionManager: ObservableObject {
    // Si @Published change, toute l'interface se met à jour automatiquement
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    
    // ✅ NOUVEAU : État de chargement initial (pour le Splash Screen)
    @Published var isLoading: Bool = true
    
    init() {
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        // ICI: Plus tard, on vérifiera le Token dans le Keychain
        
        // ✅ MISE À JOUR : On simule un délai de chargement de 2 secondes
        // Cela permet d'afficher le Splash Screen avant de décider si on montre le Login ou le Dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Pour l'instant, on force "non connecté" après le chargement
            self.isLoggedIn = false
            
            // Le chargement est terminé, l'interface va changer
            self.isLoading = false
        }
    }
    
    func login(user: User) {
        // Appelé quand le login réussit
        self.currentUser = user
        self.isLoggedIn = true
    }
    
    func logout() {
        // Appelé quand on clique sur "Se déconnecter"
        self.currentUser = nil
        self.isLoggedIn = false
    }
}
