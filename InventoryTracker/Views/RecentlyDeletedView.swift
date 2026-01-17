import SwiftUI
import SwiftData

enum DeletedSelection: Hashable {
    case item(Item)
    case vendor(Vendor)
}

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Item> { $0.isDeleted }, sort: \Item.deletedAt, order: .reverse) private var deletedItems: [Item]
    @Query(filter: #Predicate<Vendor> { $0.isDeleted }, sort: \Vendor.deletedAt, order: .reverse) private var deletedVendors: [Vendor]

    @State private var selection: DeletedSelection?

    var body: some View {
        Group {
            if deletedItems.isEmpty && deletedVendors.isEmpty {
                ContentUnavailableView {
                    Label("No Recently Deleted Items", systemImage: "trash")
                } description: {
                    Text("Items and vendors you delete will appear here for 30 days.")
                }
            } else {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 0) {
                        // Left: List of deleted items and vendors
                        List(selection: $selection) {
                            if !deletedItems.isEmpty {
                                Section("Items") {
                                    ForEach(deletedItems) { item in
                                        DeletedItemRow(item: item)
                                            .tag(DeletedSelection.item(item))
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) {
                                                    if case .item(let selectedItem) = selection, selectedItem == item {
                                                        selection = nil
                                                    }
                                                    modelContext.delete(item)
                                                } label: {
                                                    Image(systemName: "trash")
                                                }
                                            }
                                            .swipeActions(edge: .leading) {
                                                Button {
                                                    item.isDeleted = false
                                                    item.deletedAt = nil
                                                    if case .item(let selectedItem) = selection, selectedItem == item {
                                                        selection = nil
                                                    }
                                                } label: {
                                                    Image(systemName: "arrow.uturn.backward")
                                                }
                                                .tint(.green)
                                            }
                                            .contextMenu {
                                                Button {
                                                    item.isDeleted = false
                                                    item.deletedAt = nil
                                                    if case .item(let selectedItem) = selection, selectedItem == item {
                                                        selection = nil
                                                    }
                                                } label: {
                                                    Label("Recover", systemImage: "arrow.uturn.backward")
                                                }

                                                Divider()

                                                Button(role: .destructive) {
                                                    if case .item(let selectedItem) = selection, selectedItem == item {
                                                        selection = nil
                                                    }
                                                    modelContext.delete(item)
                                                } label: {
                                                    Label("Delete Permanently", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }

                            if !deletedVendors.isEmpty {
                                Section("Vendors") {
                                    ForEach(deletedVendors) { vendor in
                                        DeletedVendorRow(vendor: vendor)
                                            .tag(DeletedSelection.vendor(vendor))
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) {
                                                    if case .vendor(let selectedVendor) = selection, selectedVendor == vendor {
                                                        selection = nil
                                                    }
                                                    modelContext.delete(vendor)
                                                } label: {
                                                    Image(systemName: "trash")
                                                }
                                            }
                                            .swipeActions(edge: .leading) {
                                                Button {
                                                    vendor.isDeleted = false
                                                    vendor.deletedAt = nil
                                                    if case .vendor(let selectedVendor) = selection, selectedVendor == vendor {
                                                        selection = nil
                                                    }
                                                } label: {
                                                    Image(systemName: "arrow.uturn.backward")
                                                }
                                                .tint(.green)
                                            }
                                            .contextMenu {
                                                Button {
                                                    vendor.isDeleted = false
                                                    vendor.deletedAt = nil
                                                    if case .vendor(let selectedVendor) = selection, selectedVendor == vendor {
                                                        selection = nil
                                                    }
                                                } label: {
                                                    Label("Recover", systemImage: "arrow.uturn.backward")
                                                }

                                                Divider()

                                                Button(role: .destructive) {
                                                    if case .vendor(let selectedVendor) = selection, selectedVendor == vendor {
                                                        selection = nil
                                                    }
                                                    modelContext.delete(vendor)
                                                } label: {
                                                    Label("Delete Permanently", systemImage: "trash")
                                                }
                                            }
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
                            case .item(let item):
                                DeletedItemDetailView(item: item)
                            case .vendor(let vendor):
                                DeletedVendorDetailView(vendor: vendor)
                            case nil:
                                ContentUnavailableView {
                                    Label("No Selection", systemImage: "trash")
                                } description: {
                                    Text("Select a deleted item or vendor to view details.")
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !deletedItems.isEmpty || !deletedVendors.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        selection = nil
                        for item in deletedItems {
                            modelContext.delete(item)
                        }
                        for vendor in deletedVendors {
                            modelContext.delete(vendor)
                        }
                    } label: {
                        Label("Empty Trash", systemImage: "trash")
                    }
                }
            }
        }
    }
}

struct DeletedItemRow: View {
    let item: Item

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                if let deletedAt = item.deletedAt {
                    Text("Deleted \(deletedAt, style: .relative) ago")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}

struct DeletedVendorRow: View {
    let vendor: Vendor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.name)
                    .font(.headline)

                if let deletedAt = vendor.deletedAt {
                    Text("Deleted \(deletedAt, style: .relative) ago")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "building.2")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}

// MARK: - Deleted Item Detail View
struct DeletedItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let item: Item

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
                // Deletion Warning Banner
                deletionBanner(deletedAt: item.deletedAt)

                // Recovery Actions
                recoveryActions

                // Hero Card - Inventory Status
                heroCard

                // Stats Grid
                statsGrid

                // Pricing Card
                if item.lowestPricePaid != nil || item.averagePricePaid != nil {
                    pricingCard
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
    }

    private var recoveryActions: some View {
        HStack(spacing: 12) {
            Button {
                item.isDeleted = false
                item.deletedAt = nil
            } label: {
                Label("Recover Item", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("Delete Permanently", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack {
                if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

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

    private var recentPurchasesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Purchases", systemImage: "cart.fill")
                .font(.headline)
                .foregroundStyle(.purple)

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

    private var recentUsageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Usage", systemImage: "chart.line.downtrend.xyaxis")
                .font(.headline)
                .foregroundStyle(.blue)

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

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
            Text(item.notes)
                .font(.body)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Deleted Vendor Detail View
struct DeletedVendorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let vendor: Vendor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Deletion Warning Banner
                deletionBanner(deletedAt: vendor.deletedAt)

                // Recovery Actions
                recoveryActions

                // Hero Card - Summary
                heroCard

                // Stats Grid
                statsGrid

                // Contact Card
                if hasContactInfo {
                    contactCard
                }

                // Purchase History Card
                purchaseHistoryCard

                // Notes Card
                if !vendor.notes.isEmpty {
                    notesCard
                }
            }
            .padding()
        }
        .background(Color.primary.opacity(0.03))
    }

    private var recoveryActions: some View {
        HStack(spacing: 12) {
            Button {
                vendor.isDeleted = false
                vendor.deletedAt = nil
            } label: {
                Label("Recover Vendor", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button(role: .destructive) {
                modelContext.delete(vendor)
            } label: {
                Label("Delete Permanently", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var hasContactInfo: Bool {
        !vendor.contactName.isEmpty || !vendor.phone.isEmpty || !vendor.email.isEmpty || !vendor.address.isEmpty
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(vendor.totalSpent, format: .currency(code: "USD"))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                Spacer()
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 60, height: 60)
                        Image(systemName: "building.2.fill")
                            .font(.title)
                            .foregroundStyle(.purple)
                    }
                    Text("\(vendor.totalPurchases) orders")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statsGrid: some View {
        HStack(spacing: 16) {
            VendorStatCard(
                title: "Total Orders",
                value: "\(vendor.totalPurchases)",
                icon: "cart.fill",
                color: .blue
            )

            VendorStatCard(
                title: "Items Bought",
                value: "\(Set(vendor.purchases.compactMap { $0.item?.id }).count)",
                icon: "shippingbox.fill",
                color: .orange
            )

            VendorStatCard(
                title: "Avg. Order",
                value: vendor.totalPurchases > 0 ? (vendor.totalSpent / Double(vendor.totalPurchases)).formatted(.currency(code: "USD")) : "$0",
                icon: "chart.bar.fill",
                color: .indigo
            )
        }
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Contact Information", systemImage: "person.crop.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 10) {
                if !vendor.contactName.isEmpty {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(vendor.contactName)
                    }
                }

                if !vendor.phone.isEmpty {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(PhoneFormatter.format(vendor.phone))
                    }
                }

                if !vendor.email.isEmpty {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(vendor.email)
                    }
                }

                if !vendor.address.isEmpty {
                    HStack(alignment: .top) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(vendor.address)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var purchaseHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Purchase History", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(.purple)

            if vendor.purchases.isEmpty {
                Text("No purchases from this vendor yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(vendor.purchases.sorted { $0.date > $1.date }.prefix(5), id: \.id) { purchase in
                        if let item = purchase.item {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(purchase.date, style: .date)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
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
                            if purchase.id != vendor.purchases.sorted(by: { $0.date > $1.date }).prefix(5).last?.id {
                                Divider()
                            }
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

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
            Text(vendor.notes)
                .font(.body)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Deletion Banner Helper
private func deletionBanner(deletedAt: Date?) -> some View {
    VStack(spacing: 8) {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("This item is in the trash")
                .font(.headline)
            Spacer()
        }

        Text("Deleted items are kept for 30 days. After that, they will be permanently deleted.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

        if let deletedAt = deletedAt {
            let daysRemaining = max(0, 30 - Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day!)
            Text("\(daysRemaining) days remaining before permanent deletion")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(daysRemaining <= 7 ? .red : .orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding(16)
    .background(Color.orange.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

#Preview {
    RecentlyDeletedView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
