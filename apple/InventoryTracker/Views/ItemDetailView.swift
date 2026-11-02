import SwiftData
import SwiftUI

private struct BatchRow: View {
    let batch: BatchBalance
    let item: Item
    let isEstimated: Bool

    private var productNumber: String {
        (item.purchases ?? []).first { $0.id == batch.id }?.productNumber ?? ""
    }

    private var daysUntilExpiration: Int? {
        batch.expirationDate.flatMap { Day.days(from: Day.today, to: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(batch.expirationDate.map { "Expires \(Format.longDate($0))" } ?? "No expiration date")
            Text(productNumber.isEmpty ? "Bought \(Format.longDate(batch.day))" : "Bought \(Format.longDate(batch.day)), \(productNumber)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        ExpirationBadge(days: daysUntilExpiration, isEstimated: isEstimated)
        Text("\(isEstimated ? "About " : "")\(batch.remaining) \(item.unitAbbreviation) left")
            .fontWeight(.medium)
    }
}

struct ItemDetailView: View {
    private static let recentLimit = 5

    @Query private var matches: [Item]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide

    init(itemID: String) {
        _matches = Query(filter: #Predicate<Item> { $0.id == itemID })
    }

    var body: some View {
        if let item = matches.first {
            detail(item, metrics: item.metrics())
        }
    }

    private func detail(_ item: Item, metrics: ItemMetrics) -> some View {
        DetailScreen(title: item.name) {
            if isWide {
                Button("Edit") { router.sheet = .item(item) }
                    .buttonStyle(.themedSecondary)
                Button("+ Purchase") { router.sheet = .purchase(nil, itemID: item.id) }
                    .buttonStyle(.themedPrimary)
                Button("+ Usage") { router.sheet = .usage(nil, itemID: item.id) }
                    .buttonStyle(.themedPrimary)
            } else {
                Menu {
                    Button("Add Purchase", systemImage: "cart.badge.plus") { router.sheet = .purchase(nil, itemID: item.id) }
                    Button("Record Usage", systemImage: "minus.circle") { router.sheet = .usage(nil, itemID: item.id) }
                    if item.isPerishable {
                        Button("Count Stock", systemImage: "number") { router.sheet = .count(item) }
                    }
                    Button("Edit", systemImage: "pencil") { router.sheet = .item(item) }
                } label: {
                    Label("Actions", systemImage: "plus")
                }
            }
        } content: {
            stats(item, metrics: metrics)
            if item.isPerishable {
                batchesSection(item, metrics: metrics)
                    .padding(.bottom, 16)
            }
            let recent = recentSections(item)
            if isWide {
                HStack(alignment: .top, spacing: 16) { recent }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
            } else {
                VStack(spacing: 16) { recent }
                    .padding(.bottom, 16)
            }
            details(item, metrics: metrics)
        }
    }

    private func stats(_ item: Item, metrics: ItemMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isWide ? 180 : 150), spacing: 16)], spacing: 16) {
            StatCard(
                label: "Current Stock",
                value: "\(metrics.currentInventory)",
                valueColor: metrics.needsReorder ? Theme.amber : Theme.green,
                subtitle: "\(item.unitAbbreviation) (reorder at \(item.reorderLevel))"
            )
            if let lowest = metrics.lowestPrice {
                StatCard(label: "Best Price", value: Format.currency(lowest), valueColor: Theme.green, subtitle: metrics.bestPriceVendor ?? " ")
            }
            if let average = metrics.averagePrice {
                StatCard(label: "Avg Price", value: Format.currency(average), valueColor: Theme.primary, subtitle: "per \(item.unitAbbreviation)")
            }
            if metrics.usageRatePerDay > 0 {
                StatCard(
                    label: "Usage Rate",
                    value: "\(metrics.usageRatePerDay.formatted(.number.precision(.fractionLength(0...2))))/day",
                    valueColor: Theme.purple,
                    subtitle: metrics.daysUntilReorder.map { "\($0) days to reorder" } ?? " "
                )
            }
        }
        .padding(.bottom, 24)
    }

    private func batchesSection(_ item: Item, metrics: ItemMetrics) -> some View {
        let onHand = metrics.batches.filter { $0.remaining > 0 }

        return DetailSection(title: "Batches") {
            if onHand.isEmpty {
                PlaceholderText("No stock on hand.")
            } else {
                VStack(spacing: 0) {
                    ForEach(onHand) { batch in
                        MiniRow(showsDivider: batch.id != onHand.last?.id) {
                            BatchRow(batch: batch, item: item, isEstimated: metrics.expirationIsEstimated)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                if metrics.expirationIsEstimated {
                    Text("Estimated from past usage. Count your shelf to confirm.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("Count Stock") { router.sheet = .count(item) }
                    .buttonStyle(.themedSecondary)
            }
        }
    }

    @ViewBuilder
    private func recentSections(_ item: Item) -> some View {
        let purchases = Array((item.purchases ?? []).sorted { $0.date > $1.date }.prefix(Self.recentLimit))
        let usage = Array((item.usageRecords ?? []).filter { !$0.isAdjustment }.sorted { $0.date > $1.date }.prefix(Self.recentLimit))

        DetailSection(title: "Recent Purchases") {
            if purchases.isEmpty {
                PlaceholderText("No purchases recorded yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(purchases) { purchase in
                        MiniRow(showsDivider: purchase.id != purchases.last?.id) {
                            Text(Format.shortDate(purchase.date)).frame(width: 56, alignment: .leading)
                            Text(purchase.vendor?.name ?? Format.missing)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(purchase.quantity) \(item.unitAbbreviation)")
                            Text(Format.currency(purchase.pricePerUnit))
                                .fontWeight(.medium)
                                .frame(width: 76, alignment: .trailing)
                        }
                    }
                }
            }
        }

        DetailSection(title: "Recent Usage") {
            if usage.isEmpty {
                PlaceholderText("No usage recorded yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(usage) { record in
                        MiniRow(showsDivider: record.id != usage.last?.id) {
                            Text(Format.shortDate(record.date))
                            Spacer(minLength: 0)
                            if record.isEstimate {
                                Text("Est.").foregroundStyle(Theme.textSecondary)
                            }
                            Text("-\(record.quantity) \(item.unitAbbreviation)")
                                .foregroundStyle(Theme.red)
                        }
                    }
                }
            }
        }
    }

    private func details(_ item: Item, metrics: ItemMetrics) -> some View {
        DetailSection(title: "Details") {
            VStack(spacing: 0) {
                InfoRow("Unit", value: item.unit.label)
                InfoRow("Perishable", value: item.isPerishable ? "Yes" : "No", showsDivider: !item.storageLocation.isEmpty || metrics.nextExpiration != nil)
                if !item.storageLocation.isEmpty {
                    InfoRow("Location", value: item.storageLocation, showsDivider: metrics.nextExpiration != nil)
                }
                if let next = metrics.nextExpiration {
                    InfoRow(label: "Next Expiration", showsDivider: false) {
                        HStack(spacing: 6) {
                            Text(Format.longDate(next))
                            ExpirationBadge(days: metrics.daysUntilExpiration, isEstimated: metrics.expirationIsEstimated)
                        }
                    }
                }
                if !item.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Text(item.notes)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                }
            }
        }
    }
}
