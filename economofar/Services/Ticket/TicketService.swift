import Foundation
import Combine
import UIKit

class TicketService: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var lastScanResult: String? = nil
    
    // ✅ Action de rappel pour forcer la déconnexion si le token est invalide
    var onUnauthorized: (() -> Void)?
    
    // ⚠️ Rappel : localhost pour simulateur, IP locale (ex: 192.168.1.15) pour iPhone réel.
    private let baseURL = "http://localhost:8080/api/v1/tickets"
    
    // MARK: - 1. Fetch History
    func fetchTickets(token: String) {
        print("📡 [TicketService] Tentative de récupération de l'historique...")
        
        guard let url = URL(string: "\(baseURL)/history") else {
            print("❌ [TicketService] Erreur: URL de l'historique invalide")
            self.errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ [TicketService] Erreur réseau historique: \(error.localizedDescription)")
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ [TicketService] Pas de réponse du serveur pour l'historique")
                    self?.errorMessage = "Server error (No Response)"
                    return
                }
                
                print("📩 [TicketService] Code Status Historique: \(httpResponse.statusCode)")
                
                // ✅ GESTION DU TOKEN EXPIRE / INVALIDE (401 ou 403)
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("⚠️ [TicketService] Token rejeté par le serveur. Déconnexion forcée...")
                    self?.errorMessage = "Session expirée. Veuillez vous reconnecter."
                    self?.onUnauthorized?() // Déclenche le logout dans SessionManager
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self?.errorMessage = "Erreur serveur: \(httpResponse.statusCode)"
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let decoder = JSONDecoder()
                    // Décodeur pour gérer les dates ISO du backend
                    decoder.dateDecodingStrategy = .iso8601
                    let decodedTickets = try decoder.decode([Ticket].self, from: data)
                    print("✅ [TicketService] \(decodedTickets.count) tickets récupérés avec succès")
                    self?.tickets = decodedTickets
                } catch {
                    print("❌ [TicketService] Erreur de décodage JSON: \(error)")
                    self?.errorMessage = "Format de données incorrect."
                }
            }
        }.resume()
    }
    
    // MARK: - 2. Upload & Analysis (Ollama)
    func uploadTicket(image: UIImage, token: String) {
        print("🚀 [TicketService] Démarrage de l'upload vers Ollama...")
        
        guard let url = URL(string: "\(baseURL)/upload") else {
            print("❌ [TicketService] Erreur: URL d'upload invalide")
            self.errorMessage = "Invalid Upload URL"
            return
        }
        
        // 1. Compression de l'image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ [TicketService] Erreur: Échec du traitement de l'image")
            self.errorMessage = "Failed to process image data"
            return
        }
        print("📸 [TicketService] Image préparée: \(imageData.count) octets")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let fileName = "receipt_\(Int(Date().timeIntervalSince1970)).jpg"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.lastScanResult = nil
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ [TicketService] Erreur pendant l'upload: \(error.localizedDescription)")
                    self?.errorMessage = "Upload error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.errorMessage = "No response from server"
                    return
                }
                
                print("📡 [TicketService] Code Status Upload: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    self?.onUnauthorized?()
                    return
                }
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("✨ [TicketService] Réponse reçue d'Ollama: \(responseString)")
                    self?.lastScanResult = responseString
                }
            }
        }.resume()
    }

    // MARK: - 3. Save Final Ticket (BDD)
    /// ✅ NOUVEAU: Appelle /api/v1/tickets/scan pour enregistrer réellement en base
    func saveValidatedTicket(merchant: String, amount: Double, rawOcr: String, token: String) {
        print("💾 [TicketService] Enregistrement définitif en base de données...")
        
        guard let url = URL(string: "\(baseURL)/scan") else { return }
        
        // Corps de la requête correspondant à ton TicketRequest.java
        let body: [String: Any] = [
            "merchantName": merchant,
            "totalAmount": amount,
            "rawOcrText": rawOcr,
            "category": "Alimentation",
            "purchaseDate": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ [TicketService] Erreur JSON Serialization")
            return
        }
        
        DispatchQueue.main.async { self.isLoading = true }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                guard let httpResponse = response as? HTTPURLResponse else { return }
                
                if httpResponse.statusCode == 200 {
                    print("✅ [TicketService] Ticket enregistré avec succès !")
                    // On vide le résultat de l'IA pour fermer la vue
                    self?.lastScanResult = nil
                    // On rafraîchit l'historique du Dashboard
                    self?.fetchTickets(token: token)
                } else {
                    print("❌ [TicketService] Échec de la sauvegarde (Code: \(httpResponse.statusCode))")
                    self?.errorMessage = "Erreur lors de la sauvegarde."
                }
            }
        }.resume()
    }
}
