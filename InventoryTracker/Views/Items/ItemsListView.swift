import SwiftUI
import SwiftData

struct ItemsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.name) private var items: [Item]

    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var showingOnlyLowStock = false
    @State private var selectedItem: Item?
    @State private var navigationPath = NavigationPath()

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
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedItem) {
                if filteredItems.isEmpty {
                    ContentUnavailableView {
                        Label("No Items", systemImage: "shippingbox")
                    } description: {
                        Text("Add items to start tracking your inventory.")
                    }
                } else {
                    ForEach(filteredItems) { item in
                        ItemRowView(item: item)
                            .tag(item)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Items")
            .searchable(text: $searchText, prompt: "Search items")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddItem = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Toggle(isOn: $showingOnlyLowStock) {
                        Label("Low Stock Only", systemImage: "exclamationmark.triangle")
                    }
                }
            }
        } detail: {
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
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        #else
        NavigationStack(path: $navigationPath) {
            List {
                if filteredItems.isEmpty {
                    ContentUnavailableView {
                        Label("No Items", systemImage: "shippingbox")
                    } description: {
                        Text("Add items to start tracking your inventory.")
                    }
                } else {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item) {
                            ItemRowView(item: item)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Items")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .searchable(text: $searchText, prompt: "Search items")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddItem = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Toggle(isOn: $showingOnlyLowStock) {
                        Label("Low Stock Only", systemImage: "exclamationmark.triangle")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
        }
        #endif
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            modelContext.delete(item)
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
                        Image(systemName: "leaf")
                            .foregroundStyle(.green)
                            .font(.caption)
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
        .padding(.vertical, 4)
    }
}

#Preview {
    ItemsListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
