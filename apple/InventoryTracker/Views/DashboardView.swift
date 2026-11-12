import SwiftData
import SwiftUI

struct DashboardView: View {
    private static let rowLimit = 12
    private static let chartMonths = 12
    @Query private var items: [Item]
    @Query private var vendors: [Vendor]
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @Query(sort: \UsageRecord.date, order: .reverse) private var usage: [UsageRecord]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext
    @State private var model = DashboardModel(isEditing: DashboardView.startsInEditMode)

    private static var startsInEditMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["INVENTORY_DASHBOARD_EDIT"] != nil
        #else
        false
        #endif
    }

    var body: some View {
        Screen(title: "Dashboard") {
            if !items.isEmpty { DashboardEditActions(model: model) }
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
                if model.isEditing { editHint }
                DashboardBoard(model: model, contents: contents)
            }
        }
    }

    private var contents: [DashboardWidget: WidgetContent] {
        let rows = ItemRow.rows(for: items).sorted { orderedText($0.item.name, $1.item.name, ascending: true) }
        return Dictionary(uniqueKeysWithValues: DashboardWidget.allCases.map { ($0, content(for: $0, rows: rows)) })
    }

    private var editHint: some View {
        Label("Drag a widget to move it. Drag its bottom right corner to make it bigger or smaller.", systemImage: "hand.draw")
            .font(.system(size: 13))
            .foregroundStyle(Theme.primaryDarker)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.primaryBackground, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .padding(.bottom, 16)
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
        let attention = rows.filter(\.metrics.needsReorder)
            .sorted { ($0.metrics.currentInventory, $0.item.name) < ($1.metrics.currentInventory, $1.item.name) }
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
            stats: [
                WidgetStat(id: "in", label: "Well stocked", value: rows.count - out - low, tone: .green, action: show(.all)),
                WidgetStat(id: "low", label: "Running low", value: low, tone: .amber, action: show(.low)),
                WidgetStat(id: "out", label: "Out of stock", value: out, tone: .red, action: show(.out)),
                WidgetStat(id: "perishable", label: "Can expire", value: rows.filter(\.item.isPerishable).count, tone: .purple, isInBar: false, action: show(.perishable)),
            ],
            statsFootnote: { let added = rows.filter { $0.item.createdAt.hasPrefix(month) }.count; return added == 0 ? "" : "\(plural(added, "item")) added this month" }(),
            spotlightTitle: "Needs attention",
            spotlight: attention.map { row in
                WidgetRow(
                    id: row.id, label: row.item.name,
                    trailing: "\(row.metrics.currentInventory) \(row.item.unitAbbreviation)",
                    badge: row.metrics.currentInventory <= 0 ? Badge(text: "Out", tone: .red) : Badge(text: "Low", tone: .amber),
                    action: openItem(row.item.id)
                )
            },
            spotlightEmpty: "Everything is well stocked.",
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
