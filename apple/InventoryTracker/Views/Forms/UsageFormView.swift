import SwiftData
import SwiftUI

struct UsageFormView: View {
    private let record: UsageRecord?
    @Query private var items: [Item]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var itemID: String
    @State private var batchID: String
    @State private var date: String
    @State private var quantity: String
    @State private var isEstimate: Bool
    @State private var notes: String
    @State private var errorMessage: String?

    init(record: UsageRecord?, preselectedItemID: String?) {
        self.record = record
        _itemID = State(initialValue: record?.item?.id ?? preselectedItemID ?? "")
        _batchID = State(initialValue: record?.batch?.id ?? "")
        _date = State(initialValue: record?.date ?? Day.today)
        _quantity = State(initialValue: "\(record?.quantity ?? 1)")
        _isEstimate = State(initialValue: record?.isEstimate ?? false)
        _notes = State(initialValue: record?.notes ?? "")
    }

    private var sortedItems: [Item] {
        items.sorted { orderedText($0.name, $1.name, ascending: true) }
    }

    private var parsedQuantity: Int? {
        Int(quantity.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
    }

    private var selectedItem: Item? {
        items.first { $0.id == itemID }
    }

    private var batches: [BatchBalance] {
        guard let selectedItem, selectedItem.isPerishable else { return [] }
        return BatchOperations.balances(for: selectedItem, excluding: record).filter { $0.remaining > 0 || $0.id == batchID }
    }

    private var batchError: String? {
        guard let quantity = parsedQuantity, let batch = batches.first(where: { $0.id == batchID }), quantity > batch.remaining else {
            return nil
        }
        return "Only \(batch.remaining) left in this batch."
    }

    private func batchLabel(_ batch: BatchBalance) -> String {
        let expiration = batch.expirationDate.map { "Expires \(Format.longDate($0))" } ?? "Bought \(Format.longDate(batch.day))"
        return "\(expiration) (\(batch.remaining) left)"
    }

    private func suggestBatch() {
        batchID = BatchLedger.suggestedBatch(in: batches, today: Day.today)?.id ?? ""
    }

    var body: some View {
        FormSheet(
            title: record == nil ? "Record Usage" : "Edit Usage",
            canSave: !itemID.isEmpty && parsedQuantity != nil && batchError == nil,
            errorMessage: batchError ?? errorMessage,
            onSave: save
        ) {
            LabeledField(title: "Item", isRequired: true) {
                ItemSearchField(items: sortedItems, itemID: $itemID) { item in
                    "\(item.metrics().currentInventory) \(item.unitAbbreviation)"
                }
            }
            if !batches.isEmpty {
                LabeledField(title: "Batch") {
                    ThemedPicker(selection: $batchID) {
                        ForEach(batches) { Text(batchLabel($0)).tag($0.id) }
                        Text("Not sure").tag("")
                    }
                }
            }
            FieldRow {
                LabeledField(title: "Date") {
                    DayField(day: $date)
                }
                LabeledField(title: "Quantity", isRequired: true) {
                    ThemedTextField(text: $quantity, keyboard: .number)
                }
            }
            CheckboxField(title: "This is an estimate", isOn: $isEstimate)
            LabeledField(title: "Notes") {
                ThemedTextArea(placeholder: "Optional notes", text: $notes)
            }
        }
        .onAppear {
            if record == nil { suggestBatch() }
        }
        .onChange(of: itemID) { suggestBatch() }
    }

    private func save() {
        guard let quantity = parsedQuantity, let item = items.first(where: { $0.id == itemID }) else { return }
        let target = record ?? UsageRecord(date: date, item: nil, quantity: quantity)
        if record == nil { modelContext.insert(target) }
        target.date = date
        target.item = item
        target.batch = (item.purchases ?? []).first { $0.id == batchID }
        target.quantity = quantity
        target.isEstimate = isEstimate
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
