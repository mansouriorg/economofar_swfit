import SwiftUI
import Combine

class SessionManager: ObservableObject {
    // Si @Published change, toute l'interface se met à jour automatiquement
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    
    init() {
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        // ICI: Plus tard, on vérifiera le Token dans le Keychain
        // Pour l'instant, on simule qu'on n'est pas connecté
        self.isLoggedIn = false
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
