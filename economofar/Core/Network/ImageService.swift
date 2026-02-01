import UIKit

// 1. On définit ce qu'on attend comme réponse du serveur (le JSON)
struct ImageUploadResponse: Codable {
    let url: String
    let analysis: String // Le texte de l'IA (LLaVA)
}

class ImageService {
    
    // 2. L'adresse de ton serveur Java
    // Si Simulateur : localhost fonctionne généralement.
    // Si iPhone Réel : Mets l'IP de ton Mac (ex: http://192.168.1.15:8080...)
    static let uploadURL = "http://localhost:8080/api/images/upload"
    
    static func uploadImage(image: UIImage) async throws -> ImageUploadResponse {
        // Vérification de l'URL
        guard let url = URL(string: uploadURL) else { throw URLError(.badURL) }
        
        // Compression de l'image (pour qu'elle ne soit pas trop lourde)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { throw URLError(.cannotDecodeRawData) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 3. Préparation du format "Multipart" (Enveloppe pour fichier)
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"ticket.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 Envoi de l'image au Backend...")
        
        // 4. Envoi réel
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 5. Vérification du succès (Code 200 = OK)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Erreur Serveur")
            throw URLError(.badServerResponse)
        }
        
        print("✅ Réponse reçue du Backend !")
        
        // 6. Décodage de la réponse JSON
        let decodedResponse = try JSONDecoder().decode(ImageUploadResponse.self, from: data)
        return decodedResponse
    }
}
