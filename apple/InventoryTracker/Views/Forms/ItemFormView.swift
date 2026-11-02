import SwiftData
import SwiftUI

struct ItemFormView: View {
    private let item: Item?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var unit: UnitOfMeasure
    @State private var reorderLevel: String
    @State private var isPerishable: Bool
    @State private var storageLocation: String
    @State private var notes: String
    @State private var errorMessage: String?

    init(item: Item?) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _unit = State(initialValue: item?.unit ?? .each)
        _reorderLevel = State(initialValue: "\(item?.reorderLevel ?? 10)")
        _isPerishable = State(initialValue: item?.isPerishable ?? false)
        _storageLocation = State(initialValue: item?.storageLocation ?? "")
        _notes = State(initialValue: item?.notes ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        FormSheet(
            title: item == nil ? "New Item" : "Edit Item",
            canSave: !trimmedName.isEmpty,
            errorMessage: errorMessage,
            onSave: save
        ) {
            LabeledField(title: "Name", isRequired: true) {
                ThemedTextField("e.g. Composite Resin", text: $name)
            }
            FieldRow {
                LabeledField(title: "Unit of Measure") {
                    ThemedPicker(selection: $unit) {
                        ForEach(UnitOfMeasure.allCases) { Text($0.label).tag($0) }
                    }
                }
                LabeledField(title: "Reorder Level") {
                    ThemedTextField(text: $reorderLevel, keyboard: .number)
                }
            }
            CheckboxField(title: "Perishable item", isOn: $isPerishable)
            LabeledField(title: "Storage Location") {
                ThemedTextField("e.g. Cabinet A, Shelf 3", text: $storageLocation)
            }
            LabeledField(title: "Notes") {
                ThemedTextArea(placeholder: "Optional notes", text: $notes)
            }
        }
    }

    private func save() {
        let target = item ?? Item(name: trimmedName)
        target.name = trimmedName
        target.unit = unit
        target.reorderLevel = Int(reorderLevel.trimmingCharacters(in: .whitespaces)) ?? 0
        target.isPerishable = isPerishable
        target.storageLocation = storageLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if item == nil { modelContext.insert(target) }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
