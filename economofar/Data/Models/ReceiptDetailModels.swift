import Foundation

// MARK: - Receipt Usage Type

enum ReceiptUsageType: String, Codable, CaseIterable, Identifiable {
    case personal = "PERSONAL"
    case business = "BUSINESS"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .personal:
            return "Personnel"
        case .business:
            return "Professionnel"
        }
    }

    var icon: String {
        switch self {
        case .personal:
            return "person"
        case .business:
            return "briefcase"
        }
    }
}

// MARK: - Receipt Detail Response

struct ReceiptDetailResponse: Codable, Identifiable, Hashable {
    let id: UUID

    let merchantName: String?
    let totalAmount: Double?
    let purchaseDate: String?
    let category: String?
    let paymentMethod: String?
    let scanStatus: TicketScanStatus?

    let imageUrl: String?
    let rawOcrText: String?

    let note: String?
    let warrantyDate: String?
    let reimbursable: Bool?
    let usageType: ReceiptUsageType?

    let vatAmount: Double?
    let deductible: Bool?
    let projectName: String?
    let clientName: String?
    let expenseReportReference: String?

    let originalFileName: String?
    let imageContentType: String?

    let items: [ReceiptItemDetailResponse]?

    var displayMerchant: String {
        guard let merchantName,
              !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Commerçant inconnu"
        }

        return merchantName
    }

    var displayAmount: String {
        String(format: "%.2f €", totalAmount ?? 0.0)
    }

    var displayDate: String {
        ReceiptDetailDateHelper.shortDate(from: purchaseDate)
    }

    var displayCategory: String {
        guard let category,
              !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Autre"
        }

        return category
    }

    var displayPaymentMethod: String {
        guard let paymentMethod,
              !paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Non précisé"
        }

        return paymentMethod
    }

    var displayUsageType: String {
        usageType?.title ?? "Personnel"
    }

    var displayVatAmount: String {
        String(format: "%.2f €", vatAmount ?? 0.0)
    }

    var displayWarrantyDate: String {
        guard let warrantyDate,
              !warrantyDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Non renseignée"
        }

        return warrantyDate
    }

    var displayNote: String {
        guard let note,
              !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Aucune note"
        }

        return note
    }

    var safeItems: [ReceiptItemDetailResponse] {
        items ?? []
    }
}

// MARK: - Receipt Detail Update Request

struct ReceiptDetailUpdateRequest: Codable {
    let merchantName: String?
    let purchaseDate: String?
    let totalAmount: Double?
    let category: String?
    let paymentMethod: String?
    let rawOcrText: String?
    let imageUrl: String?

    let note: String?
    let warrantyDate: String?
    let reimbursable: Bool?
    let usageType: ReceiptUsageType?

    let vatAmount: Double?
    let deductible: Bool?
    let projectName: String?
    let clientName: String?
    let expenseReportReference: String?
}

// MARK: - Receipt Item Response

struct ReceiptItemDetailResponse: Codable, Identifiable, Hashable {
    let id: UUID

    let name: String?
    let quantity: Int?
    let unitPrice: Double?
    let totalPrice: Double?
    let category: String?
    let usageType: ReceiptUsageType?

    var displayName: String {
        guard let name,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Article"
        }

        return name
    }

    var displayQuantity: String {
        "\(quantity ?? 1)"
    }

    var displayUnitPrice: String {
        String(format: "%.2f €", unitPrice ?? 0.0)
    }

    var displayTotalPrice: String {
        String(format: "%.2f €", totalPrice ?? 0.0)
    }

    var displayCategory: String {
        guard let category,
              !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Autre"
        }

        return category
    }

    var displayUsageType: String {
        usageType?.title ?? "Personnel"
    }
}

// MARK: - Receipt Item Request

struct ReceiptItemDetailRequest: Codable {
    let name: String?
    let quantity: Int?
    let unitPrice: Double?
    let totalPrice: Double?
    let category: String?
    let usageType: ReceiptUsageType?
}

// MARK: - Editable Item Form

struct ReceiptEditableItemForm: Identifiable, Hashable {
    var id: UUID?
    var name: String
    var quantity: String
    var unitPrice: String
    var totalPrice: String
    var category: String
    var usageType: ReceiptUsageType

    var identifiableId: UUID {
        id ?? UUID()
    }

    init() {
        self.id = nil
        self.name = ""
        self.quantity = "1"
        self.unitPrice = ""
        self.totalPrice = ""
        self.category = "Autre"
        self.usageType = .personal
    }

    init(item: ReceiptItemDetailResponse) {
        self.id = item.id
        self.name = item.name ?? ""
        self.quantity = "\(item.quantity ?? 1)"
        self.unitPrice = ReceiptDetailNumberHelper.string(from: item.unitPrice)
        self.totalPrice = ReceiptDetailNumberHelper.string(from: item.totalPrice)
        self.category = item.category ?? "Autre"
        self.usageType = item.usageType ?? .personal
    }

    func toRequest() -> ReceiptItemDetailRequest {
        ReceiptItemDetailRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: Int(quantity.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1,
            unitPrice: ReceiptDetailNumberHelper.double(from: unitPrice),
            totalPrice: ReceiptDetailNumberHelper.double(from: totalPrice),
            category: category,
            usageType: usageType
        )
    }
}

// MARK: - Exported File

struct ReceiptExportedFile: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

// MARK: - Options

enum ReceiptPaymentMethodOptions {
    static let all: [String] = [
        "Carte",
        "Espèces",
        "Chèque",
        "Virement",
        "Apple Pay",
        "Google Pay",
        "Autre"
    ]
}

enum ReceiptBusinessCategoryOptions {
    static let all: [String] = [
        "Autre",
        "Alimentation",
        "Restaurant",
        "Transport",
        "Santé",
        "Shopping",
        "Bureau",
        "Carburant",
        "Hôtel",
        "Voyage",
        "Client",
        "Projet",
        "Logiciel",
        "Téléphonie"
    ]
}

// MARK: - Helpers

enum ReceiptDetailDateHelper {
    static func shortDate(from dateString: String?) -> String {
        guard let date = parseDate(dateString) else {
            return dateString ?? "Date inconnue"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(from: date)
    }

    static func inputDate(from dateString: String?) -> String {
        guard let date = parseDate(dateString) else {
            return dateString ?? ""
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: date)
    }

    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString,
              !dateString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatterWithFraction.date(from: dateString) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        if let date = standardFormatter.date(from: dateString) {
            return date
        }

        let localDateTimeFormatter = DateFormatter()
        localDateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        if let date = localDateTimeFormatter.date(from: dateString) {
            return date
        }

        let localDateFormatter = DateFormatter()
        localDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateFormatter.dateFormat = "yyyy-MM-dd"

        if let date = localDateFormatter.date(from: dateString) {
            return date
        }

        return nil
    }
}

enum ReceiptDetailNumberHelper {
    static func double(from value: String) -> Double? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !cleaned.isEmpty else {
            return nil
        }

        return Double(cleaned)
    }

    static func string(from value: Double?) -> String {
        guard let value else {
            return ""
        }

        return String(format: "%.2f", value)
    }
}
