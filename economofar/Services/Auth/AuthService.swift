import Foundation
import SwiftUI
import Combine

class AuthService: ObservableObject {
    
    // 👇 REMPLACE "localhost" PAR TON ADRESSE IP SI TU UTILISES UN VRAI IPHONE
    // Ex: "http://192.168.1.15:8080/api/auth"
    static let baseURL = "http://localhost:8080/api/auth"
    
    @Published var isAuthenticated = false
    @Published var isRegistered = false // ✅ NOUVEAU : Pour savoir si l'inscription a réussi
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    private let tokenKey = "jwt_token"

    init() {
        // Au démarrage, on vérifie si on a déjà un token
        self.isAuthenticated = UserDefaults.standard.string(forKey: tokenKey) != nil
    }

    // --- Actions ---

    func login(email: String, password: String) {
        isLoading = true
        let body = LoginRequest(email: email, password: password)
        
        // Pour le Login, si ça marche, on SAUVEGARDE le token
        performAuth(endpoint: "/authenticate", body: body) { token in
            self.saveToken(token)
        }
    }

    func register(firstName: String, lastName: String, email: String, password: String) {
        isLoading = true
        let body = RegisterRequest(firstName: firstName, lastName: lastName, email: email, password: password)
        
        // Pour l'Inscription, si ça marche, on active juste isRegistered (pas de sauvegarde de token)
        performAuth(endpoint: "/register", body: body) { token in
            DispatchQueue.main.async {
                self.isRegistered = true // Cela déclenchera la fermeture de la vue Register
                self.errorMessage = ""
            }
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
    
    // --- Moteur Réseau Interne ---

    // J'ai ajouté le paramètre 'onSuccess' pour décider quoi faire du token (Sauvegarder OU juste dire OK)
    private func performAuth<T: Codable>(endpoint: String, body: T, onSuccess: @escaping (String) -> Void) {
        guard let url = URL(string: AuthService.baseURL + endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Erreur encodage données"
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Erreur réseau: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Erreur serveur inconnue"
                    return
                }

                if httpResponse.statusCode == 200, let data = data {
                    // Succès !
                    do {
                        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                        // On exécute l'action de succès spécifique (Login ou Register)
                        onSuccess(authResponse.token)
                    } catch {
                        self.errorMessage = "Erreur lecture réponse"
                    }
                } else {
                    // Échec
                    self.errorMessage = "Échec (Code: \(httpResponse.statusCode))"
                    
                    // Si le serveur renvoie un message d'erreur spécifique (comme "Email déjà pris")
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                         print("Erreur Serveur: \(errorString)")
                         // Tu pourrais parser le JSON d'erreur ici si tu veux être plus précis
                    }
                }
            }
        }.resume()
    }
    
    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        self.isAuthenticated = true
        self.errorMessage = ""
    }
    
    // Fonction utilitaire statique pour récupérer le token n'importe où dans l'app
    static func getToken() -> String? {
        return UserDefaults.standard.string(forKey: "jwt_token")
    }
}
