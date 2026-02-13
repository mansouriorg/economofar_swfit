import Foundation
import Combine
import UIKit

// ✅ Mark the entire class as MainActor to ensure all published property updates happen on the main thread automatically.
@MainActor
class TicketService: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var lastScanResult: String? = nil
    
    var onUnauthorized: (() -> Void)?
    
    // ⚠️ Replace with your local IP if testing on a real device
    private let baseURL = "http://localhost:8080/api/v1/tickets"
    
    // MARK: - 1. Fetch History
    func fetchTickets(token: String) {
        print("📡 [TicketService] Fetching history...")
        guard let url = URL(string: "\(baseURL)/history") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        self.isLoading = true
        self.errorMessage = nil
        
        // Use Task for modern concurrency
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                self.isLoading = false
                
                guard let httpResponse = response as? HTTPURLResponse else { return }
                
                if (401...403).contains(httpResponse.statusCode) {
                    print("⚠️ [TicketService] Unauthorized. Logging out.")
                    self.onUnauthorized?()
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    self.tickets = try decoder.decode([Ticket].self, from: data)
                    print("✅ [TicketService] \(self.tickets.count) tickets loaded.")
                } else {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                }
            } catch {
                self.isLoading = false
                print("❌ [TicketService] Fetch error: \(error)")
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - 2. Upload & Analysis
    func uploadTicket(image: UIImage, token: String) {
        print("🚀 [TicketService] Uploading to Ollama...")
        guard let url = URL(string: "\(baseURL)/upload") else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.6) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let fileName = "receipt.jpg"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        self.isLoading = true
        self.lastScanResult = nil
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                self.isLoading = false
                
                guard let httpResponse = response as? HTTPURLResponse else { return }
                print("📡 [TicketService] Upload Status: \(httpResponse.statusCode)")
                
                if (401...403).contains(httpResponse.statusCode) {
                    self.onUnauthorized?()
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("✨ [TicketService] AI Response received.")
                    self.lastScanResult = responseString
                }
            } catch {
                self.isLoading = false
                print("❌ [TicketService] Upload error: \(error)")
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - 3. Save Final Ticket
    func saveValidatedTicket(merchant: String, amount: Double, rawOcr: String, token: String) {
        print("💾 [TicketService] Saving validated ticket...")
        guard let url = URL(string: "\(baseURL)/scan") else { return }
        
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
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        self.isLoading = true
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                self.isLoading = false
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("✅ [TicketService] Saved successfully!")
                    self.lastScanResult = nil
                    self.fetchTickets(token: token) // Refresh list
                } else {
                    self.errorMessage = "Save failed."
                }
            } catch {
                self.isLoading = false
                print("❌ [TicketService] Save error: \(error)")
            }
        }
    }
}
