import SwiftUI
import SwiftData

struct VendorsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Vendor.name) private var vendors: [Vendor]

    @State private var showingAddVendor = false
    @State private var searchText = ""
    @State private var selectedVendor: Vendor?
    @State private var vendorToEdit: Vendor?

    var filteredVendors: [Vendor] {
        if searchText.isEmpty {
            return Array(vendors)
        } else {
            return vendors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var pinnedVendors: [Vendor] {
        filteredVendors.filter { $0.isPinned }
    }

    var unpinnedVendors: [Vendor] {
        filteredVendors.filter { !$0.isPinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                // Left: Vendor list
                VStack(spacing: 0) {
                if filteredVendors.isEmpty {
                    ContentUnavailableView {
                        Label("No Vendors", systemImage: "building.2")
                    } description: {
                        Text("Add vendors to track where you purchase items.")
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(selection: $selectedVendor) {
                        if pinnedVendors.isEmpty {
                            ForEach(unpinnedVendors) { vendor in
                                vendorRow(for: vendor)
                            }
                        } else {
                            Section("Pinned") {
                                ForEach(pinnedVendors) { vendor in
                                    vendorRow(for: vendor)
                                }
                            }

                            Section("Vendors") {
                                ForEach(unpinnedVendors) { vendor in
                                    vendorRow(for: vendor)
                                }
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                    .animation(.default, value: pinnedVendors.map(\.id))
                }
            }
            .frame(width: 300)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search vendors")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddVendor = true }) {
                        Label("Add Vendor", systemImage: "plus")
                    }
                }
            }

            Divider()

            // Right: Detail view
            Group {
                if let vendor = selectedVendor {
                    VendorDetailView(vendor: vendor)
                } else {
                    ContentUnavailableView {
                        Label("No Vendor Selected", systemImage: "building.2")
                    } description: {
                        Text("Select a vendor from the list to view details.")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddVendor) {
            AddVendorView()
        }
        .sheet(item: $vendorToEdit) { vendor in
            EditVendorView(vendor: vendor)
        }
        .navigationTitle("Vendors")
    }

    @ViewBuilder
    private func vendorRow(for vendor: Vendor) -> some View {
        VendorRowView(vendor: vendor)
            .tag(vendor)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    modelContext.delete(vendor)
                } label: {
                    Image(systemName: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    vendor.isPinned.toggle()
                } label: {
                    Image(systemName: vendor.isPinned ? "pin.slash.fill" : "pin.fill")
                }
                .tint(.yellow)
            }
            .contextMenu {
                Button {
                    openWindow(value: vendor.id)
                } label: {
                    Label("Open in New Window", systemImage: "macwindow.badge.plus")
                }

                Button {
                    vendor.isPinned.toggle()
                } label: {
                    Label(vendor.isPinned ? "Unpin" : "Pin", systemImage: vendor.isPinned ? "pin.slash" : "pin")
                }

                Button {
                    selectedVendor = vendor
                    vendorToEdit = vendor
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    modelContext.delete(vendor)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

struct VendorRowView: View {
    let vendor: Vendor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.name)
                    .font(.headline)

                Text("\(vendor.totalPurchases) purchases")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if vendor.totalSpent > 0 {
                Text(vendor.totalSpent, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 12)
        .padding(.trailing, 4)
    }
}

struct VendorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vendor: Vendor

    @State private var showingEditVendor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
                notesCard
            }
            .padding()
        }
        .background(Color.primary.opacity(0.03))
        .navigationTitle(vendor.name)
        .toolbar {
            Button("Edit") {
                showingEditVendor = true
            }
        }
        .sheet(isPresented: $showingEditVendor) {
            EditVendorView(vendor: vendor)
        }
    }

    private var hasContactInfo: Bool {
        !vendor.contactName.isEmpty || !vendor.phone.isEmpty || !vendor.email.isEmpty || !vendor.address.isEmpty
    }

    // MARK: - Hero Card
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

    // MARK: - Stats Grid
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

    // MARK: - Contact Card
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
                        Link(vendor.phone, destination: URL(string: "tel:\(vendor.phone)")!)
                    }
                }

                if !vendor.email.isEmpty {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Link(vendor.email, destination: URL(string: "mailto:\(vendor.email)")!)
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

    // MARK: - Purchase History Card
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

    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
            TextEditor(text: $vendor.notes)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Vendor Stat Card
struct VendorStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

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

struct EditVendorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vendor: Vendor

    @State private var name = ""
    @State private var contactName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Vendor Details") {
                    TextField("Vendor Name", text: $name)
                    TextField("Contact Name", text: $contactName)
                }

                Section("Contact Information") {
                    TextField("Phone", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Address", text: $address)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
            }
            .formStyle(.grouped)
                        .navigationTitle("Edit Vendor")
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
                name = vendor.name
                contactName = vendor.contactName
                phone = vendor.phone
                email = vendor.email
                address = vendor.address
                notes = vendor.notes
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        .padding()
        #endif
    }

    private func saveChanges() {
        vendor.name = name
        vendor.contactName = contactName
        vendor.phone = phone
        vendor.email = email
        vendor.address = address
        vendor.notes = notes
        dismiss()
    }
}

#Preview {
    VendorsListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
