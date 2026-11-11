import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query private var items: [Item]
    @Query private var vendors: [Vendor]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext

    private var rows: [ItemRow] {
        ItemRow.rows(for: items).sorted { orderedText($0.item.name, $1.item.name, ascending: true) }
    }

    var body: some View {
        let rows = rows
        let lowStock = rows.filter(\.metrics.needsReorder)
        let expiring = rows.filter(\.metrics.isExpiringSoon)
            .sorted { ($0.metrics.daysUntilExpiration ?? 0) < ($1.metrics.daysUntilExpiration ?? 0) }

        Screen(title: "Dashboard") {
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
                stats(rows: rows, lowStock: lowStock.count, expiring: expiring.count)
                alerts(lowStock: lowStock, expiring: expiring)
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

    private func stats(rows: [ItemRow], lowStock: Int, expiring: Int) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isWide ? 180 : 150), spacing: 16)], spacing: 16) {
            StatCard(systemImage: "archivebox.fill", tone: .blue, label: "Total Items", value: "\(rows.count)") {
                router.show(.items)
            }
            StatCard(
                systemImage: "exclamationmark.triangle.fill",
                tone: .amber,
                label: "Low Stock",
                value: "\(lowStock)",
                valueColor: lowStock > 0 ? Theme.amber : Theme.text
            ) {
                router.show(.items, itemFilter: .low)
            }
            StatCard(
                systemImage: "clock.fill",
                tone: .red,
                label: "Expiring Soon",
                value: "\(expiring)",
                valueColor: expiring > 0 ? Theme.red : Theme.text
            ) {
                router.show(.items, itemFilter: .expiring)
            }
            StatCard(systemImage: "building.2.fill", tone: .purple, label: "Vendors", value: "\(vendors.count)") {
                router.show(.vendors)
            }
            StatCard(
                systemImage: "dollarsign.circle.fill",
                tone: .green,
                label: "Inventory Value",
                value: Format.currency(ItemRow.totalValue(rows)),
                valueColor: Theme.green
            )
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func alerts(lowStock: [ItemRow], expiring: [ItemRow]) -> some View {
        let lowStockSection = alertSection(
            title: "Low Stock Alerts",
            systemImage: "exclamationmark.triangle.fill",
            iconColor: Theme.amber,
            rows: lowStock,
            emptyMessage: "All items are well-stocked.",
            actionTitle: "Reorder List",
            action: { router.sheet = .reorder }
        ) { row in
            Text("\(row.metrics.currentInventory) / \(row.item.reorderLevel) \(row.item.unitAbbreviation)")
                .foregroundStyle(Theme.textSecondary)
            StockBadge(metrics: row.metrics)
        }
        let expiringSection = alertSection(
            title: "Expiring Soon",
            systemImage: "clock.fill",
            iconColor: Theme.red,
            rows: expiring,
            emptyMessage: "Nothing expiring in the next 30 days."
        ) { row in
            Text(Format.shortDate(row.metrics.nextExpiration))
                .foregroundStyle(Theme.textSecondary)
            ExpirationBadge(days: row.metrics.daysUntilExpiration, isEstimated: row.metrics.expirationIsEstimated)
        }

        if isWide {
            HStack(alignment: .top, spacing: 16) {
                lowStockSection
                expiringSection
            }
        } else {
            VStack(spacing: 16) {
                lowStockSection
                expiringSection
            }
        }
    }

    private func alertSection<Trailing: View>(
        title: String,
        systemImage: String,
        iconColor: Color,
        rows: [ItemRow],
        emptyMessage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping (ItemRow) -> Trailing
    ) -> some View {
        DetailSection(title: title, systemImage: systemImage, iconColor: iconColor) {
            if rows.isEmpty {
                PlaceholderText(emptyMessage)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Button {
                            router.show(.items)
                            router.open(.item(row.item.id))
                        } label: {
                            MiniRow(showsDivider: row.id != rows.last?.id) {
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
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.themedSecondary)
                }
            }
        }
    }
}
