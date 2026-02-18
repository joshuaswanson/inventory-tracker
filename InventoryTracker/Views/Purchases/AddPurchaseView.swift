import SwiftUI
import SwiftData

struct AddPurchaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Item.name) private var items: [Item]
    @Query(sort: \Vendor.name) private var vendors: [Vendor]

    var preselectedItem: Item?

    @State private var selectedItem: Item?
    @State private var selectedVendor: Vendor?
    @State private var purchaseDate = Date()
    @State private var quantity = 1
    @State private var pricePerUnit = ""
    @State private var lotNumber = ""
    @State private var hasExpiration = false
    @State private var expirationDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var showValidationErrors = false

    var isFormValid: Bool {
        selectedItem != nil && !pricePerUnit.isEmpty && Double(pricePerUnit) != nil && quantity > 0
    }

    var isItemMissing: Bool {
        showValidationErrors && selectedItem == nil
    }

    var isPriceMissing: Bool {
        showValidationErrors && (pricePerUnit.isEmpty || Double(pricePerUnit) == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                        .pickerStyle(.menu)

                        if isItemMissing {
                            Text("Please select an item")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    HStack {
                        Text("Item")
                        Text("*")
                            .foregroundStyle(.red)
                    }
                }

                Section("Vendor (Optional)") {
                    if vendors.isEmpty {
                        Text("No vendors available.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Vendor", selection: $selectedVendor) {
                            Text("No vendor").tag(nil as Vendor?)
                            ForEach(vendors) { vendor in
                                Text(vendor.name).tag(vendor as Vendor?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)

                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...10000)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("$")
                            TextField("Price per unit", text: $pricePerUnit)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        .padding(8)
                        .background(isPriceMissing ? Color.red.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isPriceMissing ? Color.red : Color.clear, lineWidth: 1)
                        )

                        if isPriceMissing {
                            Text("Please enter a valid price")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    HStack {
                        Text("Purchase Details")
                        Text("*")
                            .foregroundStyle(.red)
                    }
                }

                if selectedItem?.isPerishable == true {
                    Section("Expiration") {
                        Toggle("Has Expiration Date", isOn: $hasExpiration)

                        if hasExpiration {
                            DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                        }
                    }
                }

                Section("Additional Info (Optional)") {
                    TextField("Lot Number", text: $lotNumber)

                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let item = selectedItem {
                    Section("Item Info") {
                        LabeledContent("Current Inventory", value: "\(item.currentInventory) \(item.unit.abbreviation)")
                        LabeledContent("Reorder Level", value: "\(item.reorderLevel) \(item.unit.abbreviation)")

                        if let lowestPrice = item.lowestPricePaid {
                            LabeledContent("Lowest Price Paid") {
                                Text(lowestPrice, format: .currency(code: "USD"))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
                        .navigationTitle("Add Purchase")
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
                        if isFormValid {
                            addPurchase()
                        } else {
                            withAnimation {
                                showValidationErrors = true
                            }
                        }
                    }
                }
            }
            .onAppear {
                if let preselected = preselectedItem {
                    selectedItem = preselected
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 500)
        #endif
    }

    private func addPurchase() {
        guard let item = selectedItem,
              let price = Double(pricePerUnit) else { return }

        let purchase = Purchase(
            item: item,
            vendor: selectedVendor,
            date: purchaseDate,
            quantity: quantity,
            pricePerUnit: price,
            lotNumber: lotNumber,
            expirationDate: hasExpiration ? expirationDate : nil,
            notes: notes
        )

        modelContext.insert(purchase)
        dismiss()
    }
}

#Preview {
    AddPurchaseView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
