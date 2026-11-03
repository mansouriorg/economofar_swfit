import SwiftUI

/// Lets the user point the app to the API server.
/// Needed on a real iPhone, where "localhost" is the phone itself, not the Mac.
struct ServerSettingsView: View {
    @State private var serverText: String = AppConfig.isUsingDefaultServer ? "" : AppConfig.baseURL
    @State private var statusMessage: String? = nil
    @State private var statusIsError = false
    @State private var isTesting = false

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Adresse du serveur")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)

                        Text("Sur le simulateur, laissez ce champ vide (http://localhost:8080). Sur un vrai iPhone, entrez l’adresse IP de votre Mac, par exemple http://192.168.1.20:8080")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("URL du serveur", systemImage: "server.rack")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)

                        TextField("http://192.168.1.20:8080", text: $serverText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                            .padding()
                            .background(EconomofarUI.cardSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(EconomofarUI.border, lineWidth: 1)
                            }
                    }

                    Text("Serveur actuel : \(AppConfig.baseURL)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)

                    if let statusMessage {
                        DashboardInfoBanner(
                            icon: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                            message: statusMessage,
                            tint: statusIsError ? EconomofarUI.danger : EconomofarUI.success,
                            background: statusIsError ? EconomofarUI.dangerSoft : EconomofarUI.successSoft
                        )
                    }

                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isTesting {
                                ProgressView()
                            } else {
                                Image(systemName: "bolt.horizontal.circle")
                            }

                            Text("Tester la connexion")
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(EconomofarUI.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isTesting)

                    Button {
                        save()
                    } label: {
                        Text("Enregistrer")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(EconomofarUI.mainGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        serverText = ""
                        AppConfig.setBaseURL(nil)
                        show("Adresse réinitialisée : \(AppConfig.defaultBaseURL)", isError: false)
                    } label: {
                        Text("Revenir à localhost")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Serveur")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func show(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }

    private func save() {
        let trimmed = serverText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            AppConfig.setBaseURL(nil)
            show("Adresse réinitialisée : \(AppConfig.defaultBaseURL)", isError: false)
            return
        }

        guard let normalized = AppConfig.normalizedServerURL(from: trimmed) else {
            show("Adresse invalide. Exemple : http://192.168.1.20:8080", isError: true)
            return
        }

        AppConfig.setBaseURL(normalized)
        serverText = normalized
        show("Adresse enregistrée : \(normalized)", isError: false)
    }

    private func testConnection() async {
        let trimmed = serverText.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: String

        if trimmed.isEmpty {
            target = AppConfig.defaultBaseURL
        } else if let normalized = AppConfig.normalizedServerURL(from: trimmed) {
            target = normalized
        } else {
            show("Adresse invalide. Exemple : http://192.168.1.20:8080", isError: true)
            return
        }

        guard let url = URL(string: target + "/api/auth/ping") else {
            show("Adresse invalide.", isError: true)
            return
        }

        isTesting = true
        defer { isTesting = false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6

        do {
            // Any HTTP answer (even 404) proves that the server is reachable
            let (_, response) = try await URLSession.shared.data(for: request)

            if response is HTTPURLResponse {
                show("Serveur joignable : \(target)", isError: false)
            } else {
                show("Réponse inattendue du serveur.", isError: true)
            }
        } catch {
            show("Serveur injoignable : \(error.localizedDescription)", isError: true)
        }
    }
}
