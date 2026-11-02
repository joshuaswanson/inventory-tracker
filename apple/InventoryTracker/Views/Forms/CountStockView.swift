import SwiftData
import SwiftUI

struct CountStockView: View {
    private let item: Item
    private let batches: [BatchBalance]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var counts: [String: String]
    @State private var errorMessage: String?

    init(item: Item) {
        self.item = item
        batches = BatchOperations.balances(for: item)
        _counts = State(initialValue: Dictionary(uniqueKeysWithValues: batches.map { ($0.id, "\($0.remaining)") }))
    }

    private var parsedCounts: [String: Int]? {
        var parsed: [String: Int] = [:]
        for batch in batches {
            guard let value = Int((counts[batch.id] ?? "").trimmingCharacters(in: .whitespaces)), value >= 0 else { return nil }
            parsed[batch.id] = value
        }
        return parsed
    }

    private func title(for batch: BatchBalance) -> String {
        batch.expirationDate.map { "Expires \(Format.longDate($0))" } ?? "No expiration date"
    }

    var body: some View {
        FormSheet(
            title: "Count Stock",
            canSave: parsedCounts != nil && !batches.isEmpty,
            errorMessage: errorMessage,
            onSave: save
        ) {
            Text("Enter what is on the shelf for each batch of \(item.name). Enter 0 for a batch that is gone or thrown away.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(batches.enumerated()), id: \.element.id) { index, batch in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: batch))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Text("Bought \(Format.longDate(batch.day)), \(batch.quantity) \(item.unitAbbreviation)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ThemedTextField(
                        text: Binding(get: { counts[batch.id] ?? "" }, set: { counts[batch.id] = $0 }),
                        keyboard: .number
                    )
                    .frame(width: 88)
                    .accessibilityIdentifier("Batch \(index + 1)")
                }
            }
        }
    }

    private func save() {
        guard let parsedCounts else { return }
        do {
            try BatchOperations.applyCount(parsedCounts, to: item, in: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
