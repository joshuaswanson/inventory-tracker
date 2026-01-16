import SwiftUI
import SwiftData

struct VendorsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vendor.name) private var vendors: [Vendor]

    @State private var showingAddVendor = false
    @State private var searchText = ""

    var filteredVendors: [Vendor] {
        if searchText.isEmpty {
            return vendors
        }
        return vendors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredVendors.isEmpty {
                    ContentUnavailableView {
                        Label("No Vendors", systemImage: "building.2")
                    } description: {
                        Text("Add vendors to track where you purchase items.")
                    }
                } else {
                    ForEach(filteredVendors) { vendor in
                        NavigationLink(destination: VendorDetailView(vendor: vendor)) {
                            VendorRowView(vendor: vendor)
                        }
                    }
                    .onDelete(perform: deleteVendors)
                }
            }
            .navigationTitle("Vendors")
            .searchable(text: $searchText, prompt: "Search vendors")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddVendor = true }) {
                        Label("Add Vendor", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVendor) {
                AddVendorView()
            }
        }
    }

    private func deleteVendors(at offsets: IndexSet) {
        for index in offsets {
            let vendor = filteredVendors[index]
            modelContext.delete(vendor)
        }
    }
}

struct VendorRowView: View {
    let vendor: Vendor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vendor.name)
                .font(.headline)

            HStack {
                Text("\(vendor.totalPurchases) purchases")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if vendor.totalSpent > 0 {
                    Text("Total: \(vendor.totalSpent, format: .currency(code: "USD"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct VendorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vendor: Vendor

    @State private var showingEditVendor = false

    var body: some View {
        List {
            Section("Contact Information") {
                if !vendor.contactName.isEmpty {
                    LabeledContent("Contact", value: vendor.contactName)
                }

                if !vendor.phone.isEmpty {
                    LabeledContent("Phone") {
                        Link(vendor.phone, destination: URL(string: "tel:\(vendor.phone)")!)
                    }
                }

                if !vendor.email.isEmpty {
                    LabeledContent("Email") {
                        Link(vendor.email, destination: URL(string: "mailto:\(vendor.email)")!)
                    }
                }

                if !vendor.address.isEmpty {
                    LabeledContent("Address", value: vendor.address)
                }
            }

            Section("Purchase Summary") {
                LabeledContent("Total Purchases", value: "\(vendor.totalPurchases)")
                LabeledContent("Total Spent", value: vendor.totalSpent, format: .currency(code: "USD"))
            }

            Section("Purchase History") {
                if vendor.purchases.isEmpty {
                    Text("No purchases from this vendor yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vendor.purchases.sorted { $0.date > $1.date }, id: \.id) { purchase in
                        if let item = purchase.item {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                                        .fontWeight(.medium)
                                }
                                HStack {
                                    Text(purchase.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(purchase.quantity) \(item.unit.abbreviation)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            if !vendor.notes.isEmpty {
                Section("Notes") {
                    Text(vendor.notes)
                }
            }
        }
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
                }
            }
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
