import SwiftUI
import SwiftData
import PhotosUI
#if os(macOS)
import AppKit
#endif

struct VendorsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Vendor> { !$0.isDeleted }, sort: \Vendor.name) private var vendors: [Vendor]

    @State private var showingAddVendor = false
    @State private var vendorToEdit: Vendor?
    @State private var selectedVendorID: Vendor.ID?
    @State private var searchText = ""

    private var filteredVendors: [Vendor] {
        guard !searchText.isEmpty else { return vendors }
        return vendors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Table
                Table(filteredVendors, selection: $selectedVendorID) {
                    TableColumn("Name") { vendor in
                        Text(vendor.name)
                            .lineLimit(1)
                    }
                    .width(min: 100, ideal: 150)

                    TableColumn("Contact") { vendor in
                        Text(vendor.contactName.isEmpty ? "-" : vendor.contactName)
                            .foregroundStyle(vendor.contactName.isEmpty ? .tertiary : .primary)
                            .lineLimit(1)
                    }
                    .width(min: 80, ideal: 120)

                    TableColumn("Phone") { vendor in
                        Text(vendor.phone.isEmpty ? "-" : PhoneFormatter.format(vendor.phone))
                            .foregroundStyle(vendor.phone.isEmpty ? .tertiary : .primary)
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("Email") { vendor in
                        Text(vendor.email.isEmpty ? "-" : vendor.email)
                            .foregroundStyle(vendor.email.isEmpty ? .tertiary : .primary)
                            .lineLimit(1)
                    }
                    .width(min: 100, ideal: 150)

                    TableColumn("Orders") { vendor in
                        Text("\(vendor.totalPurchases)")
                            .foregroundStyle(.secondary)
                    }
                    .width(50)

                    TableColumn("Total Spent") { vendor in
                        Text(vendor.totalSpent, format: .currency(code: "USD"))
                            .foregroundStyle(.green)
                    }
                    .width(90)
                }
                .contextMenu(forSelectionType: Vendor.ID.self) { ids in
                    if let id = ids.first, let vendor = vendors.first(where: { $0.id == id }) {
                        Button("Edit") { vendorToEdit = vendor }
                        if !vendor.phone.isEmpty {
                            Button("Call") {
                                let cleaned = vendor.phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                                if let url = URL(string: "tel:\(cleaned)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                        if !vendor.email.isEmpty {
                            Button("Email") {
                                if let url = URL(string: "mailto:\(vendor.email)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            vendor.isDeleted = true
                            vendor.deletedAt = Date()
                            if selectedVendorID == id { selectedVendorID = nil }
                        }
                    }
                }
                .frame(minWidth: 350)

                Divider()

                // Detail
                Group {
                    if let id = selectedVendorID, let vendor = vendors.first(where: { $0.id == id }) {
                        VendorDetailView(vendor: vendor)
                    } else {
                        ContentUnavailableView {
                            Label("No Vendor Selected", systemImage: "building.2")
                        } description: {
                            Text("Select a vendor from the table to view details.")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .searchable(text: $searchText, prompt: "Search vendors")
        .navigationTitle("Vendors")
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
        .sheet(item: $vendorToEdit) { vendor in
            EditVendorView(vendor: vendor)
        }
    }
}

// MARK: - Vendor Detail View
struct VendorDetailView: View {
    @Bindable var vendor: Vendor
    @FocusState private var isNotesFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Contact info
                if !vendor.contactName.isEmpty || !vendor.phone.isEmpty || !vendor.email.isEmpty || !vendor.address.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Contact", systemImage: "person.crop.circle.fill")
                            .font(.headline)

                        if !vendor.contactName.isEmpty {
                            LabeledContent("Contact", value: vendor.contactName)
                        }
                        if !vendor.phone.isEmpty {
                            LabeledContent("Phone", value: PhoneFormatter.format(vendor.phone))
                        }
                        if !vendor.email.isEmpty {
                            LabeledContent("Email", value: vendor.email)
                        }
                        if !vendor.address.isEmpty {
                            LabeledContent("Address", value: vendor.address)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Stats
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Orders")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(vendor.totalPurchases)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(vendor.totalSpent, format: .currency(code: "USD"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Recent purchases
                VStack(alignment: .leading, spacing: 8) {
                    Label("Recent Purchases", systemImage: "clock.fill")
                        .font(.headline)

                    if vendor.purchases.isEmpty {
                        Text("No purchases yet")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        let recent = Array(vendor.purchases.sorted { $0.date > $1.date }.prefix(5))
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, purchase in
                            HStack {
                                Text(purchase.item?.name ?? "Unknown")
                                    .lineLimit(1)
                                Spacer()
                                Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                                    .foregroundStyle(.secondary)
                                Text(purchase.date, format: .dateTime.month(.abbreviated).day())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 55, alignment: .trailing)
                            }
                            .font(.subheadline)
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

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Label("Notes", systemImage: "note.text")
                        .font(.headline)
                    TextEditor(text: $vendor.notes)
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
            .padding()
        }
        .background(Color.primary.opacity(0.03))
        .navigationTitle(vendor.name)
    }
}

// MARK: - Edit Vendor View
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
                        .onChange(of: phone) { _, newValue in
                            let formatted = PhoneFormatter.format(newValue)
                            if formatted != newValue {
                                phone = formatted
                            }
                        }
                    TextField("Email", text: $email)
                    TextField("Address", text: $address)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Vendor")
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
                name = vendor.name
                contactName = vendor.contactName
                phone = PhoneFormatter.format(vendor.phone)
                email = vendor.email
                address = vendor.address
                notes = vendor.notes
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }

    private func saveChanges() {
        vendor.name = name
        vendor.contactName = contactName
        vendor.phone = PhoneFormatter.stripFormatting(phone)
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
