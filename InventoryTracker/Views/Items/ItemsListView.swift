import SwiftUI
import SwiftData

struct ItemsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.sortOrder) private var items: [Item]

    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var showingOnlyLowStock = false
    @State private var selectedItem: Item?
    @State private var itemToEdit: Item?

    var filteredItems: [Item] {
        var result = items

        if showingOnlyLowStock {
            result = result.filter { $0.needsReorder }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var body: some View {
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
                        ForEach(filteredItems) { item in
                            ItemRowView(item: item)
                                .tag(item)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(item)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        selectedItem = item
                                        itemToEdit = item
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        modelContext.delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onMove(perform: moveItems)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: false))
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
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .sheet(item: $itemToEdit) { item in
            EditItemView(item: item)
        }
        .navigationTitle("Items")
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            modelContext.delete(item)
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var reorderedItems = filteredItems
        reorderedItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reorderedItems.enumerated() {
            item.sortOrder = index
        }
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack {
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
