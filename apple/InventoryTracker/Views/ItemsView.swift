import SwiftData
import SwiftUI

enum ItemFilter: String, CaseIterable, Hashable {
    case all, low, out, expiring, perishable

    var label: String {
        switch self {
        case .all: "All"
        case .low: "Low Stock"
        case .out: "Out of Stock"
        case .expiring: "Expiring Soon"
        case .perishable: "Perishable"
        }
    }

    func includes(_ row: ItemRow) -> Bool {
        switch self {
        case .all: true
        case .low: row.metrics.needsReorder
        case .out: row.metrics.currentInventory <= 0
        case .expiring: row.metrics.isExpiringSoon
        case .perishable: row.item.isPerishable
        }
    }
}

struct ItemRow: Identifiable {
    let item: Item
    let metrics: ItemMetrics

    var id: String { item.id }

    static func rows(for items: [Item]) -> [ItemRow] {
        let today = Day.today
        return items.map { ItemRow(item: $0, metrics: $0.metrics(today: today)) }
    }

    static func totalValue(_ rows: [ItemRow]) -> Double {
        roundedToCents(rows.reduce(0) { total, row in
            guard let price = row.metrics.averagePrice, row.metrics.currentInventory > 0 else { return total }
            return total + price * Double(row.metrics.currentInventory)
        })
    }
}

private enum ItemSortKey {
    case name, stock, reorder, status, location, price
}

struct ItemsView: View {
    @Query private var items: [Item]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide
    @State private var search = ""
    @State private var sort = SortState(key: ItemSortKey.name)

    var body: some View {
        @Bindable var router = router
        let all = ItemRow.rows(for: items)
        let visible = visibleRows(from: all)

        Screen(title: "Items", searchPrompt: "Search items...", search: $search) {
            HeaderButton(title: "+ Add Item", compactImage: "plus") { router.sheet = .item(nil) }
        } content: {
            FilterChips(
                options: ItemFilter.allCases.map { filter in
                    FilterOption(value: filter, label: filter.label, count: all.filter(filter.includes).count)
                },
                selection: $router.itemFilter
            )
            if visible.isEmpty {
                let isFiltered = router.itemFilter != .all || !search.isEmpty
                EmptyState(
                    title: isFiltered ? "No matching items" : "No items yet",
                    message: isFiltered ? "Try adjusting your filters or search." : "Add your first dental supply item to get started."
                )
            } else if isWide {
                DataTable(rows: visible, columns: columns, sort: $sort) { row in
                    router.open(.item(row.item.id))
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visible) { compactRow($0) }
                }
            }
        }
    }

    private func visibleRows(from all: [ItemRow]) -> [ItemRow] {
        let query = search.lowercased()
        return all
            .filter { row in
                query.isEmpty
                    || row.item.name.lowercased().contains(query)
                    || row.item.storageLocation.lowercased().contains(query)
            }
            .filter(router.itemFilter.includes)
            .sorted(by: isOrdered)
    }

    private func isOrdered(_ first: ItemRow, _ second: ItemRow) -> Bool {
        let ascending = sort.ascending
        switch sort.key {
        case .name:
            return orderedText(first.item.name, second.item.name, ascending: ascending)
        case .stock:
            return ordered(first.metrics.currentInventory, second.metrics.currentInventory, ascending: ascending)
        case .reorder:
            return ordered(first.item.reorderLevel, second.item.reorderLevel, ascending: ascending)
        case .status:
            return ordered(first.metrics.needsReorder ? 0 : 1, second.metrics.needsReorder ? 0 : 1, ascending: ascending)
        case .location:
            return orderedText(first.item.storageLocation, second.item.storageLocation, ascending: ascending)
        case .price:
            return ordered(first.metrics.averagePrice ?? 0, second.metrics.averagePrice ?? 0, ascending: ascending)
        }
    }

    private var columns: [DataColumn<ItemRow, ItemSortKey>] {
        [
            DataColumn("Name", sortKey: .name, weight: 3.4) { row in
                Text(row.item.name).fontWeight(.medium)
            },
            DataColumn("Stock", sortKey: .stock, weight: 1.5) { row in
                StockBar(
                    stock: row.metrics.currentInventory,
                    reorderLevel: row.item.reorderLevel,
                    needsReorder: row.metrics.needsReorder,
                    unit: row.item.unitAbbreviation
                )
            },
            DataColumn("Reorder At", sortKey: .reorder, weight: 0.9) { row in
                Text("\(row.item.reorderLevel) \(row.item.unitAbbreviation)")
                    .foregroundStyle(Theme.textSecondary)
            },
            DataColumn("Status", sortKey: .status, weight: 1.7) { row in
                HStack(spacing: 4) {
                    StockBadge(metrics: row.metrics)
                    ExpirationBadge(days: row.item.isPerishable ? row.metrics.daysUntilExpiration : nil, isEstimated: row.metrics.expirationIsEstimated)
                }
            },
            DataColumn("Location", sortKey: .location, weight: 1) { row in
                Text(row.item.storageLocation.isEmpty ? Format.missing : row.item.storageLocation)
                    .foregroundStyle(Theme.textSecondary)
            },
            DataColumn("Avg Price", sortKey: .price, weight: 0.9, isNumeric: true) { row in
                Text(Format.currency(row.metrics.averagePrice))
            },
            DataColumn("", weight: 0.8) { row in
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    RowIconButton(systemImage: "pencil", label: "Edit") { router.sheet = .item(row.item) }
                    RowIconButton(systemImage: "trash.fill", isDestructive: true, label: "Delete") { confirmDelete(row.item) }
                }
            },
        ]
    }

    private func compactRow(_ row: ItemRow) -> some View {
        CompactRowCard {
            router.open(.item(row.item.id))
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text(row.item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                StockBar(
                    stock: row.metrics.currentInventory,
                    reorderLevel: row.item.reorderLevel,
                    needsReorder: row.metrics.needsReorder,
                    unit: row.item.unitAbbreviation
                )
                HStack(spacing: 4) {
                    StockBadge(metrics: row.metrics)
                    ExpirationBadge(days: row.item.isPerishable ? row.metrics.daysUntilExpiration : nil, isEstimated: row.metrics.expirationIsEstimated)
                    Spacer(minLength: 0)
                    Text(Format.currency(row.metrics.averagePrice))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { router.sheet = .item(row.item) }
            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete(row.item) }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func confirmDelete(_ item: Item) {
        router.pendingDelete = PendingDelete(
            message: "Delete \"\(item.name)\"? This will also remove its purchases and usage records."
        ) {
            modelContext.delete(item)
            try? modelContext.save()
        }
    }
}
