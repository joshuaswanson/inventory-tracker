import SwiftUI
import SwiftData

enum PurchaseSortOption: String, CaseIterable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case priceHighest = "Highest Price"
    case priceLowest = "Lowest Price"
    case expirationSoonest = "Expiring Soon"
}

struct PurchasesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]

    @State private var showingAddPurchase = false
    @State private var searchText = ""
    @State private var selectedItem: Item?
    @State private var sortOption: PurchaseSortOption = .dateNewest
    @State private var showExpiringSoonOnly = false
    @State private var purchaseToEdit: Purchase?
    @FocusState private var focusedPurchaseId: UUID?

    var filteredPurchases: [Purchase] {
        var result = purchases

        if let item = selectedItem {
            result = result.filter { $0.item?.id == item.id }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.item?.name.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.vendor?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        if showExpiringSoonOnly {
            result = result.filter { purchase in
                if let days = purchase.daysUntilExpiration {
                    return days <= 30 && days >= 0
                }
                return false
            }
        }

        // Apply sorting
        switch sortOption {
        case .dateNewest:
            result.sort { $0.date > $1.date }
        case .dateOldest:
            result.sort { $0.date < $1.date }
        case .priceHighest:
            result.sort { $0.pricePerUnit > $1.pricePerUnit }
        case .priceLowest:
            result.sort { $0.pricePerUnit < $1.pricePerUnit }
        case .expirationSoonest:
            result.sort { p1, p2 in
                let d1 = p1.daysUntilExpiration ?? Int.max
                let d2 = p2.daysUntilExpiration ?? Int.max
                return d1 < d2
            }
        }

        return result
    }

    // Group purchases by date
    private var groupedPurchases: [(String, [Purchase])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!

        var todayPurchases: [Purchase] = []
        var thisWeekPurchases: [Purchase] = []
        var thisMonthPurchases: [Purchase] = []
        var olderPurchases: [Purchase] = []

        for purchase in filteredPurchases {
            let purchaseDate = calendar.startOfDay(for: purchase.date)
            if purchaseDate >= today {
                todayPurchases.append(purchase)
            } else if purchaseDate >= weekAgo {
                thisWeekPurchases.append(purchase)
            } else if purchaseDate >= monthAgo {
                thisMonthPurchases.append(purchase)
            } else {
                olderPurchases.append(purchase)
            }
        }

        var result: [(String, [Purchase])] = []

        // Reverse section order when sorting by oldest first
        if sortOption == .dateOldest {
            if !olderPurchases.isEmpty { result.append(("Earlier", olderPurchases)) }
            if !thisMonthPurchases.isEmpty { result.append(("This Month", thisMonthPurchases)) }
            if !thisWeekPurchases.isEmpty { result.append(("This Week", thisWeekPurchases)) }
            if !todayPurchases.isEmpty { result.append(("Today", todayPurchases)) }
        } else {
            if !todayPurchases.isEmpty { result.append(("Today", todayPurchases)) }
            if !thisWeekPurchases.isEmpty { result.append(("This Week", thisWeekPurchases)) }
            if !thisMonthPurchases.isEmpty { result.append(("This Month", thisMonthPurchases)) }
            if !olderPurchases.isEmpty { result.append(("Earlier", olderPurchases)) }
        }

        return result
    }

    // Summary calculations
    private var totalSpent: Double {
        filteredPurchases.reduce(0) { $0 + $1.totalCost }
    }

    private var expiringSoonCount: Int {
        purchases.filter { purchase in
            if let days = purchase.daysUntilExpiration {
                return days <= 30 && days >= 0
            }
            return false
        }.count
    }

    private var expiredCount: Int {
        purchases.filter { $0.isExpired }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Divider()

                if filteredPurchases.isEmpty && searchText.isEmpty && !showExpiringSoonOnly {
                    emptyStateView
                } else if filteredPurchases.isEmpty {
                    noResultsView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Summary Header
                            summaryHeader
                                .frame(maxWidth: 700)
                                .padding(.horizontal)
                                .padding(.top, 16)

                            // Grouped List
                            LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                                ForEach(groupedPurchases, id: \.0) { section, sectionPurchases in
                                    Section {
                                        VStack(spacing: 10) {
                                            ForEach(sectionPurchases) { purchase in
                                                PurchaseCardView(purchase: purchase, isHighlighted: focusedPurchaseId == purchase.id)
                                                    .focusable()
                                                    .focused($focusedPurchaseId, equals: purchase.id)
                                                    .contextMenu {
                                                        Button {
                                                            purchaseToEdit = purchase
                                                        } label: {
                                                            Label("Edit", systemImage: "pencil")
                                                        }

                                                        Divider()

                                                        Button(role: .destructive) {
                                                            modelContext.delete(purchase)
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                    }
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal)
                                    } header: {
                                        sectionHeader(section)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color.primary.opacity(0.03))
                }
            }
            .navigationTitle("Purchases")
            .searchable(text: $searchText, prompt: "Search by item or vendor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPurchase = true }) {
                        Label("Add Purchase", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Toggle(isOn: $showExpiringSoonOnly) {
                            Label("Expiring Soon Only", systemImage: "clock.badge.exclamationmark")
                        }

                        Divider()

                        Menu("Sort By") {
                            ForEach(PurchaseSortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                } label: {
                                    if sortOption == option {
                                        Label(option.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: showExpiringSoonOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    }
                    .menuIndicator(.hidden)
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

    // MARK: - Summary Header
    private var summaryHeader: some View {
        HStack(spacing: 12) {
            SummaryStatView(
                title: "Purchases",
                value: "\(filteredPurchases.count)",
                icon: "cart.fill",
                color: .purple
            )

            SummaryStatView(
                title: "Total Spent",
                value: totalSpent.formatted(.currency(code: "USD")),
                icon: "dollarsign.circle.fill",
                color: .green
            )

            if expiringSoonCount > 0 {
                SummaryStatView(
                    title: "Expiring Soon",
                    value: "\(expiringSoonCount)",
                    icon: "clock.badge.exclamationmark.fill",
                    color: .orange
                )
            }

            if expiredCount > 0 {
                SummaryStatView(
                    title: "Expired",
                    value: "\(expiredCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Purchases", systemImage: "cart")
        } description: {
            Text("Record purchases to track inventory and pricing.")
        } actions: {
            Button(action: { showingAddPurchase = true }) {
                Text("Add Purchase")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                showingAddPurchase = true
            } label: {
                Label("Add Purchase", systemImage: "plus")
            }
        }
    }

    // MARK: - No Results View
    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            if showExpiringSoonOnly {
                Text("No purchases expiring within 30 days.")
            } else {
                Text("No purchases match your search.")
            }
        } actions: {
            if showExpiringSoonOnly {
                Button("Show All Purchases") {
                    showExpiringSoonOnly = false
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deletePurchases(at offsets: IndexSet) {
        for index in offsets {
            let purchase = filteredPurchases[index]
            modelContext.delete(purchase)
        }
    }
}

// MARK: - Summary Stat View
struct SummaryStatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 110)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Purchase Card View
struct PurchaseCardView: View {
    let purchase: Purchase
    var isHighlighted: Bool = false

    private var expirationColor: Color {
        switch purchase.expirationStatus {
        case .expired: return .red
        case .critical: return .orange
        case .warning: return .yellow
        case .good: return .green
        case .notApplicable: return .clear
        }
    }

    private var highlightColor: Color {
        if purchase.expirationDate != nil {
            return expirationColor
        }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left accent bar for expiration status
            if purchase.expirationDate != nil {
                RoundedRectangle(cornerRadius: 3)
                    .fill(expirationColor.gradient)
                    .frame(width: 5)
            }

            VStack(alignment: .leading, spacing: 10) {
                // Top row: Item name and price
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let item = purchase.item {
                            HStack(spacing: 8) {
                                Text(item.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)

                                if item.isPerishable {
                                    Image(systemName: "leaf.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                }
                            }
                        } else {
                            Text("Unknown Item")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }

                        if let vendor = purchase.vendor {
                            HStack(spacing: 5) {
                                Image(systemName: "building.2")
                                    .font(.caption)
                                Text(vendor.name)
                            }
                            .font(.body)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.green)

                        Text("per unit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Divider
                Divider()

                // Bottom row: Date, quantity, and expiration
                HStack {
                    // Date
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.subheadline)
                        Text(purchase.date, style: .date)
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)

                    Spacer()

                    // Quantity
                    if let item = purchase.item {
                        HStack(spacing: 5) {
                            Image(systemName: "shippingbox")
                                .font(.subheadline)
                            Text("\(purchase.quantity) \(item.unit.abbreviation)")
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Total cost
                    Text(purchase.totalCost, format: .currency(code: "USD"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                // Expiration status if applicable
                if purchase.isExpired {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Expired")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                } else if let days = purchase.daysUntilExpiration, days <= 30 {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                        Text(days == 0 ? "Expires today" : days == 1 ? "Expires tomorrow" : "Expires in \(days) days")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(days <= 7 ? .orange : .yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((days <= 7 ? Color.orange : Color.yellow).opacity(0.1))
                    .clipShape(Capsule())
                }

                // Lot number if present
                if !purchase.lotNumber.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "number")
                            .font(.caption)
                        Text("Lot: \(purchase.lotNumber)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
        .padding(16)
        .frame(maxWidth: 700)
        .background(isHighlighted ? highlightColor.opacity(0.1) : Color.clear)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(highlightColor.opacity(isHighlighted ? 0.6 : 0), lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
    }
}

// MARK: - Edit Purchase View
struct EditPurchaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { !$0.isDeleted }, sort: \Item.name) private var items: [Item]
    @Query(filter: #Predicate<Vendor> { !$0.isDeleted }, sort: \Vendor.name) private var vendors: [Vendor]
    @Bindable var purchase: Purchase

    @State private var selectedItem: Item?
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(quantity < 1 || (Double(pricePerUnit) ?? 0) <= 0)
                }
            }
            .onAppear {
                selectedItem = purchase.item
                selectedVendor = purchase.vendor
                date = purchase.date
                quantity = purchase.quantity
                pricePerUnit = String(format: "%.2f", purchase.pricePerUnit)
                hasExpirationDate = purchase.expirationDate != nil
                expirationDate = purchase.expirationDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())!
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
