import SwiftData
import SwiftUI

private struct StockCountRow: Identifiable {
    let id: String
    let item: Item
    let batchID: String?
    let title: String
    let subtitle: String
    let current: Int
}

struct StockCountView: View {
    @Query private var items: [Item]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [StockCountRow] = []
    @State private var counts: [String: String] = [:]
    @State private var errorMessage: String?

    private var canSave: Bool {
        !rows.isEmpty && rows.allSatisfy { parsedCount(counts[$0.id]) != nil }
    }

    var body: some View {
        FormSheet(title: "Count Stock", canSave: canSave, errorMessage: errorMessage, onSave: save) {
            Text("Walk the shelves and correct any number that is off. Leave the rest as they are.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if rows.isEmpty {
                PlaceholderText("Add items first, then count them here.")
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                CountField(
                    title: row.title,
                    subtitle: row.subtitle,
                    text: Binding(get: { counts[row.id] ?? "" }, set: { counts[row.id] = $0 }),
                    identifier: "Count \(index + 1)"
                )
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard rows.isEmpty else { return }
        let sorted = items.sorted { orderedText($0.name, $1.name, ascending: true) }
        rows = sorted.flatMap { item -> [StockCountRow] in
            let batches = item.isPerishable ? BatchOperations.balances(for: item).filter { $0.remaining > 0 } : []
            if batches.isEmpty {
                let stock = max(0, item.metrics().currentInventory)
                return [StockCountRow(id: item.id, item: item, batchID: nil, title: item.name, subtitle: "Counted in \(item.unitAbbreviation)", current: stock)]
            }
            return batches.map { batch in
                let expiration = batch.expirationDate.map { "Expires \(Format.longDate($0))" } ?? "No expiration date"
                return StockCountRow(id: batch.id, item: item, batchID: batch.id, title: item.name, subtitle: "\(expiration), in \(item.unitAbbreviation)", current: batch.remaining)
            }
        }
        counts = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, "\($0.current)") })
    }

    private func save() {
        do {
            var batchCounts: [String: (item: Item, counts: [String: Int])] = [:]
            for row in rows {
                guard let counted = parsedCount(counts[row.id]), counted != row.current else { continue }
                if let batchID = row.batchID {
                    batchCounts[row.item.id, default: (row.item, [:])].counts[batchID] = counted
                } else {
                    try BatchOperations.applyShelfCount(counted, to: row.item, in: modelContext)
                }
            }
            for entry in batchCounts.values {
                try BatchOperations.applyCount(entry.counts, to: entry.item, in: modelContext)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
