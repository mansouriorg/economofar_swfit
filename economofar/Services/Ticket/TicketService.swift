import Foundation
import Combine // ✅ This fixes the "@Published" and "ObservableObject" errors

class TicketService: ObservableObject {
    // MARK: - Published Properties (UI Updates)
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Configuration
    // ⚠️ IMPORTANT:
    // - Use "http://localhost:8080" if running on iOS Simulator.
    // - Use your Mac's Local IP (e.g., "http://192.168.1.15:8080") if running on a real iPhone.
    private let baseURL = "http://localhost:8080/api/v1/tickets"
    
    // MARK: - Fetch History
    func fetchTickets(token: String) {
        guard let url = URL(string: "\(baseURL)/history") else {
            self.errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Start Loading
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                // 1. Handle Network Errors
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                // 2. Handle Server Responses
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.errorMessage = "Server error (No Response)"
                    return
                }
                
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    self?.errorMessage = "Session expired. Please log in again."
                    // Optional: Trigger a logout action here if you have a global auth handler
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                    return
                }
                
                // 3. Decode Data
                guard let data = data else { return }
                
                do {
                    let decoder = JSONDecoder()
                    // Setup date decoding strategy if needed, though our Ticket model handles strings manually
                    // decoder.dateDecodingStrategy = .iso8601
                    
                    let decodedTickets = try decoder.decode([Ticket].self, from: data)
                    self?.tickets = decodedTickets
                } catch {
                    print("Decoding Error: \(error)")
                    self?.errorMessage = "Failed to load tickets. Data format mismatch."
                }
            }
        }.resume()
    }
}
