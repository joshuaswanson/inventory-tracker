import SwiftData
import SwiftUI

struct VendorDetailView: View {
    private static let recentLimit = 5

    @Query private var matches: [Vendor]
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var isWide

    init(vendorID: String) {
        _matches = Query(filter: #Predicate<Vendor> { $0.id == vendorID })
    }

    var body: some View {
        if let vendor = matches.first {
            detail(vendor)
        }
    }

    private func detail(_ vendor: Vendor) -> some View {
        DetailScreen(title: vendor.name) {
            if isWide {
                Button("Edit") { router.sheet = .vendor(vendor) }
                    .buttonStyle(.themedSecondary)
                Button("Combine Duplicates") { router.sheet = .combineVendor(vendor) }
                    .buttonStyle(.themedSecondary)
            } else {
                Menu {
                    Button("Edit", systemImage: "pencil") { router.sheet = .vendor(vendor) }
                    Button("Combine Duplicates", systemImage: "arrow.triangle.merge") { router.sheet = .combineVendor(vendor) }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        } content: {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isWide ? 180 : 150), spacing: 16)], spacing: 16) {
                StatCard(label: "Total Orders", value: "\(vendor.orderCount)")
                StatCard(label: "Total Spent", value: Format.currency(vendor.totalSpent), valueColor: Theme.green)
            }
            .padding(.bottom, 24)

            let sections = infoSections(vendor)
            if isWide {
                HStack(alignment: .top, spacing: 16) { sections }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
            } else {
                VStack(spacing: 16) { sections }
                    .padding(.bottom, 16)
            }

            if !vendor.notes.isEmpty {
                DetailSection(title: "Notes") {
                    Text(vendor.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func infoSections(_ vendor: Vendor) -> some View {
        DetailSection(title: "Contact Info") {
            let hasContact = !vendor.contactName.isEmpty || !vendor.phone.isEmpty || !vendor.email.isEmpty || !vendor.address.isEmpty
            if hasContact {
                VStack(spacing: 0) {
                    if !vendor.contactName.isEmpty {
                        InfoRow("Contact", value: vendor.contactName)
                    }
                    if !vendor.phone.isEmpty {
                        InfoRow(label: "Phone") { phoneValue(vendor.phone) }
                    }
                    if !vendor.email.isEmpty {
                        InfoRow(label: "Email") { VendorEmailLink(email: vendor.email) }
                    }
                    if !vendor.address.isEmpty {
                        InfoRow("Address", value: vendor.address, showsDivider: false)
                    }
                }
            } else {
                PlaceholderText("No contact info.")
            }
        }

        DetailSection(title: "Recent Purchases") {
            let purchases = Array((vendor.purchases ?? []).sorted { $0.date > $1.date }.prefix(Self.recentLimit))
            if purchases.isEmpty {
                PlaceholderText("No purchases from this vendor yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(purchases) { purchase in
                        MiniRow(showsDivider: purchase.id != purchases.last?.id) {
                            Text(Format.shortDate(purchase.date)).frame(width: 56, alignment: .leading)
                            Text(purchase.item?.name ?? "Unknown")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Format.currency(purchase.totalCost)).fontWeight(.medium)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func phoneValue(_ phone: String) -> some View {
        if let url = URL(string: "tel:\(Format.digits(phone))") {
            Link(Format.phone(phone), destination: url)
                .foregroundStyle(Theme.primary)
        } else {
            Text(Format.phone(phone))
        }
    }
}
