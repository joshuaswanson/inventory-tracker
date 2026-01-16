import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedUnit: UnitOfMeasure = .each
    @State private var reorderLevel = 10
    @State private var isPerishable = false
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $name)

                    Picker("Unit of Measure", selection: $selectedUnit) {
                        ForEach(UnitOfMeasure.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }

                    Stepper("Reorder Level: \(reorderLevel)", value: $reorderLevel, in: 0...1000)

                    Toggle("Perishable Item", isOn: $isPerishable)
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addItem() {
        let item = Item(
            name: name,
            unitOfMeasure: selectedUnit,
            reorderLevel: reorderLevel,
            isPerishable: isPerishable,
            notes: notes
        )
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: Item.self, inMemory: true)
}
