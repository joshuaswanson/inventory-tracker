import SwiftData
import SwiftUI

private enum PurchaseSortKey {
    case date, item, vendor, quantity, price, total, productNumber, expiration
}

private struct PurchaseExpiration: View {
    let expirationDate: String?

    var body: some View {
        if let expirationDate, let days = Day.days(from: Day.today, to: expirationDate) {
            switch days {
            case ..<0: Badge(text: "Expired", tone: .red)
            case 0...7: Badge(text: "\(days)d", tone: .red)
            case 8...30: Badge(text: "\(days)d", tone: .amber)
            default: Text(Format.shortDate(expirationDate)).foregroundStyle(Theme.textSecondary)
            }
        } else {
            Text(Format.missing)
        }
    }
}

private struct TextLinkButton: View {
    let title: String
    var color: Color = Theme.text
    var weight: Font.Weight = .regular
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(weight)
                .foregroundStyle(isHovering ? Theme.primary : color)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct PurchasesView: View {
    @Query private var purchases: [Purchase]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext
    @State private var search = ""
    @State private var sort = SortState(key: PurchaseSortKey.date, ascending: false)

    var body: some View {
        let visible = visiblePurchases

        Screen(title: "Purchases", searchPrompt: "Search by item or vendor...", search: $search) {
            if isWide {
                Button("Spending") { router.sheet = .spending }
                    .buttonStyle(.themedSecondary)
                Button("Import Orders") { router.sheet = .importOrders }
                    .buttonStyle(.themedSecondary)
            } else {
                Button {
                    router.sheet = .spending
                } label: {
                    Label("Spending", systemImage: "chart.pie")
                }
                Button {
                    router.sheet = .importOrders
                } label: {
                    Label("Import Orders", systemImage: "square.and.arrow.down")
                }
            }
            HeaderButton(title: "+ Add Purchase", compactImage: "plus") { router.sheet = .purchase(nil, itemID: nil) }
        } content: {
            if purchases.isEmpty {
                EmptyState(
                    systemImage: "cart.fill",
                    title: "No purchases recorded",
                    message: "Record your first supply order to start tracking costs."
                )
            } else if isWide {
                DataTable(rows: visible, columns: columns, sort: $sort)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visible) { compactRow($0) }
                }
            }
        }
    }

    private var visiblePurchases: [Purchase] {
        let query = search.lowercased()
        return purchases
            .filter { purchase in
                query.isEmpty
                    || (purchase.item?.name.lowercased().contains(query) ?? false)
                    || (purchase.vendor?.name.lowercased().contains(query) ?? false)
            }
            .sorted(by: isOrdered)
    }

    private func isOrdered(_ first: Purchase, _ second: Purchase) -> Bool {
        let ascending = sort.ascending
        switch sort.key {
        case .date: return ordered(first.date, second.date, ascending: ascending)
        case .item: return orderedText(first.item?.name ?? "", second.item?.name ?? "", ascending: ascending)
        case .vendor: return orderedText(first.vendor?.name ?? "", second.vendor?.name ?? "", ascending: ascending)
        case .quantity: return ordered(first.quantity, second.quantity, ascending: ascending)
        case .price: return ordered(first.pricePerUnit, second.pricePerUnit, ascending: ascending)
        case .total: return ordered(first.totalCost, second.totalCost, ascending: ascending)
        case .productNumber: return orderedText(first.productNumber, second.productNumber, ascending: ascending)
        case .expiration: return ordered(first.expirationDate ?? "", second.expirationDate ?? "", ascending: ascending)
        }
    }

    private var columns: [DataColumn<Purchase, PurchaseSortKey>] {
        [
            DataColumn("Date", sortKey: .date, weight: 1.15, isNumeric: true) { purchase in
                Text(Format.longDate(purchase.date))
            },
            DataColumn("Item", sortKey: .item, weight: 2.8) { purchase in
                if let item = purchase.item {
                    TextLinkButton(title: item.name, weight: .medium) { router.open(.item(item.id)) }
                } else {
                    Text("Unknown")
                }
            },
            DataColumn("Vendor", sortKey: .vendor, weight: 1.4) { purchase in
                if let vendor = purchase.vendor {
                    TextLinkButton(title: vendor.name, color: Theme.textSecondary) { router.open(.vendor(vendor.id)) }
                } else {
                    Text(Format.missing).foregroundStyle(Theme.textSecondary)
                }
            },
            DataColumn("Qty", sortKey: .quantity, weight: 0.6, isNumeric: true) { purchase in
                Text("\(purchase.quantity) \(purchase.item?.unitAbbreviation ?? UnitOfMeasure.each.abbreviation)")
            },
            DataColumn("Price/Unit", sortKey: .price, weight: 0.95, isNumeric: true) { purchase in
                Text(Format.currency(purchase.pricePerUnit))
            },
            DataColumn("Total", sortKey: .total, weight: 0.8, isNumeric: true) { purchase in
                Text(Format.currency(purchase.totalCost)).fontWeight(.medium)
            },
            DataColumn("Product #", sortKey: .productNumber, weight: 1) { purchase in
                Text(purchase.productNumber.isEmpty ? Format.missing : purchase.productNumber)
                    .foregroundStyle(Theme.textSecondary)
            },
            DataColumn("Expires", sortKey: .expiration, weight: 0.7) { purchase in
                PurchaseExpiration(expirationDate: purchase.expirationDate)
            },
            DataColumn("", weight: 0.75) { purchase in
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    RowIconButton(systemImage: "pencil", label: "Edit") { router.sheet = .purchase(purchase, itemID: nil) }
                    RowIconButton(systemImage: "trash.fill", isDestructive: true, label: "Delete") { confirmDelete(purchase) }
                }
            },
        ]
    }

    private func compactRow(_ purchase: Purchase) -> some View {
        CompactRowCard {
            router.sheet = .purchase(purchase, itemID: nil)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text(purchase.item?.name ?? "Unknown")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                Text([Format.longDate(purchase.date), purchase.vendor?.name].compactMap { $0 }.joined(separator: ", "))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                HStack {
                    Text("\(purchase.quantity) \(purchase.item?.unitAbbreviation ?? UnitOfMeasure.each.abbreviation) at \(Format.currency(purchase.pricePerUnit))")
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                    Text(Format.currency(purchase.totalCost))
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                }
                .font(.system(size: 13))
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { router.sheet = .purchase(purchase, itemID: nil) }
            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete(purchase) }
        }
    }

    private func confirmDelete(_ purchase: Purchase) {
        router.pendingDelete = PendingDelete(message: "Delete this purchase record?") {
            BatchOperations.delete(purchase, in: modelContext)
            try? modelContext.save()
        }
    }
}
