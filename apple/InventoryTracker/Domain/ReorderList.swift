import Foundation

nonisolated struct ReorderLine: Equatable, Identifiable {
    var id: String
    var name: String
    var unit: String
    var stock: Int
    var reorderLevel: Int
    var vendor: String?
    var bestPrice: Double?

    /// Enough to bring stock to twice the reorder level.
    var suggestedQuantity: Int { max(1, reorderLevel * 2 - stock) }
}

nonisolated struct ReorderGroup: Equatable, Identifiable {
    var vendor: String
    var lines: [ReorderLine]

    var id: String { vendor }
}

nonisolated enum ReorderList {
    static let noVendor = "No vendor yet"

    static func groups(_ lines: [ReorderLine]) -> [ReorderGroup] {
        let byVendor = Dictionary(grouping: lines) { $0.vendor ?? noVendor }
        return byVendor.keys
            .sorted { ($0 == noVendor ? 1 : 0, $0) < ($1 == noVendor ? 1 : 0, $1) }
            .map { vendor in
                ReorderGroup(vendor: vendor, lines: byVendor[vendor, default: []].sorted { $0.name < $1.name })
            }
    }

    static func text(_ lines: [ReorderLine], day: String) -> String {
        var output = ["Reorder list, \(Format.longDate(day))"]
        for group in groups(lines) {
            output.append("")
            output.append(group.vendor)
            for line in group.lines {
                let price = line.bestPrice.map { ", best price \(Format.currency($0))" } ?? ""
                output.append("- \(line.name): order \(line.suggestedQuantity) \(line.unit) (have \(line.stock))\(price)")
            }
        }
        return output.joined(separator: "\n")
    }
}
