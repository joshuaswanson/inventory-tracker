import SwiftData
import SwiftUI

private enum VendorFilter: String, CaseIterable, Hashable {
    case all, active, inactive

    var label: String {
        switch self {
        case .all: "All"
        case .active: "Active"
        case .inactive: "No Orders"
        }
    }

    func includes(_ vendor: Vendor) -> Bool {
        switch self {
        case .all: true
        case .active: vendor.orderCount > 0
        case .inactive: vendor.orderCount == 0
        }
    }
}

private enum VendorSortKey {
    case name, contact, phone, email, orders, spent
}

struct VendorEmailLink: View {
    let email: String

    var body: some View {
        if let url = URL(string: "mailto:\(email)") {
            Link(email, destination: url)
                .foregroundStyle(Theme.primary)
        } else {
            Text(email)
        }
    }
}

struct VendorsView: View {
    @Query private var vendors: [Vendor]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext
    @State private var search = ""
    @State private var filter = VendorFilter.all
    @State private var sort = SortState(key: VendorSortKey.name)

    var body: some View {
        let visible = visibleVendors

        Screen(title: "Vendors", searchPrompt: "Search vendors...", search: $search) {
            HeaderButton(title: "+ Add Vendor", compactImage: "plus") { router.sheet = .vendor(nil) }
        } content: {
            DuplicatesBanner(
                count: DuplicateDetector.vendorGroups(DuplicatesView.vendorCandidates(vendors), dismissed: DuplicateDetector.dismissed()).count,
                noun: "vendors"
            ) { router.sheet = .duplicates(.vendors) }
            FilterChips(
                options: VendorFilter.allCases.map { option in
                    FilterOption(value: option, label: option.label, count: vendors.filter(option.includes).count)
                },
                selection: $filter
            )
            if visible.isEmpty {
                let isFiltered = filter != .all || !search.isEmpty
                EmptyState(
                    title: isFiltered ? "No matching vendors" : "No vendors yet",
                    message: isFiltered ? "Try adjusting your filters or search." : "Add your dental suppliers to track purchases and spending."
                )
            } else if isWide {
                DataTable(rows: visible, columns: columns, sort: $sort) { vendor in
                    router.open(.vendor(vendor.id))
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visible) { compactRow($0) }
                }
            }
        }
    }

    private var visibleVendors: [Vendor] {
        let query = search.lowercased()
        return vendors
            .filter { vendor in
                query.isEmpty
                    || vendor.name.lowercased().contains(query)
                    || vendor.contactName.lowercased().contains(query)
                    || vendor.email.lowercased().contains(query)
            }
            .filter(filter.includes)
            .sorted(by: isOrdered)
    }

    private func isOrdered(_ first: Vendor, _ second: Vendor) -> Bool {
        let ascending = sort.ascending
        switch sort.key {
        case .name: return orderedText(first.name, second.name, ascending: ascending)
        case .contact: return orderedText(first.contactName, second.contactName, ascending: ascending)
        case .phone: return orderedText(first.phone, second.phone, ascending: ascending)
        case .email: return orderedText(first.email, second.email, ascending: ascending)
        case .orders: return ordered(first.orderCount, second.orderCount, ascending: ascending)
        case .spent: return ordered(first.totalSpent, second.totalSpent, ascending: ascending)
        }
    }

    private var columns: [DataColumn<Vendor, VendorSortKey>] {
        [
            DataColumn("Name", sortKey: .name, weight: 1.8) { vendor in
                Text(vendor.name).fontWeight(.medium)
            },
            DataColumn("Contact", sortKey: .contact, weight: 1.2) { vendor in
                Text(vendor.contactName.isEmpty ? Format.missing : vendor.contactName)
                    .foregroundStyle(Theme.textSecondary)
            },
            DataColumn("Phone", sortKey: .phone, weight: 1.2) { vendor in
                Text(vendor.phone.isEmpty ? Format.missing : Format.phone(vendor.phone))
                    .foregroundStyle(Theme.textSecondary)
            },
            DataColumn("Email", sortKey: .email, weight: 2) { vendor in
                if vendor.email.isEmpty {
                    Text(Format.missing).foregroundStyle(Theme.textSecondary)
                } else {
                    VendorEmailLink(email: vendor.email)
                }
            },
            DataColumn("Orders", sortKey: .orders, weight: 0.6) { vendor in
                Text("\(vendor.orderCount)")
            },
            DataColumn("Total Spent", sortKey: .spent, weight: 0.9, isNumeric: true) { vendor in
                Text(Format.currency(vendor.totalSpent))
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.green)
            },
            DataColumn("", weight: 0.7) { vendor in
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    RowIconButton(systemImage: "pencil", label: "Edit") { router.sheet = .vendor(vendor) }
                    RowIconButton(systemImage: "trash.fill", isDestructive: true, label: "Delete") { confirmDelete(vendor) }
                }
            },
        ]
    }

    private func compactRow(_ vendor: Vendor) -> some View {
        CompactRowCard {
            router.open(.vendor(vendor.id))
        } content: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                    Text(vendor.contactName.isEmpty ? "\(vendor.orderCount) orders" : "\(vendor.contactName), \(vendor.orderCount) orders")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Text(Format.currency(vendor.totalSpent))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.green)
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { router.sheet = .vendor(vendor) }
            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete(vendor) }
        }
    }

    private func confirmDelete(_ vendor: Vendor) {
        router.pendingDelete = PendingDelete(message: "Delete vendor \"\(vendor.name)\"?") {
            modelContext.delete(vendor)
            try? modelContext.save()
        }
    }
}
