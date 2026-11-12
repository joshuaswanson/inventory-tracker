import Foundation

nonisolated enum DashboardWidget: String, CaseIterable, Codable, Identifiable {
    case items, lowStock, expiring, vendors, inventoryValue, spending, purchases, usage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .items: "Items"
        case .lowStock: "Low Stock"
        case .expiring: "Expiring Soon"
        case .vendors: "Vendors"
        case .inventoryValue: "Inventory Value"
        case .spending: "Spending"
        case .purchases: "Purchases"
        case .usage: "Usage"
        }
    }
}

/// The same four sizes as home screen widgets, measured in grid cells.
nonisolated enum DashboardTileSize: String, CaseIterable, Codable, Identifiable {
    case small, medium, large, extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    var columns: Int {
        switch self {
        case .small: 1
        case .medium, .large: 2
        case .extraLarge: 4
        }
    }

    var rows: Int {
        switch self {
        case .small, .medium: 1
        case .large, .extraLarge: 2
        }
    }

    /// The size whose shape is closest to a block of cells, used while a corner is being dragged.
    static func closest(columns: Int, rows: Int) -> DashboardTileSize {
        if columns >= 3 { return .extraLarge }
        if rows >= 2 { return .large }
        return columns == 2 ? .medium : .small
    }
}

nonisolated struct DashboardTile: Codable, Equatable, Identifiable {
    var widget: DashboardWidget
    var size: DashboardTileSize

    var id: String { widget.rawValue }
}

nonisolated struct DashboardLayout: Codable, Equatable {
    static let storageKey = "dashboardLayout.v2"

    static let standard = DashboardLayout(tiles: [
        DashboardTile(widget: .items, size: .small),
        DashboardTile(widget: .vendors, size: .small),
        DashboardTile(widget: .inventoryValue, size: .medium),
        DashboardTile(widget: .spending, size: .medium),
        DashboardTile(widget: .lowStock, size: .large),
        DashboardTile(widget: .expiring, size: .large),
        DashboardTile(widget: .purchases, size: .large),
    ])

    var tiles: [DashboardTile]

    var hidden: [DashboardWidget] {
        DashboardWidget.allCases.filter { widget in !tiles.contains { $0.widget == widget } }
    }

    mutating func move(_ widget: DashboardWidget, onto target: DashboardWidget) {
        guard let from = tiles.firstIndex(where: { $0.widget == widget }),
              let to = tiles.firstIndex(where: { $0.widget == target }), from != to else { return }
        let tile = tiles.remove(at: from)
        tiles.insert(tile, at: to)
    }

    mutating func resize(_ widget: DashboardWidget, to size: DashboardTileSize) {
        guard let index = tiles.firstIndex(where: { $0.widget == widget }) else { return }
        tiles[index].size = size
    }

    mutating func hide(_ widget: DashboardWidget) {
        tiles.removeAll { $0.widget == widget }
    }

    mutating func add(_ widget: DashboardWidget) {
        guard !tiles.contains(where: { $0.widget == widget }) else { return }
        tiles.append(DashboardTile(widget: widget, size: .small))
    }

    static func load(from defaults: UserDefaults = .standard) -> DashboardLayout {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(DashboardLayout.self, from: data) else { return standard }
        var seen: Set<DashboardWidget> = []
        return DashboardLayout(tiles: saved.tiles.filter { seen.insert($0.widget).inserted })
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.storageKey)
    }
}

nonisolated enum DashboardPacking {
    struct Slot: Equatable {
        var column: Int
        var row: Int
        var columns: Int
        var rows: Int
    }

    /// Each tile takes the first free spot, reading left to right and top to bottom,
    /// so small tiles fill the gaps beside tall ones.
    static func slots(for sizes: [DashboardTileSize], columns: Int) -> [Slot] {
        let columns = max(1, columns)
        var taken: [[Bool]] = []
        func isFree(column: Int, row: Int, width: Int, height: Int) -> Bool {
            for y in row..<(row + height) where y < taken.count {
                for x in column..<(column + width) where taken[y][x] { return false }
            }
            return true
        }
        return sizes.map { size in
            let width = min(size.columns, columns)
            var row = 0
            while true {
                for column in 0...(columns - width) where isFree(column: column, row: row, width: width, height: size.rows) {
                    while taken.count < row + size.rows { taken.append(Array(repeating: false, count: columns)) }
                    for y in row..<(row + size.rows) {
                        for x in column..<(column + width) { taken[y][x] = true }
                    }
                    return Slot(column: column, row: row, columns: width, rows: size.rows)
                }
                row += 1
            }
        }
    }
}
