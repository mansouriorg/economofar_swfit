import Foundation

enum TicketScanStatus: String, Codable, CaseIterable {
    case idle = "IDLE"
    case uploading = "UPLOADING"
    case analyzing = "ANALYZING"
    case ocrCompleted = "OCR_COMPLETED"
    case needsReview = "NEEDS_REVIEW"
    case saved = "SAVED"
    case failed = "FAILED"

    var title: String {
        switch self {
        case .idle:
            return "Prêt à scanner"
        case .uploading:
            return "Envoi du ticket"
        case .analyzing:
            return "Analyse en cours"
        case .ocrCompleted:
            return "OCR terminé"
        case .needsReview:
            return "Validation requise"
        case .saved:
            return "Ticket sauvegardé"
        case .failed:
            return "Échec du scan"
        }
    }

    var subtitle: String {
        switch self {
        case .idle:
            return "Ajoutez un ticket"
        case .uploading:
            return "Téléversement de l’image"
        case .analyzing:
            return "Extraction des informations"
        case .ocrCompleted:
            return "Lecture terminée"
        case .needsReview:
            return "Vérifiez les données"
        case .saved:
            return "Ajouté à l’historique"
        case .failed:
            return "Une erreur est survenue"
        }
    }

    var isLoading: Bool {
        switch self {
        case .uploading, .analyzing:
            return true
        default:
            return false
        }
    }

    var isFinal: Bool {
        switch self {
        case .saved, .failed, .needsReview:
            return true
        default:
            return false
        }
    }
}

struct TicketUploadResponse: Codable {
    let ticketId: String?
    let scanStatus: TicketScanStatus?
    let scanErrorMessage: String?
    let scanStartedAt: String?
    let ocrCompletedAt: String?
    let reviewedAt: String?
    let savedAt: String?
    let rawOcrText: String?
    let message: String?
}

struct TicketScanStatusResponse: Codable {
    let ticketId: String?
    let scanStatus: TicketScanStatus?
    let scanErrorMessage: String?
    let scanStartedAt: String?
    let ocrCompletedAt: String?
    let reviewedAt: String?
    let savedAt: String?
}
