import SwiftData
import SwiftUI

private struct DashboardData {
    var rows: [ItemRow]
    var lowStock: [ItemRow]
    var expiring: [ItemRow]
    var vendorCount: Int
    var spentThisMonth: Double
    var recentPurchases: [Purchase]
}

private struct TileDropDelegate: DropDelegate {
    let target: DashboardWidget
    @Binding var layout: DashboardLayout
    @Binding var dragging: DashboardWidget?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        withAnimation(.snappy(duration: 0.3)) { layout.move(dragging, onto: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

struct DashboardView: View {
    private static let recentPurchaseLimit = 5
    private static let alertLimit = 8

    @Query private var items: [Item]
    @Query private var vendors: [Vendor]
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext
    @State private var layout = DashboardLayout.load()
    @State private var isEditing = DashboardView.startsInEditMode
    @State private var dragging: DashboardWidget?

    private static var startsInEditMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["INVENTORY_DASHBOARD_EDIT"] != nil
        #else
        false
        #endif
    }

    private var data: DashboardData {
        let rows = ItemRow.rows(for: items).sorted { orderedText($0.item.name, $1.item.name, ascending: true) }
        let month = String(Day.today.prefix(7))
        return DashboardData(
            rows: rows,
            lowStock: rows.filter(\.metrics.needsReorder),
            expiring: rows.filter(\.metrics.isExpiringSoon)
                .sorted { ($0.metrics.daysUntilExpiration ?? 0) < ($1.metrics.daysUntilExpiration ?? 0) },
            vendorCount: vendors.count,
            spentThisMonth: roundedToCents(purchases.filter { $0.date.hasPrefix(month) }.reduce(0) { $0 + $1.totalCost }),
            recentPurchases: Array(purchases.prefix(Self.recentPurchaseLimit))
        )
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
                let data = data
                DashboardGrid {
                    ForEach(layout.tiles) { tile in
                        editable(tile) { widget(tile.widget, data: data) }
                            .layoutValue(key: DashboardTileSizeKey.self, value: tile.size)
                    }
                }
                .animation(.snappy(duration: 0.3), value: layout)
                if layout.tiles.isEmpty {
                    PlaceholderText("Your dashboard is empty. Press Customize, then Add a Box.")
                }
            }
        }
        .onChange(of: layout) { layout.save() }
    }

    @ViewBuilder
    private var editActions: some View {
        if isEditing {
            if !layout.hidden.isEmpty {
                Menu("Add a Box") {
                    ForEach(layout.hidden) { widget in
                        Button(widget.title) { withAnimation(.snappy) { layout.add(widget) } }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.themedSecondary)
                .fixedSize()
            }
            if layout != .standard {
                Button("Reset") { withAnimation(.snappy) { layout = .standard } }
                    .buttonStyle(.themedSecondary)
            }
            Button("Done") { finishEditing() }
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
        Label("Drag a box to move it, which also works any time without Customize. Use the buttons in a box's corner to change its size or remove it.", systemImage: "hand.draw")
            .font(.system(size: 13))
            .foregroundStyle(Theme.primaryDarker)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.primaryBackground, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .padding(.bottom, 16)
    }

    private func finishEditing() {
        dragging = nil
        isEditing = false
    }

    private func editable<Content: View>(_ tile: DashboardTile, @ViewBuilder content: () -> Content) -> some View {
        content()
            .allowsHitTesting(!isEditing)
            .overlay {
                if isEditing {
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(Theme.primary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                }
            }
            .overlay(alignment: .topTrailing) {
                if isEditing { tileControls(tile) }
            }
            .contentShape(Rectangle())
            .onDrag {
                dragging = tile.widget
                return NSItemProvider(object: tile.widget.rawValue as NSString)
            }
            .onDrop(of: [.plainText], delegate: TileDropDelegate(target: tile.widget, layout: $layout, dragging: $dragging))
    }

    private func tileControls(_ tile: DashboardTile) -> some View {
        let isLargest = tile.size == tile.widget.sizes.last
        return HStack(spacing: 2) {
            RowIconButton(
                systemImage: isLargest ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                label: isLargest ? "Make \(tile.widget.title) smaller" : "Make \(tile.widget.title) bigger"
            ) {
                withAnimation(.snappy(duration: 0.3)) { layout.resize(tile.widget) }
            }
            RowIconButton(systemImage: "xmark", isDestructive: true, label: "Remove \(tile.widget.title)") {
                withAnimation(.snappy(duration: 0.3)) { layout.hide(tile.widget) }
            }
        }
        .padding(2)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        .padding(8)
    }

    @ViewBuilder
    private func widget(_ widget: DashboardWidget, data: DashboardData) -> some View {
        switch widget {
        case .totalItems:
            StatCard(systemImage: "archivebox.fill", tone: .blue, label: "Total Items", value: "\(data.rows.count)") {
                router.show(.items)
            }
        case .lowStockCount:
            StatCard(
                systemImage: "exclamationmark.triangle.fill",
                tone: .amber,
                label: "Low Stock",
                value: "\(data.lowStock.count)",
                valueColor: data.lowStock.isEmpty ? Theme.text : Theme.amber
            ) {
                router.show(.items, itemFilter: .low)
            }
        case .expiringCount:
            StatCard(
                systemImage: "clock.fill",
                tone: .red,
                label: "Expiring Soon",
                value: "\(data.expiring.count)",
                valueColor: data.expiring.isEmpty ? Theme.text : Theme.red
            ) {
                router.show(.items, itemFilter: .expiring)
            }
        case .vendors:
            StatCard(systemImage: "building.2.fill", tone: .purple, label: "Vendors", value: "\(data.vendorCount)") {
                router.show(.vendors)
            }
        case .inventoryValue:
            StatCard(
                systemImage: "dollarsign.circle.fill",
                tone: .green,
                label: "Inventory Value",
                value: Format.currency(ItemRow.totalValue(data.rows)),
                valueColor: Theme.green
            )
        case .spentThisMonth:
            StatCard(systemImage: "creditcard.fill", tone: .green, label: "Spent This Month", value: Format.currency(data.spentThisMonth)) {
                router.sheet = .spending
            }
        case .lowStockAlerts:
            alertSection(
                title: "Low Stock Alerts",
                systemImage: "exclamationmark.triangle.fill",
                iconColor: Theme.amber,
                rows: data.lowStock,
                emptyMessage: "All items are well-stocked.",
                filter: .low,
                actionTitle: "Shopping List",
                action: { router.sheet = .reorder }
            ) { row in
                Text("\(row.metrics.currentInventory) / \(row.item.reorderLevel) \(row.item.unitAbbreviation)")
                    .foregroundStyle(Theme.textSecondary)
                StockBadge(metrics: row.metrics)
            }
        case .expiringList:
            alertSection(
                title: "Expiring Soon",
                systemImage: "clock.fill",
                iconColor: Theme.red,
                rows: data.expiring,
                emptyMessage: "Nothing expiring in the next 30 days.",
                filter: .expiring
            ) { row in
                Text(Format.shortDate(row.metrics.nextExpiration))
                    .foregroundStyle(Theme.textSecondary)
                ExpirationBadge(days: row.metrics.daysUntilExpiration, isEstimated: row.metrics.expirationIsEstimated)
            }
        case .recentPurchases:
            recentPurchases(data.recentPurchases)
        }
    }

    private func recentPurchases(_ purchases: [Purchase]) -> some View {
        DetailSection(title: "Recent Purchases", systemImage: "cart.fill", iconColor: Theme.primary) {
            if purchases.isEmpty {
                PlaceholderText("No purchases yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(purchases) { purchase in
                        MiniRow(showsDivider: purchase.id != purchases.last?.id) {
                            Text(purchase.item?.name ?? "Unknown")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Format.shortDate(purchase.date))
                                .foregroundStyle(Theme.textSecondary)
                            Text(Format.currency(purchase.totalCost)).fontWeight(.medium)
                        }
                    }
                }
                Button("All Purchases") { router.show(.purchases) }
                    .buttonStyle(.themedSecondary)
            }
        }
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

    private func alertSection<Trailing: View>(
        title: String,
        systemImage: String,
        iconColor: Color,
        rows: [ItemRow],
        emptyMessage: String,
        filter: ItemFilter,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping (ItemRow) -> Trailing
    ) -> some View {
        DetailSection(title: title, systemImage: systemImage, iconColor: iconColor) {
            if rows.isEmpty {
                PlaceholderText(emptyMessage)
            } else {
                let shown = Array(rows.prefix(Self.alertLimit))
                VStack(spacing: 0) {
                    ForEach(shown) { row in
                        Button {
                            router.show(.items)
                            router.open(.item(row.item.id))
                        } label: {
                            MiniRow(showsDivider: row.id != shown.last?.id) {
                                Text(row.item.name)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                trailing(row)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: 8) {
                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .buttonStyle(.themedSecondary)
                    }
                    if rows.count > shown.count {
                        Button("See All \(rows.count)") { router.show(.items, itemFilter: filter) }
                            .buttonStyle(.themedSecondary)
                    }
                }
            }
        }
    }
}
