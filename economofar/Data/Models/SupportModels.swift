import Foundation

struct FaqItem: Codable, Identifiable {
    let id: String
    let category: String
    let question: String
    let answer: String
    let displayOrder: Int?
    let createdAt: String?
    let updatedAt: String?
}

struct SupportConfig: Codable {
    let supportEmail: String
    let termsUrl: String
    let privacyUrl: String
    let statusPageUrl: String
}

struct AppStatus: Codable {
    let status: String
    let api: String
    let database: String
    let message: String
    let checkedAt: String?
}

struct SubmitSupportRequest: Codable {
    let subject: String
    let message: String
    let appVersion: String?
    let deviceModel: String?
    let osVersion: String?
    let contactEmail: String?
}

struct SupportRequestResponse: Codable, Identifiable {
    let id: String
    let type: String
    let status: String
    let subject: String
    let message: String
    let appVersion: String?
    let deviceModel: String?
    let osVersion: String?
    let contactEmail: String?
    let createdAt: String?
    let updatedAt: String?
}
