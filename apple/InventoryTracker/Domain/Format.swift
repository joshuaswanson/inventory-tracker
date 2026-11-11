import Foundation

nonisolated enum Format {
    static let missing = "-"

    static func currency(_ value: Double?) -> String {
        guard let value else { return missing }
        return value.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }

    static func longDate(_ iso: String?) -> String {
        formatted(iso, pattern: "MMM d, yyyy")
    }

    static func shortDate(_ iso: String?) -> String {
        formatted(iso, pattern: "MMM d")
    }

    static func month(_ yearMonth: String) -> String {
        formatted("\(yearMonth)-01", pattern: "MMMM yyyy")
    }

    static func digits(_ phone: String) -> String {
        phone.filter(\.isNumber)
    }

    static func phone(_ phone: String) -> String {
        let digits = Array(digits(phone))
        func slice(_ range: Range<Int>) -> String { String(digits[range]) }
        if digits.count == 10 {
            return "(\(slice(0..<3))) \(slice(3..<6))-\(slice(6..<10))"
        }
        if digits.count == 11, digits[0] == "1" {
            return "+1 (\(slice(1..<4))) \(slice(4..<7))-\(slice(7..<11))"
        }
        return phone
    }

    private static func formatted(_ iso: String?, pattern: String) -> String {
        guard let iso, let date = Day.utcDate(from: iso) else { return missing }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
