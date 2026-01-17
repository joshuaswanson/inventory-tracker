import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item

    @State private var showingEditItem = false
    @State private var showingAddPurchase = false
    @State private var showingAddUsage = false

    private var stockPercentage: Double {
        guard item.reorderLevel > 0 else { return 1.0 }
        return min(Double(item.currentInventory) / Double(item.reorderLevel * 2), 1.0)
    }

    private var stockColor: Color {
        if item.needsReorder { return .orange }
        if stockPercentage > 0.5 { return .green }
        return .yellow
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero Card - Inventory Status
                heroCard

                // Stats Grid
                statsGrid

                // Pricing Card
                if item.lowestPricePaid != nil || item.averagePricePaid != nil {
                    pricingCard
                }

                // Expiration Card (for perishables)
                if item.isPerishable {
                    expirationCard
                }

                // Recent Activity
                HStack(spacing: 16) {
                    recentPurchasesCard
                    recentUsageCard
                }

                // Notes
                if !item.notes.isEmpty {
                    notesCard
                }
            }
            .padding()
        }
        .background(Color.primary.opacity(0.03))
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

    // MARK: - Hero Card
    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Current Stock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if item.isPerishable {
                            Image(systemName: "leaf.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(item.currentInventory)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(item.unit.abbreviation)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                stockIndicator
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(stockColor.gradient)
                            .frame(width: geometry.size.width * stockPercentage, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Reorder at \(item.reorderLevel) \(item.unit.abbreviation)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let days = item.estimatedDaysUntilReorder {
                        Text(days <= 0 ? "Reorder now" : "\(days) days until reorder")
                            .font(.footnote)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var stockIndicator: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(stockColor.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: item.needsReorder ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(stockColor)
            }
            Text(item.needsReorder ? "Low Stock" : "In Stock")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(stockColor)
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Daily Usage",
                value: String(format: "%.1f", item.usageRatePerDay),
                unit: item.unit.abbreviation + "/day",
                icon: "chart.line.downtrend.xyaxis",
                color: .blue
            )

            StatCard(
                title: "Purchases",
                value: "\(item.purchases.count)",
                unit: "total",
                icon: "cart.fill",
                color: .purple
            )

            StatCard(
                title: "Usage Records",
                value: "\(item.usageRecords.count)",
                unit: "total",
                icon: "list.bullet.clipboard",
                color: .indigo
            )
        }
    }

    // MARK: - Pricing Card
    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pricing", systemImage: "dollarsign.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            HStack(spacing: 20) {
                if let lowest = item.lowestPricePaid {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best Price")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(lowest, format: .currency(code: "USD"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        if let purchase = item.lowestPricePurchase, let vendor = purchase.vendor {
                            Text(vendor.name)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let average = item.averagePricePaid {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(average, format: .currency(code: "USD"))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Expiration Card
    private var expirationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Expiration", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            if let nextExpiring = item.nextExpiringPurchase {
                HStack {
                    if let days = nextExpiring.daysUntilExpiration {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next Expiring")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("\(days) days")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(expirationColor(days: days))
                        }
                    }

                    Spacer()

                    if let expDate = nextExpiring.expirationDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Date")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(expDate, style: .date)
                                .font(.subheadline)
                        }
                    }
                }

                let expiringItems = item.expiringWithin30Days
                if !expiringItems.isEmpty {
                    Divider()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(expiringItems.count) batch(es) expiring within 30 days")
                            .font(.subheadline)
                    }
                }
            } else {
                Text("No expiring items")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Purchases Card
    private var recentPurchasesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent Purchases", systemImage: "cart.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)
                Spacer()
                Button(action: { showingAddPurchase = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
            }

            if item.purchases.isEmpty {
                Text("No purchases yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(item.purchases.sorted { $0.date > $1.date }.prefix(3), id: \.id) { purchase in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(purchase.date, style: .date)
                                    .font(.subheadline)
                                if let vendor = purchase.vendor {
                                    Text(vendor.name)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(purchase.quantity) \(item.unit.abbreviation)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        if purchase.id != item.purchases.sorted(by: { $0.date > $1.date }).prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Usage Card
    private var recentUsageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent Usage", systemImage: "chart.line.downtrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                Button(action: { showingAddUsage = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if item.usageRecords.isEmpty {
                Text("No usage recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(item.usageRecords.sorted { $0.date > $1.date }.prefix(3), id: \.id) { usage in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(usage.date, style: .date)
                                    .font(.subheadline)
                                if usage.isEstimate {
                                    Text("Estimated")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("-\(usage.quantity) \(item.unit.abbreviation)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                        if usage.id != item.usageRecords.sorted(by: { $0.date > $1.date }).prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
            Text(item.notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func expirationColor(days: Int) -> Color {
        if days < 0 { return .red }
        if days <= 7 { return .orange }
        if days <= 30 { return .yellow }
        return .green
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(unit)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
