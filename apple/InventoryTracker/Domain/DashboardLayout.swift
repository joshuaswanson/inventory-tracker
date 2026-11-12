import Foundation

nonisolated enum DashboardWidget: String, CaseIterable, Codable, Identifiable {
    case totalItems, lowStockCount, expiringCount, vendors, inventoryValue, spentThisMonth
    case lowStockAlerts, expiringList, recentPurchases

    var id: String { rawValue }

    var title: String {
        switch self {
        case .totalItems: "Total Items"
        case .lowStockCount: "Low Stock Count"
        case .expiringCount: "Expiring Soon Count"
        case .vendors: "Vendors"
        case .inventoryValue: "Inventory Value"
        case .spentThisMonth: "Spent This Month"
        case .lowStockAlerts: "Low Stock Alerts"
        case .expiringList: "Expiring Soon List"
        case .recentPurchases: "Recent Purchases"
        }
    }

    var isList: Bool {
        switch self {
        case .lowStockAlerts, .expiringList, .recentPurchases: true
        default: false
        }
    }

    var sizes: [DashboardTileSize] { isList ? [.half, .full] : [.small, .wide] }
}

nonisolated enum DashboardTileSize: String, Codable {
    case small, wide, half, full

    func span(columns: Int) -> Int {
        switch self {
        case .small: 1
        case .wide: min(2, columns)
        case .half: columns <= 2 ? columns : columns / 2
        case .full: columns
        }
    }
}

nonisolated struct DashboardTile: Codable, Equatable, Identifiable {
    var widget: DashboardWidget
    var size: DashboardTileSize

    var id: String { widget.rawValue }
}

nonisolated struct DashboardLayout: Codable, Equatable {
    static let storageKey = "dashboardLayout"

    static let standard = DashboardLayout(tiles: [
        DashboardTile(widget: .totalItems, size: .small),
        DashboardTile(widget: .lowStockCount, size: .small),
        DashboardTile(widget: .expiringCount, size: .small),
        DashboardTile(widget: .vendors, size: .small),
        DashboardTile(widget: .inventoryValue, size: .small),
        DashboardTile(widget: .lowStockAlerts, size: .half),
        DashboardTile(widget: .expiringList, size: .half),
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

    mutating func resize(_ widget: DashboardWidget) {
        guard let index = tiles.firstIndex(where: { $0.widget == widget }) else { return }
        let sizes = widget.sizes
        let current = sizes.firstIndex(of: tiles[index].size) ?? 0
        tiles[index].size = sizes[(current + 1) % sizes.count]
    }

    mutating func hide(_ widget: DashboardWidget) {
        tiles.removeAll { $0.widget == widget }
    }

    mutating func add(_ widget: DashboardWidget) {
        guard !tiles.contains(where: { $0.widget == widget }) else { return }
        tiles.append(DashboardTile(widget: widget, size: widget.sizes[0]))
    }

    static func load(from defaults: UserDefaults = .standard) -> DashboardLayout {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(DashboardLayout.self, from: data) else { return standard }
        var seen: Set<DashboardWidget> = []
        return DashboardLayout(tiles: saved.tiles.filter { seen.insert($0.widget).inserted && $0.widget.sizes.contains($0.size) })
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.storageKey)
    }
}
