import SwiftUI
import UIKit

struct AuthenticatedAsyncImage<Content: View>: View {
    private let url: URL?
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await load()
            }
    }

    @MainActor
    private func load() async {
        guard let url else {
            phase = .empty
            return
        }

        let target = ServerAddress.inServer(url)

        var request = URLRequest(url: target)
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        if ServerAddress.isServer(target), let token = KeychainManager.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                phase = .failure(URLError(.badServerResponse))
                return
            }

            phase = .success(Image(uiImage: image))
        } catch {
            if Task.isCancelled == false {
                phase = .failure(error)
            }
        }
    }
}

private enum ServerAddress {

    static func isServer(_ url: URL) -> Bool {
        guard let server = URLComponents(string: AppConfig.baseURL),
              let candidate = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        return origin(of: server) == origin(of: candidate)
    }

    static func inServer(_ url: URL) -> URL {
        guard isServer(url) == false,
              url.path.hasPrefix("/uploads/"),
              var components = URLComponents(string: AppConfig.baseURL) else {
            return url
        }

        components.path = url.path

        return components.url ?? url
    }

    private static func origin(of components: URLComponents) -> String {
        let scheme = components.scheme?.lowercased() ?? ""
        let host = components.host?.lowercased() ?? ""
        let port = components.port ?? (scheme == "https" ? 443 : 80)

        return "\(scheme)://\(host):\(port)"
    }
}
