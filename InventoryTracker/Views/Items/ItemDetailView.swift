import SwiftUI
import SwiftData
import PhotosUI

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item

    @State private var showingEditItem = false
    @State private var showingAddPurchase = false
    @State private var showingAddUsage = false
    @FocusState private var isNotesFocused: Bool

    private var stockColor: Color {
        if item.needsReorder { return .orange }
        if item.currentInventory > item.reorderLevel * 2 { return .green }
        return .yellow
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                stockCard
                metricsRow
                expirationCard

                HStack(alignment: .top, spacing: 12) {
                    recentPurchasesCard
                    recentUsageCard
                }

                notesCard
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture { isNotesFocused = false }
        .background(Color.primary.opacity(0.03))
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button("Edit") { showingEditItem = true }
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

    // MARK: - Stock Card
    private var stockCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Stock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(item.currentInventory)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(stockColor)
                    Text(item.unit.abbreviation)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text("Reorder at \(item.reorderLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !item.storageLocation.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(item.storageLocation, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                }
            }

            if item.needsReorder {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Low Stock")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Metrics Row
    @ViewBuilder
    private var metricsRow: some View {
        let hasMetrics = item.lowestPricePaid != nil || item.averagePricePaid != nil || item.usageRatePerDay > 0
        if hasMetrics {
            HStack(spacing: 12) {
                if let bestPrice = item.lowestPricePaid {
                    metricCard(
                        title: "Best Price",
                        value: bestPrice.formatted(.currency(code: "USD")),
                        detail: item.lowestPricePurchase?.vendor?.name,
                        color: .green
                    )
                }

                if let avgPrice = item.averagePricePaid {
                    metricCard(
                        title: "Avg Price",
                        value: avgPrice.formatted(.currency(code: "USD")),
                        detail: nil,
                        color: .blue
                    )
                }

                if item.usageRatePerDay > 0 {
                    let detail: String? = item.estimatedDaysUntilReorder.map { "\($0) days to reorder" }
                    metricCard(
                        title: "Usage Rate",
                        value: String(format: "%.1f/day", item.usageRatePerDay),
                        detail: detail,
                        color: .purple
                    )
                }
            }
        }
    }

    // MARK: - Expiration Card
    @ViewBuilder
    private var expirationCard: some View {
        if item.isPerishable, let nextExpiring = item.nextExpiringPurchase,
           let days = nextExpiring.daysUntilExpiration {
            let expirationColor: Color = days <= 7 ? .red : (days <= 30 ? .orange : .green)
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(expirationColor)
                Text("Next expiration: \(days) days")
                    .font(.subheadline)
                if let expDate = nextExpiring.expirationDate {
                    Spacer()
                    Text(expDate, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Recent Purchases
    private var recentPurchasesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Recent Purchases", systemImage: "cart.fill")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddPurchase = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            if item.purchases.isEmpty {
                Text("No purchases yet")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 8)
            } else {
                let recent = Array(item.purchases.sorted { $0.date > $1.date }.prefix(5))
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, purchase in
                    purchaseRow(purchase)
                    if index < recent.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func purchaseRow(_ purchase: Purchase) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(purchase.date, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                if let vendor = purchase.vendor {
                    Text(vendor.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                    .font(.subheadline)
                Text("\(purchase.quantity) \(item.unit.abbreviation)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Recent Usage
    private var recentUsageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Recent Usage", systemImage: "chart.line.downtrend.xyaxis")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddUsage = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            if item.usageRecords.isEmpty {
                Text("No usage recorded")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 8)
            } else {
                let recent = Array(item.usageRecords.sorted { $0.date > $1.date }.prefix(5))
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, usage in
                    usageRow(usage)
                    if index < recent.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func usageRow(_ usage: Usage) -> some View {
        HStack {
            Text(usage.date, format: .dateTime.month(.abbreviated).day())
                .font(.subheadline)
            if usage.isEstimate {
                Text("Est.")
                    .font(.caption2)
                    .foregroundStyle(.teal)
            }
            Spacer()
            Text("-\(usage.quantity) \(item.unit.abbreviation)")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Notes
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
            TextEditor(text: $item.notes)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
                .focused($isNotesFocused)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Metric Card
    private func metricCard(title: String, value: String, detail: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Edit Item View
struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Item

    @State private var name: String = ""
    @State private var selectedUnit: UnitOfMeasure = .each
    @State private var reorderLevel: Int = 10
    @State private var isPerishable: Bool = false
    @State private var storageLocation: String = ""
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

                Section("Storage Location") {
                    TextField("e.g., Supply Room A, Cabinet 3", text: $storageLocation)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = item.name
                selectedUnit = item.unit
                reorderLevel = item.reorderLevel
                isPerishable = item.isPerishable
                storageLocation = item.storageLocation
                notes = item.notes
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 350)
        #endif
    }

    private func saveChanges() {
        item.name = name
        item.unitOfMeasure = selectedUnit.rawValue
        item.reorderLevel = reorderLevel
        item.isPerishable = isPerishable
        item.storageLocation = storageLocation
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
