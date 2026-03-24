import SwiftUI
import SwiftData

struct ItemsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Item> { !$0.isDeleted }, sort: \Item.name) private var items: [Item]

    @State private var selectedItemID: Item.ID?
    @State private var showingAddItem = false
    @State private var itemToEdit: Item?
    @State private var searchText = ""
    @State private var showLowStockOnly = false

    private var filteredItems: [Item] {
        var result = items
        if showLowStockOnly {
            result = result.filter { $0.needsReorder }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Table
                VStack(spacing: 0) {
                    Table(filteredItems, selection: $selectedItemID) {
                        TableColumn("Item") { item in
                            HStack(spacing: 6) {
                                if item.needsReorder {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                                Text(item.name)
                                    .lineLimit(1)
                            }
                        }
                        .width(min: 120, ideal: 180)

                        TableColumn("Stock") { item in
                            Text("\(item.currentInventory)")
                                .foregroundStyle(item.needsReorder ? .orange : .primary)
                                .fontWeight(item.needsReorder ? .semibold : .regular)
                        }
                        .width(50)

                        TableColumn("Unit") { item in
                            Text(item.unit.abbreviation)
                                .foregroundStyle(.secondary)
                        }
                        .width(40)

                        TableColumn("Reorder At") { item in
                            Text("\(item.reorderLevel)")
                                .foregroundStyle(.secondary)
                        }
                        .width(70)

                        TableColumn("Location") { item in
                            Text(item.storageLocation.isEmpty ? "-" : item.storageLocation)
                                .foregroundStyle(item.storageLocation.isEmpty ? .tertiary : .secondary)
                                .lineLimit(1)
                        }
                        .width(min: 80, ideal: 120)

                        TableColumn("Best Price") { item in
                            if let price = item.lowestPricePaid {
                                Text(price, format: .currency(code: "USD"))
                                    .foregroundStyle(.green)
                            } else {
                                Text("-")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .width(75)
                    }
                    .contextMenu(forSelectionType: Item.ID.self) { ids in
                        if let id = ids.first, let item = items.first(where: { $0.id == id }) {
                            Button("Edit") { itemToEdit = item }
                            Divider()
                            Button("Delete", role: .destructive) {
                                item.isDeleted = true
                                item.deletedAt = Date()
                                if selectedItemID == id { selectedItemID = nil }
                            }
                        }
                    }
                }
                .frame(minWidth: 350)

                Divider()

                // Detail
                Group {
                    if let id = selectedItemID, let item = items.first(where: { $0.id == id }) {
                        ItemDetailView(item: item)
                    } else {
                        ContentUnavailableView {
                            Label("No Item Selected", systemImage: "shippingbox")
                        } description: {
                            Text("Select an item from the table to view details.")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .searchable(text: $searchText, prompt: "Search items")
        .navigationTitle("Items")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddItem = true }) {
                    Label("Add Item", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Toggle(isOn: $showLowStockOnly) {
                    Label("Low Stock", systemImage: "exclamationmark.triangle")
                }
                .help("Show only items below reorder level")
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .sheet(item: $itemToEdit) { item in
            EditItemView(item: item)
        }
    }
}

#Preview {
    ItemsListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
