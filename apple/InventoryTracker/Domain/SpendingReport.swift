import Foundation

nonisolated struct SpendingEntry {
    var day: String
    var item: String
    var vendor: String
    var quantity: Int
    var pricePerUnit: Double

    var total: Double { Double(quantity) * pricePerUnit }
}

nonisolated enum SpendingPeriod: String, CaseIterable, Identifiable {
    case thisYear, lastYear, allTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thisYear: "This Year"
        case .lastYear: "Last Year"
        case .allTime: "All Time"
        }
    }

    func includes(day: String, today: String) -> Bool {
        let year = Int(today.prefix(4)) ?? 0
        switch self {
        case .thisYear: return day.hasPrefix("\(year)-")
        case .lastYear: return day.hasPrefix("\(year - 1)-")
        case .allTime: return true
        }
    }
}

nonisolated struct SpendingTotal: Equatable, Identifiable {
    var name: String
    var total: Double

    var id: String { name }
}

nonisolated struct SpendingReport {
    static let noVendor = "No vendor"

    var total: Double
    var byVendor: [SpendingTotal]
    var byMonth: [SpendingTotal]

    init(entries: [SpendingEntry]) {
        total = roundedToCents(entries.reduce(0) { $0 + $1.total })
        byVendor = Self.totals(entries) { $0.vendor.isEmpty ? Self.noVendor : $0.vendor }
            .sorted { ($1.total, $0.name) < ($0.total, $1.name) }
        byMonth = Self.totals(entries) { String($0.day.prefix(7)) }
            .sorted { $0.name > $1.name }
    }

    private static func totals(_ entries: [SpendingEntry], key: (SpendingEntry) -> String) -> [SpendingTotal] {
        Dictionary(grouping: entries, by: key).map { name, group in
            SpendingTotal(name: name, total: roundedToCents(group.reduce(0) { $0 + $1.total }))
        }
    }

    static func csv(_ entries: [SpendingEntry]) -> String {
        func field(_ text: String) -> String {
            text.contains(where: { ",\"\n".contains($0) }) ? "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\"" : text
        }
        func money(_ value: Double) -> String { String(format: "%.2f", value) }
        var rows = ["Date,Item,Vendor,Quantity,Price per Unit,Total"]
        for entry in entries.sorted(by: { $0.day < $1.day }) {
            rows.append([entry.day, field(entry.item), field(entry.vendor), "\(entry.quantity)", money(entry.pricePerUnit), money(entry.total)].joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }
}
