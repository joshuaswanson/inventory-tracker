import SwiftData
import SwiftUI

private struct TileDropDelegate: DropDelegate {
    let target: DashboardWidget
    @Binding var layout: DashboardLayout
    @Binding var dragging: DashboardWidget?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { layout.move(dragging, onto: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

private struct ResizeStart {
    var widget: DashboardWidget
    var size: DashboardTileSize
    var tileSize: CGSize
    var cellWidth: CGFloat
    var translation = CGSize.zero

    /// Follows the pointer, but never smaller than the smallest box or bigger than the biggest.
    func draggedSize(spacing: CGFloat) -> CGSize {
        let largest = DashboardTileSize.extraLarge
        func length(_ cells: Int, _ cell: CGFloat) -> CGFloat { cell * CGFloat(cells) + spacing * CGFloat(cells - 1) }
        return CGSize(
            width: min(max(cellWidth, tileSize.width + translation.width), length(largest.columns, cellWidth)),
            height: min(max(DashboardGrid.cellHeight, tileSize.height + translation.height), length(largest.rows, DashboardGrid.cellHeight))
        )
    }
}

/// A thick stroke that hugs the rounded bottom right corner of a box.
nonisolated private struct CornerHandle: Shape {
    var radius: CGFloat
    var inset: CGFloat
    var arm: CGFloat

    func path(in rect: CGRect) -> Path {
        let right = rect.maxX - inset
        let bottom = rect.maxY - inset
        var path = Path()
        path.move(to: CGPoint(x: right, y: bottom - radius - arm))
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addArc(center: CGPoint(x: right - radius, y: bottom - radius), radius: radius, startAngle: .zero, endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: right - radius - arm, y: bottom))
        return path
    }
}

struct DashboardView: View {
    private static let rowLimit = 12
    private static let chartMonths = 12
    private static let gridSpacing: CGFloat = 16
    private static let layoutAnimation = Animation.spring(response: 0.5, dampingFraction: 0.82)

    @Query private var items: [Item]
    @Query private var vendors: [Vendor]
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @Query(sort: \UsageRecord.date, order: .reverse) private var usage: [UsageRecord]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext
    @State private var layout = DashboardLayout.load()
    @State private var isEditing = DashboardView.startsInEditMode
    @State private var dragging: DashboardWidget?
    @State private var hovered: DashboardWidget?
    @State private var resizeStart: ResizeStart?

    private static var startsInEditMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["INVENTORY_DASHBOARD_EDIT"] != nil
        #else
        false
        #endif
    }

    var body: some View {
        Screen(title: "Dashboard") {
            if !items.isEmpty { editActions }
            if !isWide {
                Button {
                    router.sheet = .data
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        } content: {
            if items.isEmpty {
                welcome
            } else {
                if isEditing { editHint }
                let rows = ItemRow.rows(for: items).sorted { orderedText($0.item.name, $1.item.name, ascending: true) }
                DashboardGrid(spacing: Self.gridSpacing) {
                    ForEach(layout.tiles) { tile in
                        editable(tile) {
                            DashboardTileView(content: content(for: tile.widget, rows: rows), size: tile.size)
                        }
                        .layoutValue(key: DashboardTileSizeKey.self, value: tile.size)
                    }
                }
                .animation(Self.layoutAnimation, value: layout)
                if layout.tiles.isEmpty {
                    PlaceholderText("Your dashboard is empty. Press Customize, then Add a Widget.")
                }
            }
        }
        .onChange(of: layout) { layout.save() }
    }

    @ViewBuilder
    private var editActions: some View {
        if isEditing {
            if !layout.hidden.isEmpty {
                Menu("Add a Widget") {
                    ForEach(layout.hidden) { widget in
                        Button(widget.title) { withAnimation(Self.layoutAnimation) { layout.add(widget) } }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.themedSecondary)
                .fixedSize()
            }
            if layout != .standard {
                Button("Reset") { withAnimation(Self.layoutAnimation) { layout = .standard } }
                    .buttonStyle(.themedSecondary)
            }
            Button("Done") {
                dragging = nil
                isEditing = false
            }
            .buttonStyle(.themedPrimary)
        } else if isWide {
            Button("Customize") { isEditing = true }
                .buttonStyle(.themedSecondary)
        } else {
            Button {
                isEditing = true
            } label: {
                Label("Customize", systemImage: "square.grid.2x2")
            }
        }
    }

    private var editHint: some View {
        Label("Drag a widget to move it. Drag its bottom right corner to make it bigger or smaller. Both also work any time, without Customize.", systemImage: "hand.draw")
            .font(.system(size: 13))
            .foregroundStyle(Theme.primaryDarker)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.primaryBackground, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .padding(.bottom, 16)
    }

    /// The grid sizes an invisible placeholder. The box itself sits on top of it, so it can
    /// follow the pointer while its corner is dragged without disturbing the other boxes.
    private func editable<Content: View>(_ tile: DashboardTile, @ViewBuilder content: @escaping () -> Content) -> some View {
        let dragged = resizeStart.flatMap { $0.widget == tile.widget ? $0.draggedSize(spacing: Self.gridSpacing) : nil }
        return Color.clear
            .overlay(alignment: .topLeading) {
                GeometryReader { geometry in
                    box(tile, slotSize: geometry.size, content: content)
                        .frame(width: dragged?.width ?? geometry.size.width, height: dragged?.height ?? geometry.size.height)
                        .shadow(color: .black.opacity(dragged == nil ? 0 : 0.16), radius: 14, y: 6)
                }
            }
            .zIndex(dragged == nil ? 0 : 1)
    }

    private func box<Content: View>(_ tile: DashboardTile, slotSize: CGSize, content: () -> Content) -> some View {
        content()
            .allowsHitTesting(!isEditing)
            .overlay {
                if isEditing {
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(Theme.primary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                }
            }
            .contentShape(Rectangle())
            .onDrag {
                dragging = tile.widget
                return NSItemProvider(object: tile.widget.rawValue as NSString)
            }
            .onDrop(of: [.plainText], delegate: TileDropDelegate(target: tile.widget, layout: $layout, dragging: $dragging))
            .overlay(alignment: .topTrailing) {
                if isEditing { removeButton(tile) }
            }
            .overlay(alignment: .bottomTrailing) {
                resizeHandle(tile, tileSize: slotSize)
            }
            .onHover { isInside in
                if isInside { hovered = tile.widget } else if hovered == tile.widget { hovered = nil }
            }
            .contextMenu {
                Menu("Size") {
                    ForEach(DashboardTileSize.allCases) { size in
                        Button {
                            withAnimation(Self.layoutAnimation) { layout.resize(tile.widget, to: size) }
                        } label: {
                            if size == tile.size {
                                Label(size.title, systemImage: "checkmark")
                            } else {
                                Text(size.title)
                            }
                        }
                    }
                }
                Button("Remove from Dashboard", role: .destructive) {
                    withAnimation(Self.layoutAnimation) { layout.hide(tile.widget) }
                }
                if !isEditing {
                    Button("Customize Dashboard") { isEditing = true }
                }
            }
    }

    private func removeButton(_ tile: DashboardTile) -> some View {
        RowIconButton(systemImage: "xmark", isDestructive: true, label: "Remove \(tile.widget.title)") {
            withAnimation(Self.layoutAnimation) { layout.hide(tile.widget) }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        .padding(8)
    }

    private func resizeHandle(_ tile: DashboardTile, tileSize: CGSize) -> some View {
        let isActive = resizeStart?.widget == tile.widget
        let isVisible = isEditing || isActive || hovered == tile.widget
        return CornerHandle(radius: Theme.radius - 4, inset: 5, arm: 7)
            .stroke(isActive ? Theme.primary : Theme.textTertiary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: isVisible)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { drag in
                        if resizeStart?.widget != tile.widget {
                            let columns = CGFloat(tile.size.columns)
                            resizeStart = ResizeStart(
                                widget: tile.widget,
                                size: tile.size,
                                tileSize: tileSize,
                                cellWidth: (tileSize.width - Self.gridSpacing * (columns - 1)) / columns
                            )
                        }
                        guard var start = resizeStart else { return }
                        start.translation = drag.translation
                        resizeStart = start
                        let columns = start.size.columns + Int((drag.translation.width / (start.cellWidth + Self.gridSpacing)).rounded())
                        let rows = start.size.rows + Int((drag.translation.height / (DashboardGrid.cellHeight + Self.gridSpacing)).rounded())
                        let size = DashboardTileSize.closest(columns: columns, rows: rows)
                        if size != tile.size {
                            withAnimation(Self.layoutAnimation) { layout.resize(tile.widget, to: size) }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) { resizeStart = nil }
                    }
            )
            .help("Drag to resize")
            .accessibilityLabel("Resize \(tile.widget.title)")
    }

    private func content(for widget: DashboardWidget, rows: [ItemRow]) -> WidgetContent {
        switch widget {
        case .items: itemsContent(rows)
        case .lowStock: lowStockContent(rows)
        case .expiring: expiringContent(rows)
        case .vendors: vendorsContent()
        case .inventoryValue: valueContent(rows)
        case .spending: spendingContent()
        case .purchases: purchasesContent()
        case .usage: usageContent()
        }
    }

    private func openItem(_ id: String) -> () -> Void {
        {
            router.show(.items)
            router.open(.item(id))
        }
    }

    private func plural(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    private func itemsContent(_ rows: [ItemRow]) -> WidgetContent {
        let out = rows.filter { $0.metrics.currentInventory <= 0 }.count
        let low = rows.filter { $0.metrics.needsReorder && $0.metrics.currentInventory > 0 }.count
        let month = String(Day.today.prefix(7))
        func show(_ filter: ItemFilter) -> () -> Void { { router.show(.items, itemFilter: filter) } }
        return WidgetContent(
            systemImage: "archivebox.fill", tone: .blue, title: "Items", value: "\(rows.count)",
            caption: "\(rows.count - out - low) well stocked",
            rows: [
                WidgetRow(id: "in", label: "Well stocked", trailing: "\(rows.count - out - low)", action: show(.all)),
                WidgetRow(id: "low", label: "Running low", trailing: "\(low)", action: show(.low)),
                WidgetRow(id: "out", label: "Out of stock", trailing: "\(out)", action: show(.out)),
                WidgetRow(id: "perishable", label: "Can expire", trailing: "\(rows.filter(\.item.isPerishable).count)", action: show(.perishable)),
                WidgetRow(id: "new", label: "Added this month", trailing: "\(rows.filter { $0.item.createdAt.hasPrefix(month) }.count)", action: show(.all)),
            ],
            links: [WidgetLink(title: "All Items") { router.show(.items) }],
            action: { router.show(.items) }
        )
    }

    private func lowStockContent(_ rows: [ItemRow]) -> WidgetContent {
        let low = rows.filter(\.metrics.needsReorder)
        return WidgetContent(
            systemImage: "exclamationmark.triangle.fill", tone: .amber, title: "Low Stock", value: "\(low.count)",
            valueColor: low.isEmpty ? Theme.text : Theme.amber,
            caption: "",
            rows: low.prefix(Self.rowLimit).map { row in
                WidgetRow(
                    id: row.id, label: row.item.name,
                    trailing: "\(row.metrics.currentInventory) / \(row.item.reorderLevel) \(row.item.unitAbbreviation)",
                    badge: row.metrics.currentInventory <= 0 ? Badge(text: "Out", tone: .red) : Badge(text: "Low", tone: .amber),
                    action: openItem(row.item.id)
                )
            },
            emptyMessage: "All items are well stocked.",
            links: [WidgetLink(title: "Shopping List") { router.sheet = .reorder }]
                + (low.count > 3 ? [WidgetLink(title: "See All \(low.count)") { router.show(.items, itemFilter: .low) }] : []),
            action: { router.show(.items, itemFilter: .low) }
        )
    }

    private func expiringContent(_ rows: [ItemRow]) -> WidgetContent {
        let expiring = rows.filter(\.metrics.isExpiringSoon)
            .sorted { ($0.metrics.daysUntilExpiration ?? 0) < ($1.metrics.daysUntilExpiration ?? 0) }
        return WidgetContent(
            systemImage: "clock.fill", tone: .red, title: "Expiring Soon", value: "\(expiring.count)",
            valueColor: expiring.isEmpty ? Theme.text : Theme.red,
            caption: "",
            rows: expiring.prefix(Self.rowLimit).map { row in
                let days = row.metrics.daysUntilExpiration ?? 0
                return WidgetRow(
                    id: row.id, label: row.item.name, trailing: Format.shortDate(row.metrics.nextExpiration),
                    badge: Badge(text: days < 0 ? "Expired" : "\(days)d", tone: days <= 7 ? .red : .amber),
                    action: openItem(row.item.id)
                )
            },
            emptyMessage: "Nothing expiring in the next 30 days.",
            links: expiring.count > 3 ? [WidgetLink(title: "See All \(expiring.count)") { router.show(.items, itemFilter: .expiring) }] : [],
            action: { router.show(.items, itemFilter: .expiring) }
        )
    }

    private func vendorsContent() -> WidgetContent {
        let ranked = vendors.map { ($0, $0.totalSpent) }.sorted { ($1.1, $0.0.name) < ($0.1, $1.0.name) }
        return WidgetContent(
            systemImage: "building.2.fill", tone: .purple, title: "Vendors", value: "\(vendors.count)",
            caption: ranked.first.map { "Most spent at \($0.0.name)" } ?? "No vendors yet",
            rows: ranked.prefix(Self.rowLimit).map { vendor, spent in
                WidgetRow(id: vendor.id, label: vendor.name, trailing: Format.currency(spent)) {
                    router.show(.vendors)
                    router.open(.vendor(vendor.id))
                }
            },
            emptyMessage: "No vendors yet.",
            links: [WidgetLink(title: "All Vendors") { router.show(.vendors) }],
            action: { router.show(.vendors) }
        )
    }

    private func valueContent(_ rows: [ItemRow]) -> WidgetContent {
        let valued = rows.compactMap { row -> (ItemRow, Double)? in
            guard let price = row.metrics.averagePrice, row.metrics.currentInventory > 0 else { return nil }
            return (row, roundedToCents(price * Double(row.metrics.currentInventory)))
        }.sorted { ($1.1, $0.0.item.name) < ($0.1, $1.0.item.name) }
        return WidgetContent(
            systemImage: "dollarsign.circle.fill", tone: .green, title: "Inventory Value",
            value: Format.currency(ItemRow.totalValue(rows)), valueColor: Theme.green,
            caption: "",
            rows: valued.prefix(Self.rowLimit).map { row, value in
                WidgetRow(id: row.id, label: row.item.name, trailing: Format.currency(value), action: openItem(row.item.id))
            },
            emptyMessage: "Nothing in stock yet.",
            links: [WidgetLink(title: "All Items") { router.show(.items) }],
            action: { router.show(.items) }
        )
    }

    private func spendingContent() -> WidgetContent {
        let today = Day.today
        let year = Int(today.prefix(4)) ?? 0
        let month = Int(today.dropFirst(5).prefix(2)) ?? 1
        func key(monthsBack: Int) -> String {
            let index = year * 12 + month - 1 - monthsBack
            return String(format: "%04d-%02d", index / 12, index % 12 + 1)
        }
        func total(_ prefix: String) -> Double {
            roundedToCents(purchases.filter { $0.date.hasPrefix(prefix) }.reduce(0) { $0 + $1.totalCost })
        }
        let thisMonth = total(key(monthsBack: 0))
        let show = { router.sheet = .spending }
        return WidgetContent(
            systemImage: "creditcard.fill", tone: .green, title: "Spending", value: Format.currency(thisMonth),
            caption: "this month",
            rows: [
                WidgetRow(id: "month", label: "This month", trailing: Format.currency(thisMonth), action: show),
                WidgetRow(id: "last-month", label: "Last month", trailing: Format.currency(total(key(monthsBack: 1))), action: show),
                WidgetRow(id: "year", label: "This year", trailing: Format.currency(total("\(year)-")), action: show),
                WidgetRow(id: "last-year", label: "Last year", trailing: Format.currency(total("\(year - 1)-")), action: show),
                WidgetRow(id: "all", label: "All time", trailing: Format.currency(roundedToCents(purchases.reduce(0) { $0 + $1.totalCost })), action: show),
            ],
            chart: (0..<Self.chartMonths).reversed().map { SpendingTotal(name: key(monthsBack: $0), total: total(key(monthsBack: $0))) },
            links: [WidgetLink(title: "Spending Report", action: show)],
            action: show
        )
    }

    private func purchasesContent() -> WidgetContent {
        let month = String(Day.today.prefix(7))
        let thisMonth = purchases.filter { $0.date.hasPrefix(month) }.count
        return WidgetContent(
            systemImage: "cart.fill", tone: .blue, title: "Purchases", value: "\(thisMonth)",
            caption: "this month, \(purchases.count) in all",
            rows: purchases.prefix(Self.rowLimit).map { purchase in
                WidgetRow(
                    id: purchase.id, label: purchase.item?.name ?? "Unknown",
                    trailing: "\(Format.shortDate(purchase.date))  \(Format.currency(purchase.totalCost))",
                    action: purchase.item.map { openItem($0.id) }
                )
            },
            emptyMessage: "No purchases yet.",
            links: [
                WidgetLink(title: "All Purchases") { router.show(.purchases) },
                WidgetLink(title: "Import Orders") { router.sheet = .importOrders },
            ],
            action: { router.show(.purchases) }
        )
    }

    private func usageContent() -> WidgetContent {
        let month = String(Day.today.prefix(7))
        let used = usage.filter { !$0.isAdjustment }
        let thisMonth = used.filter { $0.date.hasPrefix(month) }.reduce(0) { $0 + $1.quantity }
        return WidgetContent(
            systemImage: "chart.bar.doc.horizontal.fill", tone: .purple, title: "Usage", value: "\(thisMonth)",
            caption: "used this month",
            rows: used.prefix(Self.rowLimit).map { record in
                WidgetRow(
                    id: record.id, label: record.item?.name ?? "Unknown",
                    trailing: "\(Format.shortDate(record.date))  \(record.quantityText)",
                    action: record.item.map { openItem($0.id) }
                )
            },
            emptyMessage: "No usage recorded yet.",
            links: [
                WidgetLink(title: "All Usage") { router.show(.usage) },
                WidgetLink(title: "Record Usage") { router.sheet = .usage(nil, itemID: nil) },
            ],
            action: { router.show(.usage) }
        )
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "archivebox")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textTertiary.opacity(0.5))
                    .padding(.bottom, 8)
                Text("Welcome to Inventory Tracker")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Keep track of your supplies, see what is running low, and know what to reorder.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            ViewThatFits {
                HStack(spacing: 8) { welcomeButtons }
                VStack(spacing: 8) { welcomeButtons }
            }
            Button("Have a backup file? Restore it") { router.sheet = .data }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.primary)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .card()
    }

    @ViewBuilder
    private var welcomeButtons: some View {
        Button("Add Item") { router.sheet = .item(nil) }
            .buttonStyle(.themedPrimary)
        Button("Import Orders") { router.sheet = .importOrders }
            .buttonStyle(.themedSecondary)
        Button("Take a Quick Tour") { Tour.start(router: router, context: modelContext) }
            .buttonStyle(.themedSecondary)
    }
}
