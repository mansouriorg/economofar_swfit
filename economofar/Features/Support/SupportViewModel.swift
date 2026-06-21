import Foundation
import Combine

@MainActor
final class SupportViewModel: ObservableObject {

    @Published var faqs: [FaqItem] = []
    @Published var supportConfig: SupportConfig?
    @Published var appStatus: AppStatus?
    @Published var myRequests: [SupportRequestResponse] = []

    @Published var contactSubject: String = ""
    @Published var contactMessage: String = ""
    @Published var bugSubject: String = ""
    @Published var bugMessage: String = ""

    @Published var isLoading = false
    @Published var isSendingContact = false
    @Published var isSendingBug = false

    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let supportService: SupportService

    init(supportService: SupportService = .shared) {
        self.supportService = supportService
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        async let faqsTask = supportService.fetchFaqs()
        async let configTask = supportService.fetchSupportConfig()
        async let statusTask = supportService.fetchAppStatus()

        do {
            faqs = try await faqsTask
            supportConfig = try await configTask
            appStatus = try await statusTask
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMyRequests() async {
        do {
            myRequests = try await supportService.fetchMySupportRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendContact(contactEmail: String?) async {
        let subject = contactSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = contactMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !subject.isEmpty else {
            errorMessage = "Veuillez saisir un sujet."
            return
        }

        guard !message.isEmpty else {
            errorMessage = "Veuillez saisir un message."
            return
        }

        isSendingContact = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await supportService.submitContactSupport(
                subject: subject,
                message: message,
                contactEmail: contactEmail
            )

            contactSubject = ""
            contactMessage = ""
            successMessage = "Votre message a été envoyé au support."
            await loadMyRequests()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSendingContact = false
    }

    func sendBugReport(contactEmail: String?) async {
        let subject = bugSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = bugMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !subject.isEmpty else {
            errorMessage = "Veuillez saisir un sujet pour le bug."
            return
        }

        guard !message.isEmpty else {
            errorMessage = "Veuillez décrire le bug rencontré."
            return
        }

        isSendingBug = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await supportService.reportBug(
                subject: subject,
                message: message,
                contactEmail: contactEmail
            )

            bugSubject = ""
            bugMessage = ""
            successMessage = "Votre bug a été signalé avec succès."
            await loadMyRequests()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSendingBug = false
    }
}
