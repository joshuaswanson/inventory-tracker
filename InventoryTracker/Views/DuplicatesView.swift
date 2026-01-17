import SwiftUI
import SwiftData

struct DuplicateGroup<T: Identifiable>: Identifiable {
    let id = UUID()
    let items: [T]
    let reason: String
}

enum DuplicateSelection: Hashable {
    case items([Item])
    case vendors([Vendor])
    case purchases([Purchase])
    case usages([Usage])

    func hash(into hasher: inout Hasher) {
        switch self {
        case .items(let items):
            hasher.combine("items")
            for item in items { hasher.combine(item.id) }
        case .vendors(let vendors):
            hasher.combine("vendors")
            for vendor in vendors { hasher.combine(vendor.id) }
        case .purchases(let purchases):
            hasher.combine("purchases")
            for purchase in purchases { hasher.combine(purchase.id) }
        case .usages(let usages):
            hasher.combine("usages")
            for usage in usages { hasher.combine(usage.id) }
        }
    }

    static func == (lhs: DuplicateSelection, rhs: DuplicateSelection) -> Bool {
        switch (lhs, rhs) {
        case (.items(let l), .items(let r)):
            return l.map(\.id) == r.map(\.id)
        case (.vendors(let l), .vendors(let r)):
            return l.map(\.id) == r.map(\.id)
        case (.purchases(let l), .purchases(let r)):
            return l.map(\.id) == r.map(\.id)
        case (.usages(let l), .usages(let r)):
            return l.map(\.id) == r.map(\.id)
        default:
            return false
        }
    }
}

struct DuplicatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Item> { !$0.isDeleted }) private var items: [Item]
    @Query(filter: #Predicate<Vendor> { !$0.isDeleted }) private var vendors: [Vendor]
    @Query private var purchases: [Purchase]
    @Query private var usages: [Usage]

    @State private var selection: DuplicateSelection?
    @State private var duplicateItems: [[Item]] = []
    @State private var duplicateVendors: [[Vendor]] = []
    @State private var duplicatePurchases: [[Purchase]] = []
    @State private var duplicateUsages: [[Usage]] = []
    @State private var isLoading = true

    private var hasDuplicates: Bool {
        !duplicateItems.isEmpty || !duplicateVendors.isEmpty ||
        !duplicatePurchases.isEmpty || !duplicateUsages.isEmpty
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Scanning for duplicates...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasDuplicates {
                ContentUnavailableView {
                    Label("No Duplicates Found", systemImage: "checkmark.circle")
                } description: {
                    Text("Your inventory data looks clean. No suspected duplicates were detected.")
                }
            } else {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 0) {
                        // Left: List of duplicate groups
                        List(selection: $selection) {
                            if !duplicateItems.isEmpty {
                                Section("Items (\(duplicateItems.count) groups)") {
                                    ForEach(duplicateItems, id: \.first?.id) { group in
                                        DuplicateItemGroupRow(items: group)
                                            .tag(DuplicateSelection.items(group))
                                    }
                                }
                            }

                            if !duplicateVendors.isEmpty {
                                Section("Vendors (\(duplicateVendors.count) groups)") {
                                    ForEach(duplicateVendors, id: \.first?.id) { group in
                                        DuplicateVendorGroupRow(vendors: group)
                                            .tag(DuplicateSelection.vendors(group))
                                    }
                                }
                            }

                            if !duplicatePurchases.isEmpty {
                                Section("Purchases (\(duplicatePurchases.count) groups)") {
                                    ForEach(duplicatePurchases, id: \.first?.id) { group in
                                        DuplicatePurchaseGroupRow(purchases: group)
                                            .tag(DuplicateSelection.purchases(group))
                                    }
                                }
                            }

                            if !duplicateUsages.isEmpty {
                                Section("Usage Records (\(duplicateUsages.count) groups)") {
                                    ForEach(duplicateUsages, id: \.first?.id) { group in
                                        DuplicateUsageGroupRow(usages: group)
                                            .tag(DuplicateSelection.usages(group))
                                    }
                                }
                            }
                        }
                        .listStyle(.inset(alternatesRowBackgrounds: false))
                        .frame(width: 300)

                        Divider()

                        // Right: Detail view
                        Group {
                            switch selection {
                            case .items(let items):
                                DuplicateItemsDetailView(items: items)
                            case .vendors(let vendors):
                                DuplicateVendorsDetailView(vendors: vendors)
                            case .purchases(let purchases):
                                DuplicatePurchasesDetailView(purchases: purchases)
                            case .usages(let usages):
                                DuplicateUsagesDetailView(usages: usages)
                            case nil:
                                ContentUnavailableView {
                                    Label("No Selection", systemImage: "doc.on.doc")
                                } description: {
                                    Text("Select a duplicate group to view details and resolve.")
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Duplicates")
        .task {
            await recalculateDuplicates()
        }
        .onChange(of: items.count) {
            Task { await recalculateDuplicates() }
        }
        .onChange(of: vendors.count) {
            Task { await recalculateDuplicates() }
        }
        .onChange(of: purchases.count) {
            Task { await recalculateDuplicates() }
        }
        .onChange(of: usages.count) {
            Task { await recalculateDuplicates() }
        }
    }

    private func recalculateDuplicates() async {
        isLoading = true

        // Run expensive calculations off main thread
        let itemDupes = findDuplicateItems()
        let vendorDupes = findDuplicateVendors()
        let purchaseDupes = findDuplicatePurchases()
        let usageDupes = findDuplicateUsages()

        await MainActor.run {
            duplicateItems = itemDupes
            duplicateVendors = vendorDupes
            duplicatePurchases = purchaseDupes
            duplicateUsages = usageDupes
            isLoading = false
        }
    }

    // MARK: - Duplicate Detection

    private func findDuplicateItems() -> [[Item]] {
        var groups: [[Item]] = []
        var processed = Set<UUID>()

        for item in items {
            guard !processed.contains(item.id) else { continue }

            let normalizedName = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let similar = items.filter { other in
                guard other.id != item.id, !processed.contains(other.id) else { return false }
                let otherName = other.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return normalizedName == otherName || levenshteinDistance(normalizedName, otherName) <= 2
            }

            if !similar.isEmpty {
                let group = [item] + similar
                groups.append(group)
                group.forEach { processed.insert($0.id) }
            }
        }

        return groups
    }

    private func findDuplicateVendors() -> [[Vendor]] {
        var groups: [[Vendor]] = []
        var processed = Set<UUID>()

        for vendor in vendors {
            guard !processed.contains(vendor.id) else { continue }

            let normalizedName = vendor.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedPhone = vendor.phone.filter { $0.isNumber }
            let normalizedEmail = vendor.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            let similar = vendors.filter { other in
                guard other.id != vendor.id, !processed.contains(other.id) else { return false }

                let otherName = other.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let otherPhone = other.phone.filter { $0.isNumber }
                let otherEmail = other.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                // Match on similar name
                if normalizedName == otherName || levenshteinDistance(normalizedName, otherName) <= 2 {
                    return true
                }

                // Match on same phone (if both have phones)
                if !normalizedPhone.isEmpty && !otherPhone.isEmpty && normalizedPhone == otherPhone {
                    return true
                }

                // Match on same email (if both have emails)
                if !normalizedEmail.isEmpty && !otherEmail.isEmpty && normalizedEmail == otherEmail {
                    return true
                }

                return false
            }

            if !similar.isEmpty {
                let group = [vendor] + similar
                groups.append(group)
                group.forEach { processed.insert($0.id) }
            }
        }

        return groups
    }

    private func findDuplicatePurchases() -> [[Purchase]] {
        var groups: [[Purchase]] = []
        var processed = Set<UUID>()

        // Only consider purchases with valid items
        let validPurchases = purchases.filter { $0.item != nil && !($0.item?.isDeleted ?? true) }

        for purchase in validPurchases {
            guard !processed.contains(purchase.id) else { continue }

            let similar = validPurchases.filter { other in
                guard other.id != purchase.id, !processed.contains(other.id) else { return false }

                // Same item, vendor, date, and quantity
                let sameItem = purchase.item?.id == other.item?.id
                let sameVendor = purchase.vendor?.id == other.vendor?.id
                let sameDate = Calendar.current.isDate(purchase.date, inSameDayAs: other.date)
                let sameQuantity = purchase.quantity == other.quantity
                let samePrice = abs(purchase.pricePerUnit - other.pricePerUnit) < 0.01

                return sameItem && sameVendor && sameDate && sameQuantity && samePrice
            }

            if !similar.isEmpty {
                let group = [purchase] + similar
                groups.append(group)
                group.forEach { processed.insert($0.id) }
            }
        }

        return groups
    }

    private func findDuplicateUsages() -> [[Usage]] {
        var groups: [[Usage]] = []
        var processed = Set<UUID>()

        // Only consider usages with valid items
        let validUsages = usages.filter { $0.item != nil && !($0.item?.isDeleted ?? true) }

        for usage in validUsages {
            guard !processed.contains(usage.id) else { continue }

            let similar = validUsages.filter { other in
                guard other.id != usage.id, !processed.contains(other.id) else { return false }

                // Same item, date, and quantity
                let sameItem = usage.item?.id == other.item?.id
                let sameDate = Calendar.current.isDate(usage.date, inSameDayAs: other.date)
                let sameQuantity = usage.quantity == other.quantity

                return sameItem && sameDate && sameQuantity
            }

            if !similar.isEmpty {
                let group = [usage] + similar
                groups.append(group)
                group.forEach { processed.insert($0.id) }
            }
        }

        return groups
    }

    // MARK: - Levenshtein Distance

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[m][n]
    }
}

// MARK: - Row Views

struct DuplicateItemGroupRow: View {
    let items: [Item]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(items.first?.name ?? "Unknown")
                    .font(.headline)
                Text("\(items.count) similar items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "shippingbox")
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}

struct DuplicateVendorGroupRow: View {
    let vendors: [Vendor]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vendors.first?.name ?? "Unknown")
                    .font(.headline)
                Text("\(vendors.count) similar vendors")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "building.2")
                .foregroundStyle(.purple)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}

struct DuplicatePurchaseGroupRow: View {
    let purchases: [Purchase]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(purchases.first?.item?.name ?? "Unknown Item")
                    .font(.headline)
                Text("\(purchases.count) duplicate purchases")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "cart")
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}

struct DuplicateUsageGroupRow: View {
    let usages: [Usage]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(usages.first?.item?.name ?? "Unknown Item")
                    .font(.headline)
                Text("\(usages.count) duplicate records")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chart.line.downtrend.xyaxis")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}

// MARK: - Detail Views

struct DuplicateItemsDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let items: [Item]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Warning Banner
                warningBanner

                // Items Comparison
                VStack(alignment: .leading, spacing: 12) {
                    Label("Suspected Duplicates", systemImage: "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    ForEach(items) { item in
                        DuplicateItemCard(item: item, onDelete: {
                            item.isDeleted = true
                            item.deletedAt = Date()
                        })
                    }
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .background(Color.primary.opacity(0.03))
    }

    private var warningBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Possible Duplicate Items")
                    .font(.headline)
                Spacer()
            }

            Text("These items have similar names and may be duplicates. Review them and delete any that are redundant.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DuplicateItemCard: View {
    let item: Item
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                    Text("Created \(item.createdAt, style: .date)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.currentInventory) \(item.unit.abbreviation)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(item.purchases.count) purchases")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DuplicateVendorsDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let vendors: [Vendor]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Warning Banner
                warningBanner

                // Vendors Comparison
                VStack(alignment: .leading, spacing: 12) {
                    Label("Suspected Duplicates", systemImage: "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(.purple)

                    ForEach(vendors) { vendor in
                        DuplicateVendorCard(vendor: vendor, onDelete: {
                            vendor.isDeleted = true
                            vendor.deletedAt = Date()
                        })
                    }
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .background(Color.primary.opacity(0.03))
    }

    private var warningBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.purple)
                Text("Possible Duplicate Vendors")
                    .font(.headline)
                Spacer()
            }

            Text("These vendors have similar names, phone numbers, or emails. Review them and delete any that are redundant.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DuplicateVendorCard: View {
    let vendor: Vendor
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vendor.name)
                        .font(.headline)
                    if !vendor.contactName.isEmpty {
                        Text(vendor.contactName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(vendor.totalPurchases) orders")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(vendor.totalSpent, format: .currency(code: "USD"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !vendor.phone.isEmpty || !vendor.email.isEmpty {
                HStack(spacing: 16) {
                    if !vendor.phone.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "phone")
                                .font(.footnote)
                            Text(vendor.phone)
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                    }
                    if !vendor.email.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope")
                                .font(.footnote)
                            Text(vendor.email)
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DuplicatePurchasesDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let purchases: [Purchase]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Warning Banner
                warningBanner

                // Purchases Comparison
                VStack(alignment: .leading, spacing: 12) {
                    Label("Suspected Duplicates", systemImage: "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    ForEach(purchases) { purchase in
                        DuplicatePurchaseCard(purchase: purchase, onDelete: {
                            modelContext.delete(purchase)
                        })
                    }
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .background(Color.primary.opacity(0.03))
    }

    private var warningBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.blue)
                Text("Possible Duplicate Purchases")
                    .font(.headline)
                Spacer()
            }

            Text("These purchases have the same item, vendor, date, quantity, and price. They may have been entered twice by mistake.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DuplicatePurchaseCard: View {
    let purchase: Purchase
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(purchase.item?.name ?? "Unknown Item")
                        .font(.headline)
                    Text(purchase.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let vendor = purchase.vendor {
                        Text("from \(vendor.name)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(purchase.quantity) \(purchase.item?.unit.abbreviation ?? "units")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DuplicateUsagesDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let usages: [Usage]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Warning Banner
                warningBanner

                // Usages Comparison
                VStack(alignment: .leading, spacing: 12) {
                    Label("Suspected Duplicates", systemImage: "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(.green)

                    ForEach(usages) { usage in
                        DuplicateUsageCard(usage: usage, onDelete: {
                            modelContext.delete(usage)
                        })
                    }
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .background(Color.primary.opacity(0.03))
    }

    private var warningBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.green)
                Text("Possible Duplicate Usage Records")
                    .font(.headline)
                Spacer()
            }

            Text("These usage records have the same item, date, and quantity. They may have been entered twice by mistake.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DuplicateUsageCard: View {
    let usage: Usage
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(usage.item?.name ?? "Unknown Item")
                        .font(.headline)
                    Text(usage.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if usage.isEstimate {
                        Text("Estimated")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("-\(usage.quantity) \(usage.item?.unit.abbreviation ?? "units")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            }

            if !usage.notes.isEmpty {
                Text(usage.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    DuplicatesView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
