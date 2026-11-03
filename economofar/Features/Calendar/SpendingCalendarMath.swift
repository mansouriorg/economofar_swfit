import Foundation

// MARK: - A month of the calendar

struct SpendingCalendarMonth: Equatable, Hashable {
    let year: Int
    let month: Int

    static func containing(_ date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> SpendingCalendarMonth {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return SpendingCalendarMonth(year: parts.year ?? 1970, month: parts.month ?? 1)
    }

    /// Position of the month on a single line, used to compare two months.
    var index: Int {
        year * 12 + (month - 1)
    }

    func adding(months delta: Int) -> SpendingCalendarMonth {
        let position = index + delta
        return SpendingCalendarMonth(year: position / 12, month: position % 12 + 1)
    }

    /// yyyy-MM, the format the server expects for its month filter.
    var key: String {
        String(format: "%04d-%02d", year, month)
    }

    func dayKey(_ day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    func firstDay(calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    func dayCount(calendar: Calendar) -> Int {
        guard let first = firstDay(calendar: calendar),
              let range = calendar.range(of: .day, in: .month, for: first) else {
            return 30
        }

        return max(range.count, 1)
    }

    /// Empty cells before the 1st so that it falls under the right weekday.
    func leadingBlanks(calendar: Calendar) -> Int {
        guard let first = firstDay(calendar: calendar) else { return 0 }

        let weekday = calendar.component(.weekday, from: first)

        return (weekday - calendar.firstWeekday + 7) % 7
    }

    func title(locale: Locale) -> String {
        let gregorian = Calendar(identifier: .gregorian)

        guard let first = firstDay(calendar: gregorian) else { return key }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = gregorian
        formatter.dateFormat = "LLLL yyyy"

        return SpendingCalendarMath.capitalized(formatter.string(from: first))
    }
}

// MARK: - What was spent on one day

struct SpendingCalendarDay: Identifiable, Equatable {
    let key: String
    let day: Int
    var total: Double
    var tickets: [TicketHistoryReceipt]

    var id: String {
        key
    }
}

struct SpendingCalendarSummary: Equatable {
    let total: Double
    let ticketCount: Int
    let activeDays: Int
    let topDay: SpendingCalendarDay?
}

struct SpendingCalendarCell: Identifiable {
    let id: String
    let day: Int?
    let key: String?
}

// MARK: - Calculations

enum SpendingCalendarMath {

    static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppFormat.locale
        calendar.firstWeekday = AppFormat.locale.identifier == "en_US" ? 1 : 2
        return calendar
    }

    /// yyyy-MM-dd of the purchase, read from the text sent by the server
    /// (a date without time zone), so the day is the one the server stored.
    static func dayKey(of purchaseDate: String?) -> String? {
        guard let text = purchaseDate, text.count >= 10 else { return nil }

        let prefix = String(text.prefix(10))
        let parts = prefix.split(separator: "-", omittingEmptySubsequences: false)

        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              Int(parts[0]) != nil,
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }

        return prefix
    }

    static func todayKey(calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        let month = SpendingCalendarMonth(year: parts.year ?? 1970, month: parts.month ?? 1)

        return month.dayKey(parts.day ?? 1)
    }

    static func aggregate(
        _ receipts: [TicketHistoryReceipt],
        in month: SpendingCalendarMonth
    ) -> [String: SpendingCalendarDay] {
        var result: [String: SpendingCalendarDay] = [:]
        let prefix = month.key + "-"

        for receipt in receipts {
            guard let key = dayKey(of: receipt.purchaseDate),
                  key.hasPrefix(prefix),
                  let day = Int(key.suffix(2)) else {
                continue
            }

            let raw = receipt.totalAmount ?? 0
            let amount = raw.isFinite ? raw : 0

            if var existing = result[key] {
                existing.total += amount
                existing.tickets.append(receipt)
                result[key] = existing
            } else {
                result[key] = SpendingCalendarDay(key: key, day: day, total: amount, tickets: [receipt])
            }
        }

        return result
    }

    static func summary(of days: [String: SpendingCalendarDay]) -> SpendingCalendarSummary {
        var total = 0.0
        var count = 0
        var active = 0
        var top: SpendingCalendarDay? = nil

        for day in days.values {
            total += day.total
            count += day.tickets.count

            if !day.tickets.isEmpty {
                active += 1
            }

            if let best = top {
                if day.total > best.total || (day.total == best.total && day.key < best.key) {
                    top = day
                }
            } else {
                top = day
            }
        }

        if let best = top, best.total <= 0 {
            top = nil
        }

        return SpendingCalendarSummary(total: total, ticketCount: count, activeDays: active, topDay: top)
    }

    /// 0 for a quiet day, 1 for the most expensive day of the month.
    static func intensity(total: Double, maxTotal: Double) -> Double {
        guard total > 0, maxTotal > 0 else { return 0 }

        return min(max(total / maxTotal, 0), 1)
    }

    static func cells(for month: SpendingCalendarMonth, calendar: Calendar) -> [SpendingCalendarCell] {
        var result: [SpendingCalendarCell] = []

        for index in 0..<month.leadingBlanks(calendar: calendar) {
            result.append(SpendingCalendarCell(id: "blank-\(index)", day: nil, key: nil))
        }

        for day in 1...month.dayCount(calendar: calendar) {
            let key = month.dayKey(day)
            result.append(SpendingCalendarCell(id: key, day: day, key: key))
        }

        return result
    }

    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols

        guard symbols.count == 7 else {
            return ["L", "M", "M", "J", "V", "S", "D"]
        }

        let start = max(0, min(6, calendar.firstWeekday - 1))

        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    /// Short label for a day cell: 0 to 999 as they are, then 1,2k, 15k...
    static func compactAmount(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0" }

        if value < 1 {
            return "<1"
        }

        if value >= 999.5 {
            let formatter = NumberFormatter()
            formatter.locale = AppFormat.locale
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = value >= 10_000 ? 0 : 1

            let text = formatter.string(from: NSNumber(value: value / 1000)) ?? String(Int(value / 1000))

            return text + "k"
        }

        return String(Int(value.rounded()))
    }

    static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }

        return first.uppercased() + text.dropFirst()
    }

    /// "Jeudi 15 octobre" for a yyyy-MM-dd key.
    static func longTitle(forKey key: String, locale: Locale) -> String {
        guard let date = date(forKey: key) else { return key }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE d MMMM"

        return capitalized(formatter.string(from: date))
    }

    /// Noon of the day (device time zone), safe against a change of day by a time zone shift.
    static func date(forKey key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"

        guard let start = formatter.date(from: key) else { return nil }

        return Calendar(identifier: .gregorian).date(bySettingHour: 12, minute: 0, second: 0, of: start)
    }
}
