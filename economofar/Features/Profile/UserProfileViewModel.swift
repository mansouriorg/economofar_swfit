import Foundation
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {

    @Published var profile: UserProfileResponse?

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var companyName: String = ""
    @Published var preferredCurrency: String = "EUR"
    @Published var language: String = "fr"

    @Published var currentPassword: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""

    @Published var isLoading = false
    @Published var isSavingProfile = false
    @Published var isSavingPassword = false

    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var shouldLogout = false

    private let service: UserProfileService

    init(service: UserProfileService = .shared) {
        self.service = service
    }

    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let loadedProfile = try await service.fetchProfile()
            profile = loadedProfile
            fillForm(with: loadedProfile)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func saveProfile() async {
        let cleanFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCompany = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCurrency = preferredCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanFirstName.isEmpty else {
            errorMessage = "Veuillez saisir votre prénom."
            return
        }

        guard !cleanLastName.isEmpty else {
            errorMessage = "Veuillez saisir votre nom."
            return
        }

        guard isValidEmail(cleanEmail) else {
            errorMessage = "Veuillez saisir un email valide."
            return
        }

        guard cleanCurrency.count == 3 else {
            errorMessage = "La devise doit contenir 3 lettres, par exemple EUR."
            return
        }

        guard ["fr", "en", "ar"].contains(cleanLanguage) else {
            errorMessage = "Langue invalide. Choisissez fr, en ou ar."
            return
        }

        isSavingProfile = true
        errorMessage = nil
        successMessage = nil

        do {
            let request = UpdateUserProfileRequest(
                firstName: cleanFirstName,
                lastName: cleanLastName,
                email: cleanEmail,
                companyName: cleanCompany.isEmpty ? nil : cleanCompany,
                preferredCurrency: cleanCurrency,
                language: cleanLanguage
            )

            let updatedProfile = try await service.updateProfile(request)

            profile = updatedProfile
            fillForm(with: updatedProfile)

            if let currency = updatedProfile.preferredCurrency, !currency.isEmpty {
                UserDefaults.standard.set(currency, forKey: AppStorageKeys.preferredCurrency)
            }

            if let language = updatedProfile.language, !language.isEmpty {
                UserDefaults.standard.set(language, forKey: AppStorageKeys.preferredLanguage)
            }

            if updatedProfile.requiresReLogin {
                successMessage = "Profil mis à jour. Veuillez vous reconnecter."
                shouldLogout = true
            } else {
                successMessage = "Profil mis à jour avec succès."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSavingProfile = false
    }

    func savePassword() async {
        let cleanCurrent = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanCurrent.isEmpty else {
            errorMessage = "Veuillez saisir votre mot de passe actuel."
            return
        }

        guard cleanNew.count >= 8 else {
            errorMessage = "Le nouveau mot de passe doit contenir au moins 8 caractères."
            return
        }

        guard cleanNew == cleanConfirm else {
            errorMessage = "Les deux nouveaux mots de passe ne correspondent pas."
            return
        }

        guard cleanCurrent != cleanNew else {
            errorMessage = "Le nouveau mot de passe doit être différent de l’ancien."
            return
        }

        isSavingPassword = true
        errorMessage = nil
        successMessage = nil

        do {
            let request = UpdatePasswordRequest(
                currentPassword: cleanCurrent,
                newPassword: cleanNew,
                confirmPassword: cleanConfirm
            )

            let response = try await service.updatePassword(request)

            currentPassword = ""
            newPassword = ""
            confirmPassword = ""

            successMessage = response.message

            if response.requiresReLogin {
                shouldLogout = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSavingPassword = false
    }

    private func fillForm(with profile: UserProfileResponse) {
        firstName = profile.firstName ?? ""
        lastName = profile.lastName ?? ""
        email = profile.email ?? ""
        companyName = profile.companyName ?? ""
        preferredCurrency = profile.preferredCurrency ?? "EUR"
        language = profile.language ?? "fr"
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
