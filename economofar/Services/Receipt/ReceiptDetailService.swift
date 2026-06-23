import Foundation

final class ReceiptDetailService {

    static let shared = ReceiptDetailService()

    /**
     Simulator:
     */
    private let baseURL = "http://localhost:8080/api/v1/receipts"

    /**
     Real iPhone:
     Replace localhost with your Mac IP, for example:
     private let baseURL = "http://192.168.1.20:8080/api/v1/receipts"
     */

    private init() {}

    // MARK: - Receipt Detail

    func getReceiptDetail(
        receiptId: UUID,
        token: String
    ) async throws -> ReceiptDetailResponse {
        let request = try makeRequest(
            path: "/\(receiptId.uuidString)",
            method: "GET",
            token: token
        )

        return try await perform(
            request,
            responseType: ReceiptDetailResponse.self
        )
    }

    func updateReceiptDetail(
        receiptId: UUID,
        requestBody: ReceiptDetailUpdateRequest,
        token: String
    ) async throws -> ReceiptDetailResponse {
        var request = try makeRequest(
            path: "/\(receiptId.uuidString)",
            method: "PUT",
            token: token
        )

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        return try await perform(
            request,
            responseType: ReceiptDetailResponse.self
        )
    }

    func deleteReceipt(
        receiptId: UUID,
        token: String
    ) async throws {
        let request = try makeRequest(
            path: "/\(receiptId.uuidString)",
            method: "DELETE",
            token: token
        )

        try await performEmpty(request)
    }

    func duplicateReceipt(
        receiptId: UUID,
        token: String
    ) async throws -> ReceiptDetailResponse {
        let request = try makeRequest(
            path: "/\(receiptId.uuidString)/duplicate",
            method: "POST",
            token: token
        )

        return try await perform(
            request,
            responseType: ReceiptDetailResponse.self
        )
    }

    // MARK: - Items

    func addItem(
        receiptId: UUID,
        item: ReceiptItemDetailRequest,
        token: String
    ) async throws -> ReceiptItemDetailResponse {
        var request = try makeRequest(
            path: "/\(receiptId.uuidString)/items",
            method: "POST",
            token: token
        )

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(item)

        return try await perform(
            request,
            responseType: ReceiptItemDetailResponse.self
        )
    }

    func updateItem(
        receiptId: UUID,
        itemId: UUID,
        item: ReceiptItemDetailRequest,
        token: String
    ) async throws -> ReceiptItemDetailResponse {
        var request = try makeRequest(
            path: "/\(receiptId.uuidString)/items/\(itemId.uuidString)",
            method: "PUT",
            token: token
        )

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(item)

        return try await perform(
            request,
            responseType: ReceiptItemDetailResponse.self
        )
    }

    func deleteItem(
        receiptId: UUID,
        itemId: UUID,
        token: String
    ) async throws {
        let request = try makeRequest(
            path: "/\(receiptId.uuidString)/items/\(itemId.uuidString)",
            method: "DELETE",
            token: token
        )

        try await performEmpty(request)
    }

    // MARK: - Exports

    func downloadReceiptPdf(
        receiptId: UUID,
        token: String
    ) async throws -> URL {
        let request = try makeRequest(
            path: "/\(receiptId.uuidString)/pdf",
            method: "GET",
            token: token
        )

        return try await performFileDownload(
            request,
            filename: "economofar-receipt-\(receiptId.uuidString).pdf"
        )
    }

    func exportAccountantCsv(
        receiptId: UUID,
        token: String
    ) async throws -> URL {
        let request = try makeRequest(
            path: "/\(receiptId.uuidString)/accountant-export/csv",
            method: "GET",
            token: token
        )

        return try await performFileDownload(
            request,
            filename: "economofar-accountant-receipt-\(receiptId.uuidString).csv"
        )
    }

    // MARK: - Helpers

    private func makeRequest(
        path: String,
        method: String,
        token: String
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw ReceiptDetailServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("📡 [ReceiptDetailService] URL: \(url.absoluteString)")

        return request
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptDetailServiceError.invalidResponse
        }

        print("📡 [ReceiptDetailService] HTTP Status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodeBackendError(from: data)

            throw ReceiptDetailServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "No response body"

            throw ReceiptDetailServiceError.decodingFailed(
                """
                \(error.localizedDescription)

                Backend response:
                \(rawResponse)
                """
            )
        }
    }

    private func performEmpty(_ request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptDetailServiceError.invalidResponse
        }

        print("📡 [ReceiptDetailService] Empty HTTP Status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodeBackendError(from: data)

            throw ReceiptDetailServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }

    private func performFileDownload(
        _ request: URLRequest,
        filename: String
    ) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptDetailServiceError.invalidResponse
        }

        print("📥 [ReceiptDetailService] File download status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodeBackendError(from: data)

            throw ReceiptDetailServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            throw ReceiptDetailServiceError.fileSaveFailed(error.localizedDescription)
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

            if let path = json["path"] as? String {
                return "Erreur serveur sur \(path)"
            }
        }

        return String(data: data, encoding: .utf8) ?? "Unknown backend error"
    }
}

// MARK: - Error

enum ReceiptDetailServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case backendError(statusCode: Int, message: String)
    case decodingFailed(String)
    case fileSaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL détail reçu invalide."

        case .invalidResponse:
            return "Réponse serveur invalide."

        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"

        case .decodingFailed(let message):
            return "Erreur de lecture du reçu: \(message)"

        case .fileSaveFailed(let message):
            return "Impossible d’enregistrer le fichier exporté: \(message)"
        }
    }
}
