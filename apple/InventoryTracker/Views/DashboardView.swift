import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query private var items: [Item]
    @Query private var vendors: [Vendor]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide

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
                    Label("Data", systemImage: "externaldrive")
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
        VStack(spacing: 0) {
            EmptyState(
                systemImage: "archivebox",
                title: "Welcome to Inventory Tracker",
                message: "Import a backup, or add your first supply item."
            )
            .padding(.bottom, -40)
            HStack(spacing: 8) {
                Button("Import Data") { router.sheet = .data }
                    .buttonStyle(.themedPrimary)
                Button("Add Item") { router.sheet = .item(nil) }
                    .buttonStyle(.themedSecondary)
            }
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .card()
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
            emptyMessage: "All items are well-stocked."
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
            }
        }
    }
}
