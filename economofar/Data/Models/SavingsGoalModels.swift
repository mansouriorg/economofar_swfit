import Foundation

// MARK: - API responses of /api/savings-goals

struct SavingsContribution: Decodable, Identifiable, Equatable {
    let id: Int
    let amount: Double
    let date: String
    let note: String?
}

struct SavingsGoal: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let icon: String?
    let targetAmount: Double
    let savedAmount: Double
    let remainingAmount: Double
    let percent: Double
    let deadline: String?
    let daysLeft: Int?
    let monthlyNeeded: Double?
    let monthlyPace: Double?
    let projectedDate: String?
    let status: String
    let contributionCount: Int
    let contributions: [SavingsContribution]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case targetAmount
        case savedAmount
        case remainingAmount
        case percent
        case deadline
        case daysLeft
        case monthlyNeeded
        case monthlyPace
        case projectedDate
        case status
        case contributionCount
        case contributions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        targetAmount = try container.decode(Double.self, forKey: .targetAmount)
        savedAmount = try container.decodeIfPresent(Double.self, forKey: .savedAmount) ?? 0
        remainingAmount = try container.decodeIfPresent(Double.self, forKey: .remainingAmount) ?? 0
        percent = try container.decodeIfPresent(Double.self, forKey: .percent) ?? 0
        deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        daysLeft = try container.decodeIfPresent(Int.self, forKey: .daysLeft)
        monthlyNeeded = try container.decodeIfPresent(Double.self, forKey: .monthlyNeeded)
        monthlyPace = try container.decodeIfPresent(Double.self, forKey: .monthlyPace)
        projectedDate = try container.decodeIfPresent(String.self, forKey: .projectedDate)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        contributions = try container.decodeIfPresent([SavingsContribution].self, forKey: .contributions) ?? []
        contributionCount = try container.decodeIfPresent(Int.self, forKey: .contributionCount) ?? contributions.count
    }
}

enum SavingsGoalStatus: String {
    case completed
    case overdue
    case notStarted
    case noDeadline
    case onTrack
    case behind
    case unknown
}

extension SavingsGoal {
    var state: SavingsGoalStatus {
        SavingsGoalStatus(rawValue: status) ?? .unknown
    }

    var isCompleted: Bool {
        state == .completed
    }

    /// Share of the target already saved, between 0 and 1.
    var progressFraction: Double {
        guard percent.isFinite else { return 0 }
        return min(max(percent, 0), 100) / 100
    }
}

// MARK: - Bodies sent to the API

struct SavingsGoalBody: Encodable {
    let name: String
    let targetAmount: Double
    let deadline: String?
    let icon: String?
}

struct SavingsContributionBody: Encodable {
    let amount: Double
    let date: String?
    let note: String?
}

// MARK: - Icons

struct SavingsGoalIcon: Identifiable, Equatable {
    let key: String
    let symbol: String
    let label: String

    var id: String {
        key
    }
}

enum SavingsGoalIcons {
    static let defaultKey = "goal"
    static let fallbackSymbol = "flag.fill"

    static let all: [SavingsGoalIcon] = [
        SavingsGoalIcon(key: "goal", symbol: "flag.fill", label: "Objectif"),
        SavingsGoalIcon(key: "travel", symbol: "airplane", label: "Voyage"),
        SavingsGoalIcon(key: "home", symbol: "house.fill", label: "Maison"),
        SavingsGoalIcon(key: "car", symbol: "car.fill", label: "Voiture"),
        SavingsGoalIcon(key: "gift", symbol: "gift.fill", label: "Cadeau"),
        SavingsGoalIcon(key: "study", symbol: "graduationcap.fill", label: "Études"),
        SavingsGoalIcon(key: "health", symbol: "heart.fill", label: "Santé"),
        SavingsGoalIcon(key: "tech", symbol: "laptopcomputer", label: "High-tech"),
        SavingsGoalIcon(key: "shopping", symbol: "bag.fill", label: "Shopping"),
        SavingsGoalIcon(key: "holiday", symbol: "sun.max.fill", label: "Vacances"),
        SavingsGoalIcon(key: "emergency", symbol: "cross.case.fill", label: "Imprévus"),
        SavingsGoalIcon(key: "party", symbol: "sparkles", label: "Fête")
    ]

    static func symbol(for key: String?) -> String {
        guard let key, let found = all.first(where: { $0.key == key }) else {
            return fallbackSymbol
        }

        return found.symbol
    }
}

// MARK: - Dates

enum SavingsDates {
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        parser.date(from: value)
    }

    static func iso(_ date: Date) -> String {
        parser.string(from: date)
    }

    static func display(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppFormat.locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    static func display(_ value: String?) -> String? {
        guard let value, let date = parse(value) else { return nil }
        return display(date)
    }

    static func addMonths(_ months: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: date) ?? date
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }
}

// MARK: - Text input helpers

enum SavingsInput {
    /// Reads an amount typed by the user: spaces (including no-break spaces) are ignored,
    /// a comma counts as a decimal point, and at least one cent is required.
    static func amount(from text: String) -> Double? {
        let cleaned = text
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(cleaned), value.isFinite, value < 1_000_000_000 else {
            return nil
        }

        guard (value * 100).rounded() >= 1 else {
            return nil
        }

        return value
    }

    /// Cuts a text so that it fits the server limit, which counts UTF-16 units.
    static func limited(_ text: String, to maxLength: Int) -> String {
        var result = text

        while result.utf16.count > maxLength, !result.isEmpty {
            result.removeLast()
        }

        return result
    }
}
