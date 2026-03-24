import SwiftUI
import SwiftData

struct PurchasesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]

    @State private var showingAddPurchase = false
    @State private var purchaseToEdit: Purchase?
    @State private var searchText = ""
    @State private var selectedPurchaseID: Purchase.ID?
    @State private var sortOrder = [KeyPathComparator(\Purchase.date, order: .reverse)]

    private var filteredPurchases: [Purchase] {
        var result = purchases
        if !searchText.isEmpty {
            result = result.filter {
                $0.item?.name.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.vendor?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        return result.sorted(using: sortOrder)
    }

    var body: some View {
        NavigationStack {
            Table(filteredPurchases, selection: $selectedPurchaseID, sortOrder: $sortOrder) {
                TableColumn("Date", value: \.date) { purchase in
                    Text(purchase.date, format: .dateTime.month(.abbreviated).day().year())
                }
                .width(min: 90, ideal: 110)

                TableColumn("Item") { (purchase: Purchase) in
                    Text(purchase.item?.name ?? "Unknown")
                        .lineLimit(1)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Vendor") { (purchase: Purchase) in
                    Text(purchase.vendor?.name ?? "-")
                        .foregroundStyle(purchase.vendor == nil ? .tertiary : .primary)
                        .lineLimit(1)
                }
                .width(min: 100, ideal: 140)

                TableColumn("Qty", value: \.quantity) { purchase in
                    if let item = purchase.item {
                        Text("\(purchase.quantity) \(item.unit.abbreviation)")
                    } else {
                        Text("\(purchase.quantity)")
                    }
                }
                .width(60)

                TableColumn("Price/Unit", value: \.pricePerUnit) { purchase in
                    Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                }
                .width(80)

                TableColumn("Total") { (purchase: Purchase) in
                    Text(purchase.totalCost, format: .currency(code: "USD"))
                        .fontWeight(.medium)
                }
                .width(80)

                TableColumn("Expires") { (purchase: Purchase) in
                    if let expDate = purchase.expirationDate {
                        Text(expDate, format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(expirationColor(for: purchase))
                    } else {
                        Text("-")
                            .foregroundStyle(.tertiary)
                    }
                }
                .width(70)

                TableColumn("Lot #", value: \.lotNumber) { purchase in
                    Text(purchase.lotNumber.isEmpty ? "-" : purchase.lotNumber)
                        .foregroundStyle(purchase.lotNumber.isEmpty ? .tertiary : .secondary)
                        .lineLimit(1)
                }
                .width(min: 60, ideal: 90)
            }
            .contextMenu(forSelectionType: Purchase.ID.self) { ids in
                if let id = ids.first, let purchase = purchases.first(where: { $0.id == id }) {
                    Button("Edit") { purchaseToEdit = purchase }
                    Divider()
                    Button("Delete", role: .destructive) {
                        modelContext.delete(purchase)
                        if selectedPurchaseID == id { selectedPurchaseID = nil }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by item or vendor")
            .navigationTitle("Purchases")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPurchase = true }) {
                        Label("Add Purchase", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPurchase) {
                AddPurchaseView()
            }
            .sheet(item: $purchaseToEdit) { purchase in
                EditPurchaseView(purchase: purchase)
            }
        }
    }

    private func expirationColor(for purchase: Purchase) -> Color {
        switch purchase.expirationStatus {
        case .expired: return .red
        case .critical: return .orange
        case .warning: return .yellow
        case .good: return .green
        case .notApplicable: return .secondary
        }
    }
}

// MARK: - Edit Purchase View
struct EditPurchaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { !$0.isDeleted }, sort: \Item.name) private var items: [Item]
    @Query(filter: #Predicate<Vendor> { !$0.isDeleted }, sort: \Vendor.name) private var vendors: [Vendor]
    @Bindable var purchase: Purchase

    @State private var selectedVendor: Vendor?
    @State private var date: Date = Date()
    @State private var quantity: Int = 1
    @State private var pricePerUnit: String = ""
    @State private var hasExpirationDate: Bool = false
    @State private var expirationDate: Date = Date()
    @State private var lotNumber: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    if let item = purchase.item {
                        Text(item.name)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Vendor") {
                    Picker("Vendor", selection: $selectedVendor) {
                        Text("None").tag(nil as Vendor?)
                        ForEach(vendors) { vendor in
                            Text(vendor.name).tag(vendor as Vendor?)
                        }
                    }
                }

                Section("Purchase Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...10000)
                    HStack {
                        Text("Price per Unit")
                        Spacer()
                        TextField("0.00", text: $pricePerUnit)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }

                if purchase.item?.isPerishable == true {
                    Section("Expiration") {
                        Toggle("Has Expiration Date", isOn: $hasExpirationDate)
                        if hasExpirationDate {
                            DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                        }
                    }
                }

                Section("Additional Info") {
                    TextField("Lot Number", text: $lotNumber)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Purchase")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                    .disabled(quantity < 1 || (Double(pricePerUnit) ?? 0) <= 0)
                }
            }
            .onAppear {
                selectedVendor = purchase.vendor
                date = purchase.date
                quantity = purchase.quantity
                pricePerUnit = String(format: "%.2f", purchase.pricePerUnit)
                hasExpirationDate = purchase.expirationDate != nil
                expirationDate = purchase.expirationDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
                lotNumber = purchase.lotNumber
                notes = purchase.notes
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 450)
        #endif
    }

    private func saveChanges() {
        purchase.vendor = selectedVendor
        purchase.date = date
        purchase.quantity = quantity
        purchase.pricePerUnit = Double(pricePerUnit) ?? 0
        purchase.expirationDate = hasExpirationDate ? expirationDate : nil
        purchase.lotNumber = lotNumber
        purchase.notes = notes
        dismiss()
    }
}

#Preview {
    PurchasesListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
