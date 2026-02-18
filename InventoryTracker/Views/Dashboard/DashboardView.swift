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
    case items = "Items"
    case lowStock = "Low Stock"
    case expiringSoon = "Expiring Soon"
    case inventoryValue = "Inventory Value"
    case priceAnalytics = "Price Analytics"
    case vendors = "Vendors"
    case purchases = "Recent Purchases"
    case usage = "Recent Usage"

    var id: String { rawValue }

    var defaultSize: WidgetSize {
        switch self {
        case .items, .lowStock, .expiringSoon, .inventoryValue, .vendors, .purchases, .usage:
            return .small
        case .priceAnalytics:
            return .medium
        }
    }

    var icon: String {
        switch self {
        case .items: return "shippingbox.fill"
        case .lowStock: return "exclamationmark.triangle.fill"
        case .expiringSoon: return "clock.fill"
        case .inventoryValue: return "dollarsign.circle.fill"
        case .priceAnalytics: return "dollarsign.circle.fill"
        case .vendors: return "building.2.fill"
        case .purchases: return "cart.fill"
        case .usage: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .items: return .blue
        case .lowStock: return .orange
        case .expiringSoon: return .red
        case .inventoryValue: return .green
        case .priceAnalytics: return .green
        case .vendors: return .purple
        case .purchases: return .cyan
        case .usage: return .pink
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
    @Binding var selectedTab: ContentView.AppTab
    @Environment(\.openWindow) private var openWindow
    @Query private var items: [Item]
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @Query private var vendors: [Vendor]
    @Query(sort: \Usage.date, order: .reverse) private var usages: [Usage]

    @AppStorage("dashboardItemOrder") private var itemOrderData: Data = Data()
    @AppStorage("dashboardWidgetSizes") private var widgetSizesData: Data = Data()

    @State private var itemOrder: [DashboardItem] = DashboardItem.allCases
    @State private var widgetSizes: [DashboardItem: WidgetSize] = [:]
    @State private var draggingItem: DashboardItem?
    @State private var droppingItem: DashboardItem?

    private let columns = 4
    private let spacing: CGFloat = 18
    private let cellSize: CGFloat = 165

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

    private func targetTab(for item: DashboardItem) -> ContentView.AppTab? {
        switch item {
        case .items, .lowStock, .expiringSoon, .inventoryValue, .priceAnalytics:
            return .items
        case .vendors:
            return .vendors
        case .purchases:
            return .purchases
        case .usage:
            return .usage
        }
    }

    @ViewBuilder
    private func draggableCard(for item: DashboardItem, size: CGSize) -> some View {
        let currentSize = sizeFor(item)

        cardView(for: item, size: currentSize)
            .id(item.id)
            .contentShape(Rectangle())
            .onTapGesture {
                if currentSize == .small, let tab = targetTab(for: item) {
                    selectedTab = tab
                }
            }
            .contextMenu {
                Section("Size") {
                    ForEach(WidgetSize.allCases, id: \.self) { widgetSize in
                        Button {
                            withAnimation {
                                widgetSizes[item] = widgetSize
                                saveSettings()
                            }
                        } label: {
                            Label(widgetSize.rawValue, systemImage: currentSize == widgetSize ? "checkmark" : "")
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
            .opacity(draggingItem == item ? 0.4 : (droppingItem == item ? 0 : 1.0))
            .onDrag {
                draggingItem = item
                return NSItemProvider(object: item.rawValue as NSString)
            } preview: {
                cardView(for: item, size: currentSize, isPreview: true)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .onDrop(of: [.text], delegate: DashboardItemDropDelegate(
                item: item,
                items: $itemOrder,
                draggingItem: $draggingItem,
                droppingItem: $droppingItem,
                onReorder: saveSettings
            ))
    }

    @ViewBuilder
    private func cardView(for item: DashboardItem, size: WidgetSize, isPreview: Bool = false) -> some View {
        switch item {
        case .items:
            WidgetCard(
                title: "Items",
                value: items.count,
                icon: item.icon,
                color: item.color,
                size: size,
                items: items.map { WidgetItem(name: $0.name, detail: "\($0.currentInventory) \($0.unit.abbreviation)", id: $0.id, showPill: false) },
                isPreview: isPreview,
                onItemTap: { id in openWindow(value: ItemWindowID(id: id)) },
                onMoreTap: { selectedTab = .items }
            )
        case .lowStock:
            WidgetCard(
                title: "Low Stock",
                value: itemsNeedingReorder.count,
                icon: item.icon,
                color: itemsNeedingReorder.isEmpty ? .green : item.color,
                size: size,
                items: itemsNeedingReorder.map { WidgetItem(name: $0.name, detail: "\($0.currentInventory)/\($0.reorderLevel)", id: $0.id) },
                isPreview: isPreview,
                onItemTap: { id in openWindow(value: ItemWindowID(id: id)) },
                onMoreTap: { selectedTab = .items }
            )
        case .expiringSoon:
            WidgetCard(
                title: "Expiring Soon",
                value: expiringItems.count,
                icon: item.icon,
                color: expiringItems.isEmpty ? .green : item.color,
                size: size,
                items: expiringItems.map { WidgetItem(name: $0.item.name, detail: "\($0.daysLeft) days", id: $0.item.id) },
                isPreview: isPreview,
                onItemTap: { id in openWindow(value: ItemWindowID(id: id)) },
                onMoreTap: { selectedTab = .items }
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
                    return WidgetItem(name: item.name, detail: value.formatted(.currency(code: "USD")), id: item.id)
                },
                isPreview: isPreview,
                onItemTap: { id in openWindow(value: ItemWindowID(id: id)) },
                onMoreTap: { selectedTab = .items }
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
                    return WidgetItem(name: item.name, detail: price.formatted(.currency(code: "USD")), id: item.id)
                },
                isPreview: isPreview,
                onItemTap: { id in openWindow(value: ItemWindowID(id: id)) },
                onMoreTap: { selectedTab = .items }
            )
        case .vendors:
            WidgetCard(
                title: "Vendors",
                value: vendors.count,
                icon: item.icon,
                color: item.color,
                size: size,
                items: vendors.map { WidgetItem(name: $0.name, detail: $0.phone, id: $0.id) },
                isPreview: isPreview,
                onItemTap: { id in openWindow(value: VendorWindowID(id: id)) },
                onMoreTap: { selectedTab = .vendors }
            )
        case .purchases:
            WidgetCard(
                title: "Recent Purchases",
                value: purchases.count,
                icon: item.icon,
                color: item.color,
                size: size,
                items: purchases.prefix(10).map { purchase in
                    let itemName = purchase.item?.name ?? "Unknown"
                    let detail = "\(purchase.date.formatted(date: .abbreviated, time: .omitted)) · \(purchase.totalCost.formatted(.currency(code: "USD")))"
                    return WidgetItem(name: itemName, detail: detail, id: purchase.item?.id)
                },
                isPreview: isPreview,
                onItemTap: { id in openWindow(value: ItemWindowID(id: id)) },
                onMoreTap: { selectedTab = .purchases }
            )
        case .usage:
            WidgetCard(
                title: "Recent Usage",
                value: usages.count,
                icon: item.icon,
                color: item.color,
                size: size,
                items: usages.prefix(10).map { usage in
                    let itemName = usage.item?.name ?? "Unknown"
                    let detail = "\(usage.date.formatted(date: .abbreviated, time: .omitted)) · \(usage.quantity) used"
                    return WidgetItem(name: itemName, detail: detail, id: usage.item?.id)
                },
                isPreview: isPreview,
                onItemTap: { id in openWindow(value: ItemWindowID(id: id)) },
                onMoreTap: { selectedTab = .usage }
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
    @Binding var droppingItem: DashboardItem?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        droppingItem = draggingItem
        draggingItem = nil
        onReorder()

        // Show the widget after the drag preview animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            droppingItem = nil
        }
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

struct WidgetItem: Identifiable {
    let id: UUID?
    let name: String
    let detail: String
    let showPill: Bool

    init(name: String, detail: String, id: UUID? = nil, showPill: Bool = true) {
        self.id = id
        self.name = name
        self.detail = detail
        self.showPill = showPill
    }
}

// Unified widget card that adapts to size
struct WidgetCard: View {
    let title: String
    let value: Any
    let icon: String
    let color: Color
    let size: WidgetSize
    let items: [WidgetItem]
    var isPreview: Bool = false
    var onItemTap: ((UUID) -> Void)? = nil
    var onMoreTap: (() -> Void)? = nil

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
        case .medium: return 2
        case .large: return 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .small ? 8 : 14) {
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
            .padding(.horizontal, size == .small ? 0 : 4)

            if size == .small {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(title)
                            .font(.title3)
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
                } else if size == .medium {
                    // Medium: top 2 items with +X more
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.prefix(maxItems).enumerated()), id: \.element.name) { index, item in
                            if index > 0 {
                                Divider()
                                    .padding(.horizontal, 4)
                            }
                            itemRow(item: item)
                        }
                        if items.count > maxItems {
                            Divider()
                                .padding(.horizontal, 4)
                            moreButton(count: items.count - maxItems)
                        }
                    }
                } else {
                    // Large: top 8 items without scroll
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.prefix(maxItems).enumerated()), id: \.element.name) { index, item in
                            if index > 0 {
                                Divider()
                                    .padding(.horizontal, 4)
                            }
                            itemRow(item: item)
                        }
                        if items.count > maxItems {
                            Divider()
                                .padding(.horizontal, 4)
                            moreButton(count: items.count - maxItems)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, size == .small ? 14 : 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func itemRow(item: WidgetItem) -> some View {
        let rowContent = HStack(spacing: 8) {
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(item.showPill ? color : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(item.showPill ? color.opacity(0.15) : .clear)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)

        if let id = item.id, let onItemTap = onItemTap {
            Button {
                onItemTap(id)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    @ViewBuilder
    private func moreButton(count: Int) -> some View {
        if let onMoreTap = onMoreTap {
            Button {
                onMoreTap()
            } label: {
                Text("+\(count) more")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        } else {
            Text("+\(count) more")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
        }
    }
}

#Preview {
    @Previewable @State var selectedTab: ContentView.AppTab = .dashboard
    DashboardView(selectedTab: $selectedTab)
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
