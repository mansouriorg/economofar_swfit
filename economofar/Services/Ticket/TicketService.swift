import Foundation
import Combine
import UIKit

@MainActor
final class TicketService: ObservableObject {

    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    /**
     Used by DashboardView to open the validation sheet.
     After upload, backend returns rawOcrText inside TicketUploadResponse.
     */
    @Published var lastScanResult: String? = nil

    /**
     New scan status tracking.
     */
    @Published var activeTicketId: String? = nil
    @Published var scanStatus: TicketScanStatus = .idle
    @Published var scanStatusMessage: String? = nil

    var onUnauthorized: (() -> Void)?

    /**
     Simulator:
     */
    private let baseURL = "http://localhost:8080/api/v1/tickets"

    /**
     Real iPhone:
     Replace localhost with your Mac IP, for example:
     private let baseURL = "http://192.168.1.20:8080/api/v1/tickets"
     */

    private let scanStatusService: TicketScanStatusService
    private var pollingTask: Task<Void, Never>?

    init(scanStatusService: TicketScanStatusService = .shared) {
        self.scanStatusService = scanStatusService
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - 1. Fetch History

    func fetchTickets(token: String) {
        Task {
            await fetchTicketsAsync(token: token)
        }
    }

    private func fetchTicketsAsync(token: String) async {
        print("📡 [TicketService] Fetching history...")

        guard let url = URL(string: "\(baseURL)/history") else {
            errorMessage = TicketServiceError.invalidURL.localizedDescription
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        isLoading = true
        errorMessage = nil

        do {
            let loadedTickets: [Ticket] = try await perform(
                request,
                responseType: [Ticket].self
            )

            tickets = loadedTickets
            print("✅ [TicketService] \(loadedTickets.count) tickets loaded.")

        } catch {
            print("❌ [TicketService] Fetch error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 2. Upload & OCR Analysis

    func uploadTicket(image: UIImage, token: String) {
        Task {
            await uploadTicketAsync(image: image, token: token)
        }
    }

    private func uploadTicketAsync(image: UIImage, token: String) async {
        print("🚀 [TicketService] Uploading ticket image...")

        guard let url = URL(string: "\(baseURL)/upload") else {
            errorMessage = TicketServiceError.invalidURL.localizedDescription
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            errorMessage = TicketServiceError.invalidImage.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        lastScanResult = nil
        scanStatusMessage = nil
        scanStatus = .uploading
        activeTicketId = nil

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = createMultipartBody(
            imageData: imageData,
            boundary: boundary,
            fileName: "receipt.jpg",
            fieldName: "file"
        )

        do {
            let uploadResponse: TicketUploadResponse = try await perform(
                request,
                responseType: TicketUploadResponse.self
            )

            activeTicketId = uploadResponse.ticketId
            scanStatus = uploadResponse.scanStatus ?? .needsReview
            scanStatusMessage = uploadResponse.message ?? uploadResponse.scanErrorMessage

            if let rawOcrText = uploadResponse.rawOcrText,
               !rawOcrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lastScanResult = rawOcrText
            }

            if scanStatus == .ocrCompleted {
                scanStatus = .needsReview
            }

            print("✅ [TicketService] Upload response received.")
            print("🧾 Ticket ID: \(activeTicketId ?? "nil")")
            print("📍 Scan status: \(scanStatus.rawValue)")

            if let ticketId = uploadResponse.ticketId,
               scanStatus == .uploading || scanStatus == .analyzing {
                startPollingScanStatus(ticketId: ticketId, token: token)
            }

        } catch {
            print("❌ [TicketService] Upload error: \(error.localizedDescription)")
            scanStatus = .failed
            scanStatusMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }

        isLoading = scanStatus.isLoading
    }

    // MARK: - 3. Save Final Validated Ticket With Editable Items

    func saveValidatedTicket(
        merchant: String,
        amount: Double,
        purchaseDate: String?,
        category: String?,
        items: [EditableTicketItemRequest],
        rawOcr: String,
        token: String
    ) {
        Task {
            await saveValidatedTicketAsync(
                merchant: merchant,
                amount: amount,
                purchaseDate: purchaseDate,
                category: category,
                items: items,
                rawOcr: rawOcr,
                token: token
            )
        }
    }

    /**
     Compatibility method for your current ResultView.
     Keeps old calls working until we update the UI to send editable items.
     */
    func saveValidatedTicket(
        merchant: String,
        amount: Double,
        rawOcr: String,
        token: String
    ) {
        saveValidatedTicket(
            merchant: merchant,
            amount: amount,
            purchaseDate: ISO8601DateFormatter().string(from: Date()),
            category: "Alimentation",
            items: [],
            rawOcr: rawOcr,
            token: token
        )
    }

    private func saveValidatedTicketAsync(
        merchant: String,
        amount: Double,
        purchaseDate: String?,
        category: String?,
        items: [EditableTicketItemRequest],
        rawOcr: String,
        token: String
    ) async {
        print("💾 [TicketService] Saving validated editable ticket...")

        guard let url = URL(string: "\(baseURL)/scan") else {
            errorMessage = TicketServiceError.invalidURL.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil

        let cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = SaveValidatedTicketRequest(
            merchantName: cleanMerchant.isEmpty ? "Commerçant inconnu" : cleanMerchant,
            totalAmount: amount,
            purchaseDate: purchaseDate ?? ISO8601DateFormatter().string(from: Date()),
            category: category ?? "Alimentation",
            imageUrl: nil,
            rawOcrText: rawOcr,
            items: items
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = try JSONEncoder().encode(payload)

            let savedTicket: Ticket = try await perform(
                request,
                responseType: Ticket.self
            )

            scanStatus = .saved
            scanStatusMessage = "Ticket sauvegardé"
            lastScanResult = nil
            activeTicketId = savedTicket.id.uuidString

            print("✅ [TicketService] Saved successfully. Ticket ID: \(savedTicket.id.uuidString)")

            await fetchTicketsAsync(token: token)

        } catch {
            print("❌ [TicketService] Save error: \(error.localizedDescription)")
            scanStatus = .failed
            scanStatusMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 4. Restore Active Scan

    func restoreActiveScan(token: String) {
        Task {
            await restoreActiveScanAsync(token: token)
        }
    }

    private func restoreActiveScanAsync(token: String) async {
        print("🔄 [TicketService] Checking active scan...")

        do {
            guard let activeScan = try await scanStatusService.fetchActiveScan(token: token) else {
                print("ℹ️ [TicketService] No active scan.")
                return
            }

            activeTicketId = activeScan.ticketId
            scanStatus = activeScan.scanStatus ?? .idle
            scanStatusMessage = activeScan.scanErrorMessage

            print("📍 [TicketService] Active scan restored: \(scanStatus.rawValue)")

            if let ticketId = activeScan.ticketId,
               scanStatus == .uploading || scanStatus == .analyzing {
                startPollingScanStatus(ticketId: ticketId, token: token)
            }

        } catch {
            print("❌ [TicketService] Restore active scan error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 5. Poll Scan Status

    func startPollingScanStatus(ticketId: String, token: String) {
        pollingTask?.cancel()

        pollingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            print("⏱️ [TicketService] Polling scan status for ticket: \(ticketId)")

            for _ in 0..<30 {
                if Task.isCancelled {
                    return
                }

                do {
                    let response = try await self.scanStatusService.fetchScanStatus(
                        ticketId: ticketId,
                        token: token
                    )

                    self.activeTicketId = response.ticketId
                    self.scanStatus = response.scanStatus ?? self.scanStatus
                    self.scanStatusMessage = response.scanErrorMessage
                    self.isLoading = self.scanStatus.isLoading

                    print("📍 [TicketService] Polled status: \(self.scanStatus.rawValue)")

                    if let status = response.scanStatus, status.isFinal {
                        print("✅ [TicketService] Polling finished with status: \(status.rawValue)")
                        return
                    }

                    try await Task.sleep(nanoseconds: 1_000_000_000)

                } catch {
                    print("❌ [TicketService] Polling error: \(error.localizedDescription)")

                    self.errorMessage = error.localizedDescription
                    self.scanStatus = .failed
                    self.scanStatusMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
            }

            self.isLoading = false
            print("⏹️ [TicketService] Polling stopped after timeout.")
        }
    }

    func stopPollingScanStatus() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - 6. Helpers

    private func createMultipartBody(
        imageData: Data,
        boundary: String,
        fileName: String,
        fieldName: String
    ) -> Data {
        var body = Data()

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        return body
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketServiceError.invalidResponse
        }

        print("📡 [TicketService] HTTP Status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            onUnauthorized?()
            throw TicketServiceError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodeBackendError(from: data)
            throw TicketServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "No response body"

            throw TicketServiceError.decodingFailed(
                """
                \(error.localizedDescription)

                Backend response:
                \(rawResponse)
                """
            )
        }
    }

    private func decodeBackendError(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String {
                return message
            }

            if let error = json["error"] as? String {
                return error
            }

            if let detail = json["detail"] as? String {
                return detail
            }

            if let scanErrorMessage = json["scanErrorMessage"] as? String {
                return scanErrorMessage
            }
        }

        return String(data: data, encoding: .utf8) ?? "Unknown backend error"
    }
}

// MARK: - Save Request

struct SaveValidatedTicketRequest: Codable {
    let merchantName: String
    let totalAmount: Double
    let purchaseDate: String?
    let category: String?
    let imageUrl: String?
    let rawOcrText: String?
    let items: [EditableTicketItemRequest]
}

// MARK: - Data Extension

private extension Data {
    mutating func appendString(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
    }
}

// MARK: - Error

enum TicketServiceError: LocalizedError {
    case invalidURL
    case invalidImage
    case invalidResponse
    case unauthorized
    case backendError(statusCode: Int, message: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL ticket invalide."

        case .invalidImage:
            return "Image invalide."

        case .invalidResponse:
            return "Réponse serveur invalide."

        case .unauthorized:
            return "Session expirée. Veuillez vous reconnecter."

        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"

        case .decodingFailed(let message):
            return "Erreur de lecture des données ticket: \(message)"
        }
    }
}
