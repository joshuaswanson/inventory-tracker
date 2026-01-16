import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item

    @State private var showingEditItem = false
    @State private var showingAddPurchase = false
    @State private var showingAddUsage = false

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Current Inventory") {
                    HStack {
                        Text("\(item.currentInventory) \(item.unit.abbreviation)")
                            .fontWeight(.semibold)
                        if item.needsReorder {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                LabeledContent("Reorder Level", value: "\(item.reorderLevel) \(item.unit.abbreviation)")
                LabeledContent("Unit of Measure", value: item.unit.rawValue)

                if item.isPerishable {
                    LabeledContent("Type") {
                        Label("Perishable", systemImage: "leaf")
                            .foregroundStyle(.green)
                    }
                }
            }

            Section("Pricing") {
                if let lowest = item.lowestPricePaid {
                    LabeledContent("Lowest Price Paid") {
                        Text(lowest, format: .currency(code: "USD"))
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                    }

                    if let purchase = item.lowestPricePurchase, let vendor = purchase.vendor {
                        LabeledContent("Best Price Vendor", value: vendor.name)
                    }
                }

                if let average = item.averagePricePaid {
                    LabeledContent("Average Price", value: average, format: .currency(code: "USD"))
                }
            }

            Section("Usage Analytics") {
                LabeledContent("Daily Usage Rate") {
                    Text(String(format: "%.1f %@/day", item.usageRatePerDay, item.unit.abbreviation))
                }

                if let daysLeft = item.estimatedDaysUntilReorder {
                    LabeledContent("Days Until Reorder") {
                        Text("\(daysLeft) days")
                            .foregroundStyle(daysLeft <= 7 ? .orange : .primary)
                    }
                }

                LabeledContent("Total Usage Records", value: "\(item.usageRecords.count)")
            }

            if item.isPerishable {
                Section("Expiration Tracking") {
                    if let nextExpiring = item.nextExpiringPurchase {
                        if let days = nextExpiring.daysUntilExpiration {
                            LabeledContent("Next Expiring") {
                                Text("\(days) days")
                                    .foregroundStyle(expirationColor(days: days))
                            }
                        }

                        if let expDate = nextExpiring.expirationDate {
                            LabeledContent("Expiration Date") {
                                Text(expDate, style: .date)
                            }
                        }
                    }

                    let expiringItems = item.expiringWithin30Days
                    if !expiringItems.isEmpty {
                        LabeledContent("Expiring Within 30 Days") {
                            Text("\(expiringItems.count) batch(es)")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section("Recent Purchases") {
                if item.purchases.isEmpty {
                    Text("No purchases yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.purchases.sorted { $0.date > $1.date }.prefix(5), id: \.id) { purchase in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(purchase.date, style: .date)
                                    .font(.subheadline)
                                Spacer()
                                Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                                    .fontWeight(.medium)
                            }
                            HStack {
                                Text("\(purchase.quantity) \(item.unit.abbreviation)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let vendor = purchase.vendor {
                                    Text("from \(vendor.name)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Button(action: { showingAddPurchase = true }) {
                    Label("Add Purchase", systemImage: "plus.circle")
                }
            }

            Section("Recent Usage") {
                if item.usageRecords.isEmpty {
                    Text("No usage recorded yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.usageRecords.sorted { $0.date > $1.date }.prefix(5), id: \.id) { usage in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(usage.date, style: .date)
                                    .font(.subheadline)
                                if usage.isEstimate {
                                    Text("Estimated")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("-\(usage.quantity) \(item.unit.abbreviation)")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Button(action: { showingAddUsage = true }) {
                    Label("Record Usage", systemImage: "minus.circle")
                }
            }

            if !item.notes.isEmpty {
                Section("Notes") {
                    Text(item.notes)
                }
            }
        }
        .navigationTitle(item.name)
        .toolbar {
            Button("Edit") {
                showingEditItem = true
            }
        }
        .sheet(isPresented: $showingEditItem) {
            EditItemView(item: item)
        }
        .sheet(isPresented: $showingAddPurchase) {
            AddPurchaseView(preselectedItem: item)
        }
        .sheet(isPresented: $showingAddUsage) {
            AddUsageView(preselectedItem: item)
        }
    }

    private func expirationColor(days: Int) -> Color {
        if days < 0 { return .red }
        if days <= 7 { return .orange }
        if days <= 30 { return .yellow }
        return .green
    }
}

struct EditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Item

    @State private var name: String = ""
    @State private var selectedUnit: UnitOfMeasure = .each
    @State private var reorderLevel: Int = 10
    @State private var isPerishable: Bool = false
    @State private var notes: String = ""

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

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
            }
            .formStyle(.grouped)
                        .navigationTitle("Edit Item")
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
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = item.name
                selectedUnit = item.unit
                reorderLevel = item.reorderLevel
                isPerishable = item.isPerishable
                notes = item.notes
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 350)
        .padding()
        #endif
    }

    private func saveChanges() {
        item.name = name
        item.unitOfMeasure = selectedUnit.rawValue
        item.reorderLevel = reorderLevel
        item.isPerishable = isPerishable
        item.notes = notes
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: Item(name: "Sample Item", reorderLevel: 5))
    }
    .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
