import SwiftUI
import SwiftData

enum ItemSortOption: String, CaseIterable {
    case manual = "Manual"
    case alphabetical = "Alphabetical"
    case inventoryLevel = "Inventory Level"
    case reorderStatus = "Reorder Status"
}

struct ItemsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(filter: #Predicate<Item> { !$0.isDeleted }, sort: \Item.sortOrder) private var items: [Item]

    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var showingOnlyLowStock = false
    @State private var selectedItem: Item?
    @State private var itemToEdit: Item?
    @State private var sortOption: ItemSortOption = .manual

    var filteredItems: [Item] {
        var result = items

        if showingOnlyLowStock {
            result = result.filter { $0.needsReorder }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply sorting
        switch sortOption {
        case .manual:
            result.sort { $0.sortOrder < $1.sortOrder }
        case .alphabetical:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .inventoryLevel:
            result.sort { $0.currentInventory < $1.currentInventory }
        case .reorderStatus:
            result.sort { ($0.needsReorder ? 0 : 1) < ($1.needsReorder ? 0 : 1) }
        }

        return result
    }

    var pinnedItems: [Item] {
        filteredItems.filter { $0.isPinned }
    }

    var unpinnedItems: [Item] {
        filteredItems.filter { !$0.isPinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                // Left: Item list
                VStack(spacing: 0) {
                if filteredItems.isEmpty {
                    ContentUnavailableView {
                        Label("No Items", systemImage: "shippingbox")
                    } description: {
                        Text("Add items to start tracking your inventory.")
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(selection: $selectedItem) {
                        if pinnedItems.isEmpty {
                            ForEach(unpinnedItems) { item in
                                itemRow(for: item)
                            }
                            .onMove(perform: moveItems)
                        } else {
                            Section("Pinned") {
                                ForEach(pinnedItems) { item in
                                    itemRow(for: item)
                                }
                            }

                            Section("Items") {
                                ForEach(unpinnedItems) { item in
                                    itemRow(for: item)
                                }
                                .onMove(perform: moveItems)
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                    .animation(.default, value: pinnedItems.map(\.id))
                }
            }
            .frame(width: 300)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search items")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Toggle(isOn: $showingOnlyLowStock) {
                        Label("Low Stock", systemImage: "exclamationmark.triangle")
                    }
                    .help("Show low stock only")
                }

                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(ItemSortOption.allCases, id: \.self) { option in
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
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    .help("Sort items")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddItem = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                    .help("Add item")
                }
            }

            Divider()

            // Right: Detail view - always present to prevent snapping
            Group {
                if let item = selectedItem {
                    ItemDetailView(item: item)
                } else {
                    ContentUnavailableView {
                        Label("No Item Selected", systemImage: "shippingbox")
                    } description: {
                        Text("Select an item from the list to view details.")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .sheet(item: $itemToEdit) { item in
            EditItemView(item: item)
        }
        .navigationTitle("Items")
    }

    @ViewBuilder
    private func itemRow(for item: Item) -> some View {
        ItemRowView(item: item)
            .tag(item)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    item.isDeleted = true
                    item.deletedAt = Date()
                    if selectedItem == item {
                        selectedItem = nil
                    }
                } label: {
                    Image(systemName: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    item.isPinned.toggle()
                } label: {
                    Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                }
                .tint(.yellow)
            }
            .contextMenu {
                Button {
                    openWindow(value: item.id)
                } label: {
                    Label("Open in New Window", systemImage: "macwindow.badge.plus")
                }

                Button {
                    item.isPinned.toggle()
                } label: {
                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                }

                Button {
                    selectedItem = item
                    itemToEdit = item
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    item.isDeleted = true
                    item.deletedAt = Date()
                    if selectedItem == item {
                        selectedItem = nil
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .onTapGesture(count: 2) {
                openWindow(value: item.id)
            }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            modelContext.delete(item)
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        guard sortOption == .manual else { return }
        var reorderedItems = unpinnedItems
        reorderedItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reorderedItems.enumerated() {
            item.sortOrder = index
        }
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.headline)

                    if item.isPerishable {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }

                Text("\(item.currentInventory) \(item.unit.abbreviation) in stock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.needsReorder {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 12)
        .padding(.trailing, 4)
    }
}

#Preview {
    ItemsListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
