import Foundation

final class TicketHistoryService {

    static let shared = TicketHistoryService()

    /**
     Simulator:
     */
    private var baseURL: String { AppConfig.baseURL + "/api/v1/tickets" }

    /**
     Real iPhone:
     Replace localhost with your Mac IP, for example:
     private let baseURL = "http://192.168.1.20:8080/api/v1/tickets"
     */

    private init() {}

    // MARK: - Search History

    func searchHistory(
        filter: TicketHistoryFilter,
        token: String
    ) async throws -> [TicketHistoryReceipt] {
        let request = try makeRequest(
            path: "/history/search",
            queryItems: filter.queryItems,
            method: "GET",
            token: token
        )

        return try await perform(
            request,
            responseType: [TicketHistoryReceipt].self
        )
    }

    // MARK: - Grouped History

    func groupedHistory(
        filter: TicketHistoryFilter,
        token: String
    ) async throws -> [TicketHistoryGroup] {
        let request = try makeRequest(
            path: "/history/grouped",
            queryItems: filter.groupedQueryItems,
            method: "GET",
            token: token
        )

        return try await perform(
            request,
            responseType: [TicketHistoryGroup].self
        )
    }

    // MARK: - Monthly Report JSON

    func monthlyReport(
        month: String,
        token: String
    ) async throws -> TicketMonthlyReport {
        let queryItems = [
            URLQueryItem(name: "month", value: month)
        ]

        let request = try makeRequest(
            path: "/export/monthly/report",
            queryItems: queryItems,
            method: "GET",
            token: token
        )

        return try await perform(
            request,
            responseType: TicketMonthlyReport.self
        )
    }

    // MARK: - Export CSV / PDF

    func exportCsv(
        filter: TicketHistoryFilter,
        token: String
    ) async throws -> URL {
        let request = try makeRequest(
            path: "/export/csv",
            queryItems: filter.queryItems,
            method: "GET",
            token: token
        )

        return try await performFileDownload(
            request,
            filename: "economofar-history.csv"
        )
    }

    func exportPdf(
        filter: TicketHistoryFilter,
        token: String
    ) async throws -> URL {
        let request = try makeRequest(
            path: "/export/pdf",
            queryItems: filter.queryItems,
            method: "GET",
            token: token
        )

        return try await performFileDownload(
            request,
            filename: "economofar-history.pdf"
        )
    }

    func exportMonthlyCsv(
        month: String,
        token: String
    ) async throws -> URL {
        let queryItems = [
            URLQueryItem(name: "month", value: month)
        ]

        let request = try makeRequest(
            path: "/export/monthly/csv",
            queryItems: queryItems,
            method: "GET",
            token: token
        )

        return try await performFileDownload(
            request,
            filename: "economofar-monthly-\(month).csv"
        )
    }

    func exportMonthlyPdf(
        month: String,
        token: String
    ) async throws -> URL {
        let queryItems = [
            URLQueryItem(name: "month", value: month)
        ]

        let request = try makeRequest(
            path: "/export/monthly/pdf",
            queryItems: queryItems,
            method: "GET",
            token: token
        )

        return try await performFileDownload(
            request,
            filename: "economofar-monthly-\(month).pdf"
        )
    }

    // MARK: - Helpers

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem],
        method: String,
        token: String
    ) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw TicketHistoryServiceError.invalidURL
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw TicketHistoryServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("📡 [TicketHistoryService] URL: \(url.absoluteString)")

        return request
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketHistoryServiceError.invalidResponse
        }

        print("📡 [TicketHistoryService] HTTP Status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodeBackendError(from: data)

            throw TicketHistoryServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "No response body"

            throw TicketHistoryServiceError.decodingFailed(
                """
                \(error.localizedDescription)

                Backend response:
                \(rawResponse)
                """
            )
        }
    }

    private func performFileDownload(
        _ request: URLRequest,
        filename: String
    ) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketHistoryServiceError.invalidResponse
        }

        print("📥 [TicketHistoryService] File download status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodeBackendError(from: data)

            throw TicketHistoryServiceError.backendError(
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
            throw TicketHistoryServiceError.fileSaveFailed(error.localizedDescription)
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

enum TicketHistoryServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case backendError(statusCode: Int, message: String)
    case decodingFailed(String)
    case fileSaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL historique invalide."

        case .invalidResponse:
            return "Réponse serveur invalide."

        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"

        case .decodingFailed(let message):
            return "Erreur de lecture de l’historique: \(message)"

        case .fileSaveFailed(let message):
            return "Impossible d’enregistrer le fichier exporté: \(message)"
        }
    }
}
