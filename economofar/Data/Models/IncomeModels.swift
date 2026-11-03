import Foundation

// MARK: - API responses of /api/incomes and /api/cashflow

struct IncomeItem: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let amount: Double
    let date: String
    let recurring: Bool
    let endDate: String?
    let countsThisMonth: Bool
}

struct CashFlowMonth: Decodable, Identifiable, Equatable {
    let month: String
    let income: Double
    let expenses: Double
    let net: Double
    let savingsRate: Double?
    let current: Bool

    var id: String {
        month
    }
}

struct CashFlowReport: Decodable, Equatable {
    let months: [CashFlowMonth]
    let averageIncome: Double
    let averageExpenses: Double
    let averageNet: Double
    let averageSavingsRate: Double?
    let completedMonths: Int
    let hasIncome: Bool
}

extension CashFlowReport {
    /// The month that is not finished yet.
    var currentMonth: CashFlowMonth? {
        months.last { $0.current }
    }
}

// MARK: - Body sent to the API

struct IncomeBody: Encodable {
    let name: String
    let amount: Double
    let date: String
    let recurring: Bool
    let endDate: String?
}

// MARK: - Dates

enum IncomeDates {
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

    static func display(_ value: String?) -> String? {
        guard let value, let date = parse(value) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = AppFormat.locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// Short month name for a "yyyy-MM" value, for example "oct.".
    static func monthLabel(_ value: String) -> String {
        guard let date = parse(value + "-01") else { return value }

        let formatter = DateFormatter()
        formatter.locale = AppFormat.locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    static func addYears(_ years: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .year, value: years, to: date) ?? date
    }
}

// MARK: - Text input helpers

enum IncomeInput {
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
