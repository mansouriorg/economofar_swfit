import Foundation
import SwiftUI
import Combine

class AuthService: ObservableObject {
    
    // 👇 REMPLACE "localhost" PAR TON ADRESSE IP SI TU UTILISES UN VRAI IPHONE
    // Ex: "http://192.168.1.15:8080/api/auth"
    static var baseURL: String { AppConfig.baseURL + "/api/auth" }
    
    @Published var isAuthenticated = false
    @Published var isRegistered = false // ✅ NOUVEAU : Pour savoir si l'inscription a réussi
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    private let tokenKey = "jwt_token"

    init() {
        // Au démarrage, on vérifie si on a déjà un token
        self.isAuthenticated = KeychainManager.loadToken() != nil
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
        KeychainManager.deleteToken()
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
                    self.errorMessage = AuthService.friendlyError(statusCode: httpResponse.statusCode, data: data)
                    
                    // Si le serveur renvoie un message d'erreur spécifique (comme "Email déjà pris")
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                         print("Erreur Serveur: \(errorString)")
                         // Tu pourrais parser le JSON d'erreur ici si tu veux être plus précis
                    }
                }
            }
        }.resume()
    }
    
    /// Readable error for the login / register screens (reads the backend "message" field).
    static func friendlyError(statusCode: Int, data: Data?) -> String {
        if let data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String,
           !message.isEmpty {
            return message
        }

        switch statusCode {
        case 401:
            return "Email ou mot de passe incorrect."
        case 409:
            return "Un compte existe déjà avec cet email."
        case 429:
            return "Trop de tentatives. Réessayez dans quelques minutes."
        case 500...599:
            return "Le serveur ne répond pas correctement. Réessayez plus tard."
        default:
            return "Échec (Code: \(statusCode))"
        }
    }

    private func saveToken(_ token: String) {
        KeychainManager.saveToken(token)
        self.isAuthenticated = true
        self.errorMessage = ""
    }
    
    // Fonction utilitaire statique pour récupérer le token n'importe où dans l'app
    static func getToken() -> String? {
        return KeychainManager.loadToken()
    }
}
