import SwiftUI
import SwiftData

enum DashboardItem: String, CaseIterable, Identifiable, Codable {
    // Small cards (1x1 square)
    case totalItems = "Total Items"
    case lowStock = "Low Stock"
    case expiringSoon = "Expiring Soon"
    case inventoryValue = "Inventory Value"
    // Large modules (2x1 rectangle)
    case reorderAlerts = "Reorder Alerts"
    case priceAnalytics = "Price Analytics"

    var id: String { rawValue }

    var isLarge: Bool {
        switch self {
        case .reorderAlerts, .priceAnalytics:
            return true
        default:
            return false
        }
    }

    var colSpan: Int {
        isLarge ? 2 : 1
    }
}

struct GridCell: Equatable {
    let item: DashboardItem
    let row: Int
    let col: Int
    let colSpan: Int
}

struct DashboardView: View {
    @Query private var items: [Item]
    @Query private var purchases: [Purchase]
    @Query private var vendors: [Vendor]

    @AppStorage("dashboardItemOrder") private var itemOrderData: Data = Data()

    @State private var itemOrder: [DashboardItem] = DashboardItem.allCases
    @State private var draggingItem: DashboardItem?

    private let columns = 4
    private let spacing: CGFloat = 12

    var itemsNeedingReorder: [Item] {
        items.filter { $0.needsReorder }
    }

    var expiringItems: [(item: Item, purchase: Purchase, daysLeft: Int)] {
        InventoryCalculator.itemsExpiringWithin(days: 30, from: items)
    }

    var totalInventoryValue: Double {
        InventoryCalculator.totalInventoryValue(for: items)
    }

    // Compute grid layout: place items left-to-right, top-to-bottom
    // Small items take 1 column, large items take 2 columns
    var gridLayout: (cells: [GridCell], rowCount: Int) {
        var cells: [GridCell] = []
        var grid: [[Bool]] = [[Bool](repeating: false, count: columns)]

        func ensureRow(_ row: Int) {
            while grid.count <= row {
                grid.append([Bool](repeating: false, count: columns))
            }
        }

        func findPosition(span: Int) -> (row: Int, col: Int) {
            var row = 0
            while true {
                ensureRow(row)
                for col in 0...(columns - span) {
                    var canPlace = true
                    for c in col..<(col + span) {
                        if grid[row][c] {
                            canPlace = false
                            break
                        }
                    }
                    if canPlace {
                        return (row, col)
                    }
                }
                row += 1
            }
        }

        for item in itemOrder {
            let span = item.colSpan
            let pos = findPosition(span: span)
            cells.append(GridCell(item: item, row: pos.row, col: pos.col, colSpan: span))
            ensureRow(pos.row)
            for c in pos.col..<(pos.col + span) {
                grid[pos.row][c] = true
            }
        }

        return (cells, grid.count)
    }

    // Fixed widget size (similar to macOS small widget ~141pt)
    private let cellSize: CGFloat = 141

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

                        draggableCard(for: cell.item, size: CGSize(width: width, height: cellSize))
                            .frame(width: width, height: cellSize)
                            .offset(x: x, y: y)
                    }
                }
                .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity)
                .padding(20)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: itemOrder)
            }
            .frame(minWidth: 600, minHeight: 400)
            .navigationTitle("Dashboard")
        }
        .onAppear {
            loadItemOrder()
        }
    }

    @ViewBuilder
    private func draggableCard(for item: DashboardItem, size: CGSize) -> some View {
        cardView(for: item)
            .id(item.id)
            .onDrag {
                draggingItem = item
                return NSItemProvider(object: item.rawValue as NSString)
            } preview: {
                cardView(for: item)
                    .frame(width: min(size.width, 200), height: min(size.height, 120))
                    .background(Color(nsColor: .windowBackgroundColor))
                    .compositingGroup()
                    .drawingGroup()
            }
            .onDrop(of: [.text], delegate: DashboardItemDropDelegate(
                item: item,
                items: $itemOrder,
                draggingItem: $draggingItem,
                onReorder: saveItemOrder
            ))
    }

    @ViewBuilder
    private func cardView(for item: DashboardItem) -> some View {
        switch item {
        case .totalItems:
            SummaryCard(
                title: "Total Items",
                value: "\(items.count)",
                icon: "shippingbox.fill",
                color: .blue
            )
        case .lowStock:
            SummaryCard(
                title: "Low Stock",
                value: "\(itemsNeedingReorder.count)",
                icon: "exclamationmark.triangle.fill",
                color: itemsNeedingReorder.isEmpty ? .green : .orange
            )
        case .expiringSoon:
            SummaryCard(
                title: "Expiring Soon",
                value: "\(expiringItems.count)",
                icon: "clock.fill",
                color: expiringItems.isEmpty ? .green : .red
            )
        case .inventoryValue:
            SummaryCard(
                title: "Inventory Value",
                value: totalInventoryValue.formatted(.currency(code: "USD")),
                icon: "dollarsign.circle.fill",
                color: .green
            )
        case .reorderAlerts:
            ReorderAlertsCard(items: itemsNeedingReorder)
        case .priceAnalytics:
            PriceAnalyticsCard(items: items)
        }
    }

    private func loadItemOrder() {
        if let decoded = try? JSONDecoder().decode([DashboardItem].self, from: itemOrderData) {
            var order = decoded
            for item in DashboardItem.allCases {
                if !order.contains(item) {
                    order.append(item)
                }
            }
            // Remove items that no longer exist
            order = order.filter { DashboardItem.allCases.contains($0) }
            itemOrder = order
        }
    }

    private func saveItemOrder() {
        if let encoded = try? JSONEncoder().encode(itemOrder) {
            itemOrderData = encoded
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

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// Large card for reorder alerts (2x1)
struct ReorderAlertsCard: View {
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Reorder Alerts")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(items.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(items.isEmpty ? .green : .orange)
            }

            if items.isEmpty {
                Spacer()
                Text("All items stocked")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items.prefix(3)) { item in
                            HStack {
                                Text(item.name)
                                    .font(.body)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.currentInventory)/\(item.reorderLevel)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if items.count > 3 {
                            Text("+\(items.count - 3) more")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// Large card for price analytics (2x1)
struct PriceAnalyticsCard: View {
    let items: [Item]

    var itemsWithPricing: [Item] {
        items.filter { $0.lowestPricePaid != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Best Prices")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(itemsWithPricing.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }

            if itemsWithPricing.isEmpty {
                Spacer()
                Text("No purchase history yet")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(itemsWithPricing.prefix(3)) { item in
                            HStack {
                                Text(item.name)
                                    .font(.body)
                                    .lineLimit(1)
                                Spacer()
                                if let price = item.lowestPricePaid {
                                    Text(price, format: .currency(code: "USD"))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        if itemsWithPricing.count > 3 {
                            Text("+\(itemsWithPricing.count - 3) more")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
