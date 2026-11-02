import Foundation

/// Calendar days are stored as `yyyy-MM-dd` strings so a day never shifts across time zones or sync.
nonisolated enum Day {
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static var today: String { string(from: Date()) }

    static func string(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func localDate(from iso: String, calendar: Calendar = .current) -> Date? {
        components(from: iso).flatMap { calendar.date(from: $0) }
    }

    static func utcDate(from iso: String) -> Date? {
        components(from: iso).flatMap { utcCalendar.date(from: $0) }
    }

    static func days(from start: String, to end: String) -> Int? {
        guard let startDate = utcDate(from: start), let endDate = utcDate(from: end) else { return nil }
        return utcCalendar.dateComponents([.day], from: startDate, to: endDate).day
    }

    static func isValid(_ iso: String) -> Bool {
        guard let date = utcDate(from: iso) else { return false }
        return string(from: date, calendar: utcCalendar) == iso
    }

    private static func components(from iso: String) -> DateComponents? {
        let parts = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(year: parts[0], month: parts[1], day: parts[2])
    }
}
