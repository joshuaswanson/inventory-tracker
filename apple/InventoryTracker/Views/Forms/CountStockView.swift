import SwiftData
import SwiftUI

struct CountField: View {
    let title: String
    let subtitle: String
    @Binding var text: String
    let identifier: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ThemedTextField(text: $text, keyboard: .number)
                .frame(width: 88)
                .accessibilityIdentifier(identifier)
        }
    }
}

nonisolated func parsedCount(_ text: String?) -> Int? {
    Int((text ?? "").trimmingCharacters(in: .whitespaces)).flatMap { $0 >= 0 ? $0 : nil }
}

struct CountStockView: View {
    private static let shelfKey = "shelf"

    private let item: Item
    private let batches: [BatchBalance]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var counts: [String: String]
    @State private var errorMessage: String?

    init(item: Item) {
        self.item = item
        batches = item.isPerishable ? BatchOperations.balances(for: item) : []
        var initial = Dictionary(uniqueKeysWithValues: batches.map { ($0.id, "\($0.remaining)") })
        initial[Self.shelfKey] = "\(max(0, item.metrics().currentInventory))"
        _counts = State(initialValue: initial)
    }

    private var keys: [String] { batches.isEmpty ? [Self.shelfKey] : batches.map(\.id) }

    private var canSave: Bool { keys.allSatisfy { parsedCount(counts[$0]) != nil } }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { counts[key] ?? "" }, set: { counts[key] = $0 })
    }

    var body: some View {
        FormSheet(title: "Count Stock", canSave: canSave, errorMessage: errorMessage, onSave: save) {
            if batches.isEmpty {
                Text("Enter how many of \(item.name) are on the shelf right now.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CountField(title: "On the shelf", subtitle: "Counted in \(item.unitAbbreviation)", text: binding(Self.shelfKey), identifier: "Shelf Count")
            } else {
                Text("Enter what is on the shelf for each batch of \(item.name). Enter 0 for a batch that is gone or thrown away.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(batches.enumerated()), id: \.element.id) { index, batch in
                    CountField(
                        title: batch.expirationDate.map { "Expires \(Format.longDate($0))" } ?? "No expiration date",
                        subtitle: "Bought \(Format.longDate(batch.day)), \(batch.quantity) \(item.unitAbbreviation)",
                        text: binding(batch.id),
                        identifier: "Batch \(index + 1)"
                    )
                }
            }
        }
    }

    private func save() {
        do {
            if batches.isEmpty {
                guard let counted = parsedCount(counts[Self.shelfKey]) else { return }
                try BatchOperations.applyShelfCount(counted, to: item, in: modelContext)
            } else {
                var parsed: [String: Int] = [:]
                for batch in batches {
                    guard let counted = parsedCount(counts[batch.id]) else { return }
                    parsed[batch.id] = counted
                }
                try BatchOperations.applyCount(parsed, to: item, in: modelContext)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
