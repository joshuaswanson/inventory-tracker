import SwiftUI
import SwiftData

struct VendorWindowView: View {
    @Environment(\.modelContext) private var modelContext
    let vendorID: UUID

    @Query private var vendors: [Vendor]

    init(vendorID: UUID) {
        self.vendorID = vendorID
        _vendors = Query(filter: #Predicate<Vendor> { vendor in
            vendor.id == vendorID
        })
    }

    var body: some View {
        Group {
            if let vendor = vendors.first {
                VendorDetailView(vendor: vendor)
            } else {
                ContentUnavailableView {
                    Label("Vendor Not Found", systemImage: "building.2")
                } description: {
                    Text("This vendor may have been deleted.")
                }
            }
        }
    }
}
