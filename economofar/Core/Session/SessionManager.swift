import Foundation
import SwiftUI
import Combine

class SessionManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var token: String?
    @Published var isLoading: Bool = true

    private var unauthorizedObserver: NSObjectProtocol?

    init() {
        print("🚀 [SessionManager] Initialisation...")

        // Any 401 from the API (expired token) sends the user back to the login screen
        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: .economofarUnauthorized,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isLoggedIn else { return }
            print("🔒 [SessionManager] 401 reçu : session expirée.")
            self.logout()
        }

        checkLoginStatus()
    }

    deinit {
        if let unauthorizedObserver {
            NotificationCenter.default.removeObserver(unauthorizedObserver)
        }
    }

    // MARK: - Session Logic

    func checkLoginStatus() {
        // The token lives in the Keychain (old UserDefaults tokens are migrated automatically)
        if let savedToken = KeychainManager.loadToken(), !savedToken.isEmpty {
            print("🔑 [SessionManager] Token trouvé.")

            self.token = savedToken
            self.isLoggedIn = true

            // Load the profile (first name, email, currency...) in the background
            Task {
                await self.refreshProfile()
            }
        } else {
            print("ℹ️ [SessionManager] Aucun token trouvé au démarrage.")
            self.isLoggedIn = false
        }

        // Keep the splash screen visible for a short moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                self.isLoading = false
            }
            print("🏁 [SessionManager] Chargement initial terminé. isLoggedIn: \(self.isLoggedIn)")
        }
    }

    /// Used by LoginView to synchronise the session after a successful login
    func setSession(token: String, user: User? = nil) {
        print("🔓 [SessionManager] Mise à jour de la session active")

        self.token = token
        self.currentUser = user
        self.isLoggedIn = true

        KeychainManager.saveToken(token)

        if user == nil {
            Task {
                await self.refreshProfile()
            }
        }
    }

    func logout() {
        print("🔒 [SessionManager] Fermeture de la session et nettoyage...")

        self.token = nil
        self.currentUser = nil
        self.isLoggedIn = false

        KeychainManager.deleteToken()

        SmartReminders.clear()

        DailyRoutineReminders.clear()

        WarrantyReminders.clear()

        URLCache.shared.removeAllCachedResponses()
    }

    // MARK: - Profile

    /// Loads /api/profile and fills `currentUser` (greeting, settings screen, support email...).
    @MainActor
    func refreshProfile() async {
        guard let token, !token.isEmpty else { return }

        do {
            let profile: UserProfileResponse = try await APIClient.shared.get(
                Endpoint.profile,
                token: token,
                as: UserProfileResponse.self
            )

            let isAdmin = profile.role?.uppercased().contains("ADMIN") == true

            currentUser = User(
                id: profile.id,
                email: profile.email ?? "",
                firstName: profile.firstName ?? "",
                lastName: profile.lastName ?? "",
                role: isAdmin ? .admin : .staff
            )

            if let currency = profile.preferredCurrency, !currency.isEmpty {
                UserDefaults.standard.set(currency, forKey: AppStorageKeys.preferredCurrency)
            }

            if let language = profile.language, !language.isEmpty {
                UserDefaults.standard.set(language, forKey: AppStorageKeys.preferredLanguage)
            }

            print("👤 [SessionManager] Profil chargé : \(profile.firstName ?? "?")")
        } catch APIError.unauthorized {
            // The 401 notification already logs the user out
        } catch {
            print("⚠️ [SessionManager] Impossible de charger le profil : \(error.localizedDescription)")
        }
    }
}
