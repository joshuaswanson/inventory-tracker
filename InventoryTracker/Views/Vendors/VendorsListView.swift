import SwiftUI
import SwiftData
import PhotosUI
#if os(macOS)
import AppKit
#endif

enum VendorSortOption: String, CaseIterable {
    case manual = "Manual"
    case alphabetical = "Alphabetical"
    case purchaseCount = "Purchase Count"
    case totalSpent = "Total Spent"
}

struct VendorsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(filter: #Predicate<Vendor> { !$0.isDeleted }, sort: \Vendor.sortOrder) private var vendors: [Vendor]
    @Query(filter: #Predicate<Item> { !$0.isDeleted }) private var items: [Item]

    @State private var showingAddVendor = false
    @State private var searchText = ""
    @State private var selectedVendors: Set<Vendor.ID> = []
    @State private var vendorToEdit: Vendor?
    @State private var sortOption: VendorSortOption = .manual

    var filteredVendors: [Vendor] {
        var result = vendors.map { $0 }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply sorting
        switch sortOption {
        case .manual:
            result.sort { $0.sortOrder < $1.sortOrder }
        case .alphabetical:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .purchaseCount:
            result.sort { $0.totalPurchases > $1.totalPurchases }
        case .totalSpent:
            result.sort { $0.totalSpent > $1.totalSpent }
        }

        return result
    }

    var pinnedVendors: [Vendor] {
        filteredVendors.filter { $0.isPinned }
    }

    var unpinnedVendors: [Vendor] {
        filteredVendors.filter { !$0.isPinned }
    }

    // Check if vendor offers the best price on any item
    func hasBestPriceOnAnyItem(_ vendor: Vendor) -> Bool {
        for item in items {
            if let bestPurchase = item.lowestPricePurchase,
               bestPurchase.vendor?.id == vendor.id {
                return true
            }
        }
        return false
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
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            showingAddVendor = true
                        } label: {
                            Label("Add Vendor", systemImage: "plus")
                        }
                    }
                } else {
                    List(selection: $selectedVendors) {
                        if pinnedVendors.isEmpty {
                            ForEach(unpinnedVendors) { vendor in
                                vendorRow(for: vendor)
                            }
                            .onMove(perform: moveVendors)
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
                                .onMove(perform: moveVendors)
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                    .animation(.default, value: pinnedVendors.map(\.id))
                    .animation(.default, value: unpinnedVendors.map(\.id))
                    .contextMenu {
                        Button {
                            showingAddVendor = true
                        } label: {
                            Label("Add Vendor", systemImage: "plus")
                        }
                    }
                }
            }
            .frame(width: 300)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search vendors")
            .toolbar {
                ToolbarItem(id: "add", placement: .primaryAction) {
                    Button(action: { showingAddVendor = true }) {
                        Label("Add Vendor", systemImage: "plus")
                    }
                    .help("Add vendor")
                }

                ToolbarItem(id: "filter", placement: .secondaryAction) {
                    Menu {
                        Menu("Sort By") {
                            ForEach(VendorSortOption.allCases, id: \.self) { option in
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
                        Label("Filter", systemImage: "line.3.horizontal.decrease")
                    }
                    .menuIndicator(.hidden)
                    .help("Filter and sort vendors")
                }

                if selectedVendors.count == 1, let vendorId = selectedVendors.first, let vendor = vendors.first(where: { $0.id == vendorId }) {
                    ToolbarItem(id: "edit", placement: .secondaryAction) {
                        Button("Edit") {
                            vendorToEdit = vendor
                        }
                        .help("Edit vendor")
                    }
                }

                if !selectedVendors.isEmpty {
                    ToolbarItem(id: "delete", placement: .secondaryAction) {
                        Button(role: .destructive) {
                            for vendorId in selectedVendors {
                                if let vendor = vendors.first(where: { $0.id == vendorId }) {
                                    vendor.isDeleted = true
                                    vendor.deletedAt = Date()
                                }
                            }
                            selectedVendors.removeAll()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .help("Delete selected vendors")
                    }
                }
            }

            Divider()

            // Right: Detail view
            Group {
                if selectedVendors.count == 1, let vendorId = selectedVendors.first, let vendor = vendors.first(where: { $0.id == vendorId }) {
                    VendorDetailView(vendor: vendor)
                } else if selectedVendors.count > 1 {
                    ContentUnavailableView {
                        Label("\(selectedVendors.count) Vendors Selected", systemImage: "building.2")
                    } description: {
                        Text("Press Delete to remove selected vendors.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("No Vendor Selected", systemImage: "building.2")
                    } description: {
                        Text("Select a vendor from the list to view details.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            showingAddVendor = true
                        } label: {
                            Label("Add Vendor", systemImage: "plus")
                        }
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
        VendorRowView(vendor: vendor, hasBestPrice: hasBestPriceOnAnyItem(vendor))
            .tag(vendor)
            .onDoubleClick {
                openWindow(value: VendorWindowID(id: vendor.id))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    vendor.isDeleted = true
                    vendor.deletedAt = Date()
                    selectedVendors.remove(vendor.id)
                } label: {
                    Image(systemName: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    vendor.isPinned.toggle()
                } label: {
                    Image(systemName: vendor.isPinned ? "pin.slash.fill" : "pin.fill")
                }
                .tint(.orange)
            }
            .contextMenu {
                let selectedVendorsList = vendors.filter { selectedVendors.contains($0.id) }
                let isMultiSelect = selectedVendors.contains(vendor.id) && selectedVendors.count > 1
                let vendorsToActOn = isMultiSelect ? selectedVendorsList : [vendor]

                Button {
                    for actVendor in vendorsToActOn {
                        openWindow(value: VendorWindowID(id: actVendor.id))
                    }
                } label: {
                    Label(isMultiSelect ? "Open in New Windows" : "Open in New Window", systemImage: "macwindow.badge.plus")
                }

                Button {
                    let shouldPin = vendorsToActOn.contains { !$0.isPinned }
                    for actVendor in vendorsToActOn {
                        actVendor.isPinned = shouldPin
                    }
                } label: {
                    let allPinned = vendorsToActOn.allSatisfy { $0.isPinned }
                    Label(allPinned ? (isMultiSelect ? "Unpin All" : "Unpin") : (isMultiSelect ? "Pin All" : "Pin"),
                          systemImage: allPinned ? "pin.slash" : "pin")
                }

                if !isMultiSelect {
                    Button {
                        selectedVendors = [vendor.id]
                        vendorToEdit = vendor
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    if !vendor.phone.isEmpty {
                        Button {
                            let cleanedPhone = vendor.phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                            if let url = URL(string: "tel:\(cleanedPhone)") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Call", systemImage: "phone")
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    for actVendor in vendorsToActOn {
                        actVendor.isDeleted = true
                        actVendor.deletedAt = Date()
                        selectedVendors.remove(actVendor.id)
                    }
                } label: {
                    Label(isMultiSelect ? "Delete All" : "Delete", systemImage: "trash")
                }
            }
    }

    private func moveVendors(from source: IndexSet, to destination: Int) {
        // Switch to manual sort if needed and adopt current order
        if sortOption != .manual {
            // First, set sortOrder based on current filtered order
            for (index, vendor) in unpinnedVendors.enumerated() {
                vendor.sortOrder = index
            }
            sortOption = .manual
        }

        // Now perform the move
        var reorderedVendors = unpinnedVendors
        reorderedVendors.move(fromOffsets: source, toOffset: destination)
        for (index, vendor) in reorderedVendors.enumerated() {
            vendor.sortOrder = index
        }
    }
}

struct VendorRowView: View {
    let vendor: Vendor
    var hasBestPrice: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = vendor.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(vendor.name)
                        .font(.headline)

                    if hasBestPrice {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

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
    @State private var showingCallConfirmation = false
    @FocusState private var isNotesFocused: Bool

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
        .contentShape(Rectangle())
        .onTapGesture {
            isNotesFocused = false
        }
        .background(Color.primary.opacity(0.03))
        .navigationTitle(vendor.name)
        .onAppear {
            // Prevent notes from auto-focusing - delay needed because system focus happens after onAppear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNotesFocused = false
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
                if let imageData = vendor.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

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
                        Button(PhoneFormatter.format(vendor.phone)) {
                            showingCallConfirmation = true
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                    .confirmationDialog("Call \(PhoneFormatter.format(vendor.phone))?", isPresented: $showingCallConfirmation) {
                        Button("Call") {
                            if let url = URL(string: "tel:\(PhoneFormatter.stripFormatting(vendor.phone))") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
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
                .focused($isNotesFocused)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { }
    }
}

// MARK: - Vendor Stat Card
struct VendorStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    HStack {
                        if let imageData, let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "building.2")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Select Photo", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.bordered)

                            if imageData != nil {
                                Button(role: .destructive) {
                                    imageData = nil
                                    selectedPhoto = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

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
                        .font(.body)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
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
                phone = PhoneFormatter.format(vendor.phone)
                email = vendor.email
                address = vendor.address
                notes = vendor.notes
                imageData = vendor.imageData
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
        vendor.phone = PhoneFormatter.stripFormatting(phone)
        vendor.email = email
        vendor.address = address
        vendor.notes = notes
        vendor.imageData = imageData
        dismiss()
    }
}

#Preview {
    VendorsListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
