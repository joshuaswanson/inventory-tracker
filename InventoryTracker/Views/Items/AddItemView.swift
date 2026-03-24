import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedUnit: UnitOfMeasure = .each
    @State private var reorderLevel = 10
    @State private var isPerishable = false
    @State private var storageLocation = ""
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

                Section("Storage Location") {
                    TextField("e.g., Supply Room A, Cabinet 3", text: $storageLocation)
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                    .disabled(name.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 350)
        #endif
    }

    private func addItem() {
        let item = Item(
            name: name,
            unitOfMeasure: selectedUnit,
            reorderLevel: reorderLevel,
            isPerishable: isPerishable,
            notes: notes,
            storageLocation: storageLocation
        )
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: Item.self, inMemory: true)
}
