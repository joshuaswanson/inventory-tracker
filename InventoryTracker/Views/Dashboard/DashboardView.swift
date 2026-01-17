import SwiftUI
import SwiftData

enum WidgetSize: String, Codable, CaseIterable {
    case small = "Small"      // 1x1
    case medium = "Medium"    // 2x1
    case large = "Large"      // 2x2

    var colSpan: Int {
        switch self {
        case .small: return 1
        case .medium, .large: return 2
        }
    }

    var rowSpan: Int {
        switch self {
        case .small, .medium: return 1
        case .large: return 2
        }
    }

    var icon: String {
        switch self {
        case .small: return "square"
        case .medium: return "rectangle"
        case .large: return "square.grid.2x2"
        }
    }
}

enum DashboardItem: String, CaseIterable, Identifiable, Codable {
    case totalItems = "Total Items"
    case lowStock = "Low Stock"
    case expiringSoon = "Expiring Soon"
    case inventoryValue = "Inventory Value"
    case reorderAlerts = "Reorder Alerts"
    case priceAnalytics = "Price Analytics"

    var id: String { rawValue }

    var defaultSize: WidgetSize {
        switch self {
        case .totalItems, .lowStock, .expiringSoon, .inventoryValue:
            return .small
        case .reorderAlerts, .priceAnalytics:
            return .medium
        }
    }

    var icon: String {
        switch self {
        case .totalItems: return "shippingbox.fill"
        case .lowStock: return "exclamationmark.triangle.fill"
        case .expiringSoon: return "clock.fill"
        case .inventoryValue: return "dollarsign.circle.fill"
        case .reorderAlerts: return "exclamationmark.triangle.fill"
        case .priceAnalytics: return "dollarsign.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .totalItems: return .blue
        case .lowStock: return .orange
        case .expiringSoon: return .red
        case .inventoryValue: return .green
        case .reorderAlerts: return .orange
        case .priceAnalytics: return .green
        }
    }
}

struct GridCell: Equatable {
    let item: DashboardItem
    let row: Int
    let col: Int
    let colSpan: Int
    let rowSpan: Int
}

struct DashboardView: View {
    @Query private var items: [Item]
    @Query private var purchases: [Purchase]
    @Query private var vendors: [Vendor]

    @AppStorage("dashboardItemOrder") private var itemOrderData: Data = Data()
    @AppStorage("dashboardWidgetSizes") private var widgetSizesData: Data = Data()

    @State private var itemOrder: [DashboardItem] = DashboardItem.allCases
    @State private var widgetSizes: [DashboardItem: WidgetSize] = [:]
    @State private var draggingItem: DashboardItem?

    private let columns = 4
    private let spacing: CGFloat = 12
    private let cellSize: CGFloat = 141

    var itemsNeedingReorder: [Item] {
        items.filter { $0.needsReorder }
    }

    var expiringItems: [(item: Item, purchase: Purchase, daysLeft: Int)] {
        InventoryCalculator.itemsExpiringWithin(days: 30, from: items)
    }

    var totalInventoryValue: Double {
        InventoryCalculator.totalInventoryValue(for: items)
    }

    func sizeFor(_ item: DashboardItem) -> WidgetSize {
        widgetSizes[item] ?? item.defaultSize
    }

    // Compute grid layout with support for 2x2 widgets
    var gridLayout: (cells: [GridCell], rowCount: Int) {
        var cells: [GridCell] = []
        var grid: [[Bool]] = []

        func ensureRows(_ count: Int) {
            while grid.count < count {
                grid.append([Bool](repeating: false, count: columns))
            }
        }

        func canPlace(row: Int, col: Int, colSpan: Int, rowSpan: Int) -> Bool {
            ensureRows(row + rowSpan)
            for r in row..<(row + rowSpan) {
                for c in col..<(col + colSpan) {
                    if c >= columns || grid[r][c] {
                        return false
                    }
                }
            }
            return true
        }

        func place(row: Int, col: Int, colSpan: Int, rowSpan: Int) {
            ensureRows(row + rowSpan)
            for r in row..<(row + rowSpan) {
                for c in col..<(col + colSpan) {
                    grid[r][c] = true
                }
            }
        }

        func findPosition(colSpan: Int, rowSpan: Int) -> (row: Int, col: Int) {
            var row = 0
            while true {
                ensureRows(row + rowSpan)
                for col in 0...(columns - colSpan) {
                    if canPlace(row: row, col: col, colSpan: colSpan, rowSpan: rowSpan) {
                        return (row, col)
                    }
                }
                row += 1
            }
        }

        for item in itemOrder {
            let size = sizeFor(item)
            let pos = findPosition(colSpan: size.colSpan, rowSpan: size.rowSpan)
            cells.append(GridCell(
                item: item,
                row: pos.row,
                col: pos.col,
                colSpan: size.colSpan,
                rowSpan: size.rowSpan
            ))
            place(row: pos.row, col: pos.col, colSpan: size.colSpan, rowSpan: size.rowSpan)
        }

        return (cells, grid.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let layout = gridLayout
                let gridWidth = CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing
                let gridHeight = CGFloat(layout.rowCount) * cellSize + CGFloat(layout.rowCount - 1) * spacing

                ZStack(alignment: .topLeading) {
                    ForEach(layout.cells, id: \.item.id) { cell in
                        let x = CGFloat(cell.col) * (cellSize + spacing)
                        let y = CGFloat(cell.row) * (cellSize + spacing)
                        let width = CGFloat(cell.colSpan) * cellSize + CGFloat(cell.colSpan - 1) * spacing
                        let height = CGFloat(cell.rowSpan) * cellSize + CGFloat(cell.rowSpan - 1) * spacing

                        draggableCard(for: cell.item, size: CGSize(width: width, height: height))
                            .frame(width: width, height: height)
                            .offset(x: x, y: y)
                    }
                }
                .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity)
                .padding(20)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: itemOrder)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: widgetSizes)
            }
            .frame(minWidth: 600, minHeight: 400)
            .navigationTitle("Dashboard")
        }
        .onAppear {
            loadSettings()
        }
    }

    @ViewBuilder
    private func draggableCard(for item: DashboardItem, size: CGSize) -> some View {
        let currentSize = sizeFor(item)

        cardView(for: item, size: currentSize)
            .id(item.id)
            .contextMenu {
                Section("Size") {
                    ForEach(WidgetSize.allCases, id: \.self) { widgetSize in
                        Button {
                            withAnimation {
                                widgetSizes[item] = widgetSize
                                saveSettings()
                            }
                        } label: {
                            HStack {
                                Text(widgetSize.rawValue)
                                if currentSize == widgetSize {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    withAnimation {
                        itemOrder.removeAll { $0 == item }
                        saveSettings()
                    }
                } label: {
                    Label("Remove Widget", systemImage: "trash")
                }
            }
            .onDrag {
                draggingItem = item
                return NSItemProvider(object: item.rawValue as NSString)
            } preview: {
                cardView(for: item, size: currentSize)
                    .frame(width: min(size.width, 200), height: min(size.height, 120))
                    .background(Color(nsColor: .windowBackgroundColor))
                    .compositingGroup()
                    .drawingGroup()
            }
            .onDrop(of: [.text], delegate: DashboardItemDropDelegate(
                item: item,
                items: $itemOrder,
                draggingItem: $draggingItem,
                onReorder: saveSettings
            ))
    }

    @ViewBuilder
    private func cardView(for item: DashboardItem, size: WidgetSize) -> some View {
        switch item {
        case .totalItems:
            WidgetCard(
                title: "Total Items",
                value: items.count,
                icon: item.icon,
                color: item.color,
                size: size,
                items: items.map { ($0.name, "\($0.currentInventory) \($0.unit.abbreviation)") }
            )
        case .lowStock:
            WidgetCard(
                title: "Low Stock",
                value: itemsNeedingReorder.count,
                icon: item.icon,
                color: itemsNeedingReorder.isEmpty ? .green : item.color,
                size: size,
                items: itemsNeedingReorder.map { ($0.name, "\($0.currentInventory)/\($0.reorderLevel)") }
            )
        case .expiringSoon:
            WidgetCard(
                title: "Expiring Soon",
                value: expiringItems.count,
                icon: item.icon,
                color: expiringItems.isEmpty ? .green : item.color,
                size: size,
                items: expiringItems.map { ($0.item.name, "\($0.daysLeft) days") }
            )
        case .inventoryValue:
            WidgetCard(
                title: "Inventory Value",
                value: totalInventoryValue,
                icon: item.icon,
                color: item.color,
                size: size,
                items: items.compactMap { item in
                    guard let avgPrice = item.averagePricePaid else { return nil }
                    let value = Double(item.currentInventory) * avgPrice
                    return (item.name, value.formatted(.currency(code: "USD")))
                }
            )
        case .reorderAlerts:
            WidgetCard(
                title: "Reorder Alerts",
                value: itemsNeedingReorder.count,
                icon: item.icon,
                color: itemsNeedingReorder.isEmpty ? .green : item.color,
                size: size,
                items: itemsNeedingReorder.map { ($0.name, "\($0.currentInventory)/\($0.reorderLevel)") }
            )
        case .priceAnalytics:
            let itemsWithPricing = items.filter { $0.lowestPricePaid != nil }
            WidgetCard(
                title: "Best Prices",
                value: itemsWithPricing.count,
                icon: item.icon,
                color: item.color,
                size: size,
                items: itemsWithPricing.compactMap { item in
                    guard let price = item.lowestPricePaid else { return nil }
                    return (item.name, price.formatted(.currency(code: "USD")))
                }
            )
        }
    }

    private func loadSettings() {
        if let decoded = try? JSONDecoder().decode([DashboardItem].self, from: itemOrderData) {
            var order = decoded
            for item in DashboardItem.allCases {
                if !order.contains(item) {
                    order.append(item)
                }
            }
            order = order.filter { DashboardItem.allCases.contains($0) }
            itemOrder = order
        }

        if let decoded = try? JSONDecoder().decode([String: WidgetSize].self, from: widgetSizesData) {
            var sizes: [DashboardItem: WidgetSize] = [:]
            for (key, value) in decoded {
                if let item = DashboardItem(rawValue: key) {
                    sizes[item] = value
                }
            }
            widgetSizes = sizes
        }
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(itemOrder) {
            itemOrderData = encoded
        }

        let sizesDict = Dictionary(uniqueKeysWithValues: widgetSizes.map { ($0.key.rawValue, $0.value) })
        if let encoded = try? JSONEncoder().encode(sizesDict) {
            widgetSizesData = encoded
        }
    }
}

struct DashboardItemDropDelegate: DropDelegate {
    let item: DashboardItem
    @Binding var items: [DashboardItem]
    @Binding var draggingItem: DashboardItem?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        onReorder()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem != item,
              let fromIndex = items.firstIndex(of: draggingItem),
              let toIndex = items.firstIndex(of: item) else { return }

        withAnimation(.default) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// Unified widget card that adapts to size
struct WidgetCard: View {
    let title: String
    let value: Any
    let icon: String
    let color: Color
    let size: WidgetSize
    let items: [(name: String, detail: String)]

    private var displayValue: String {
        if let intVal = value as? Int {
            return "\(intVal)"
        } else if let doubleVal = value as? Double {
            return doubleVal.formatted(.currency(code: "USD"))
        }
        return "\(value)"
    }

    private var maxItems: Int {
        switch size {
        case .small: return 0
        case .medium: return 3
        case .large: return 8
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .small ? 8 : 10) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(size == .small ? .title2 : .title2)
                    .foregroundStyle(color)

                if size != .small {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                if size != .small {
                    Text(displayValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                }
            }

            if size == .small {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                // List items for medium and large
                if items.isEmpty {
                    Spacer()
                    Text("No items")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: size == .large ? 8 : 6) {
                            ForEach(items.prefix(maxItems), id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.body)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if items.count > maxItems {
                                Text("+\(items.count - maxItems) more")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(size == .small ? 12 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
