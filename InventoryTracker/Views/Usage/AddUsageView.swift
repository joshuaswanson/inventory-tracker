import SwiftUI
import SwiftData

struct AddUsageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Item.name) private var items: [Item]

    var preselectedItem: Item?

    @State private var selectedItem: Item?
    @State private var usageDate = Date()
    @State private var quantity = 1
    @State private var isEstimate = true
    @State private var notes = ""

    var isFormValid: Bool {
        selectedItem != nil && quantity > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    if items.isEmpty {
                        Text("No items available. Add an item first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Item", selection: $selectedItem) {
                            Text("Select an item").tag(nil as Item?)
                            ForEach(items) { item in
                                Text(item.name).tag(item as Item?)
                            }
                        }
                    }
                }

                Section("Usage Details") {
                    DatePicker("Date", selection: $usageDate, displayedComponents: .date)

                    Stepper("Quantity Used: \(quantity)", value: $quantity, in: 1...10000)

                    Toggle("This is an estimate", isOn: $isEstimate)
                }

                Section {
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text("Since usage can be hard to track precisely, estimates are fine. The app uses this data to calculate usage rates over time.")
                }

                if let item = selectedItem {
                    Section("Item Info") {
                        LabeledContent("Current Inventory", value: "\(item.currentInventory) \(item.unit.abbreviation)")
                        LabeledContent("Reorder Level", value: "\(item.reorderLevel) \(item.unit.abbreviation)")

                        if item.usageRatePerDay > 0 {
                            LabeledContent("Average Daily Usage") {
                                Text(String(format: "%.1f %@/day", item.usageRatePerDay, item.unit.abbreviation))
                            }
                        }

                        if let daysLeft = item.estimatedDaysUntilReorder, daysLeft > 0 {
                            LabeledContent("Days Until Reorder") {
                                Text("\(daysLeft) days")
                                    .foregroundStyle(daysLeft <= 7 ? .orange : .primary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Record Usage")
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
                    Button("Save") {
                        addUsage()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                if let preselected = preselectedItem {
                    selectedItem = preselected
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 450)
        .padding()
        #endif
    }

    private func addUsage() {
        guard let item = selectedItem else { return }

        let usage = Usage(
            item: item,
            date: usageDate,
            quantity: quantity,
            notes: notes,
            isEstimate: isEstimate
        )

        modelContext.insert(usage)
        dismiss()
    }
}

#Preview {
    AddUsageView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
