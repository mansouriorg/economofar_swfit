import Foundation
import Combine // <--- C'est la ligne qu'il manquait !

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Simulation d'une connexion
    func login(completion: @escaping (User?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // Simulation d'un délai réseau de 1 seconde
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            
            // Validation basique
            if !self.email.isEmpty && !self.password.isEmpty {
                // Succès : On crée un faux utilisateur
                let mockUser = User(
                    id: UUID().uuidString,
                    email: self.email,
                    firstName: "Chef",
                    lastName: "Cuisinier",
                    role: .admin
                )
                completion(mockUser)
            } else {
                // Échec
                self.errorMessage = "Email ou mot de passe invalide."
                completion(nil)
            }
        }
    }
}
