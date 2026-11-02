import SwiftData
import SwiftUI

private enum UsageSortKey {
    case date, item, quantity, notes
}

struct UsageView: View {
    @Query private var records: [UsageRecord]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext
    @State private var search = ""
    @State private var sort = SortState(key: UsageSortKey.date, ascending: false)

    var body: some View {
        let visible = visibleRecords

        Screen(title: "Usage", searchPrompt: "Search by item...", search: $search) {
            HeaderButton(title: "+ Record Usage", compactImage: "plus") { router.sheet = .usage(nil, itemID: nil) }
        } content: {
            if records.isEmpty {
                EmptyState(
                    systemImage: "chart.bar.doc.horizontal.fill",
                    title: "No usage recorded",
                    message: "Track consumption to see usage rates and predict reorder dates."
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

    private var visibleRecords: [UsageRecord] {
        let query = search.lowercased()
        return records
            .filter { query.isEmpty || ($0.item?.name.lowercased().contains(query) ?? false) }
            .sorted(by: isOrdered)
    }

    private func isOrdered(_ first: UsageRecord, _ second: UsageRecord) -> Bool {
        let ascending = sort.ascending
        switch sort.key {
        case .date: return ordered(first.date, second.date, ascending: ascending)
        case .item: return orderedText(first.item?.name ?? "", second.item?.name ?? "", ascending: ascending)
        case .quantity: return ordered(first.quantity, second.quantity, ascending: ascending)
        case .notes: return orderedText(first.notes, second.notes, ascending: ascending)
        }
    }

    private var columns: [DataColumn<UsageRecord, UsageSortKey>] {
        [
            DataColumn("Date", sortKey: .date, weight: 1, isNumeric: true) { record in
                Text(Format.longDate(record.date))
            },
            DataColumn("Item", sortKey: .item, weight: 3) { record in
                if let item = record.item {
                    Button {
                        router.open(.item(item.id))
                    } label: {
                        Text(item.name).fontWeight(.medium).lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Unknown")
                }
            },
            DataColumn("Quantity", sortKey: .quantity, weight: 0.8) { record in
                Text(record.quantityText)
                    .foregroundStyle(record.quantity < 0 ? Theme.green : Theme.red)
            },
            DataColumn("Est.", weight: 0.5) { record in
                if record.isAdjustment {
                    Badge(text: "Count", tone: .gray)
                } else if record.isEstimate {
                    Badge(text: "Est", tone: .blue)
                }
            },
            DataColumn("Notes", sortKey: .notes, weight: 2) { record in
                Text(record.notes.isEmpty ? Format.missing : record.notes)
                    .foregroundStyle(Theme.textSecondary)
            },
            DataColumn("", weight: 0.6) { record in
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    if !record.isAdjustment {
                        RowIconButton(systemImage: "pencil", label: "Edit") { router.sheet = .usage(record, itemID: nil) }
                    }
                    RowIconButton(systemImage: "trash.fill", isDestructive: true, label: "Delete") { confirmDelete(record) }
                }
            },
        ]
    }

    private func compactRow(_ record: UsageRecord) -> some View {
        CompactRowCard {
            if !record.isAdjustment {
                router.sheet = .usage(record, itemID: nil)
            }
        } content: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.item?.name ?? "Unknown")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                    Text(record.notes.isEmpty ? Format.longDate(record.date) : "\(Format.longDate(record.date)), \(record.notes)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if record.isAdjustment {
                    Badge(text: "Count", tone: .gray)
                } else if record.isEstimate {
                    Badge(text: "Est", tone: .blue)
                }
                Text(record.quantityText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(record.quantity < 0 ? Theme.green : Theme.red)
            }
        }
        .contextMenu {
            if !record.isAdjustment {
                Button("Edit", systemImage: "pencil") { router.sheet = .usage(record, itemID: nil) }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete(record) }
        }
    }

    private func confirmDelete(_ record: UsageRecord) {
        router.pendingDelete = PendingDelete(message: "Delete this usage record?") {
            modelContext.delete(record)
            try? modelContext.save()
        }
    }
}
