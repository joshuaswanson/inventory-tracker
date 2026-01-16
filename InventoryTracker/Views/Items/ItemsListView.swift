import SwiftUI
import SwiftData

struct ItemsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.name) private var items: [Item]

    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var showingOnlyLowStock = false
    @State private var selectedItem: Item?

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
        HSplitView {
            // Left: Item list
            VStack(spacing: 0) {
                // Search and filter bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search items", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Toggle(isOn: $showingOnlyLowStock) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .help("Show low stock only")

                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                    .help("Add item")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

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
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .listRowSeparator(.visible)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
            .background(Color.primary.opacity(0.02))

            // Right: Detail view
            if let item = selectedItem {
                ItemDetailView(item: item)
                    .frame(minWidth: 400)
            } else {
                ContentUnavailableView {
                    Label("No Item Selected", systemImage: "shippingbox")
                } description: {
                    Text("Select an item from the list to view details.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
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
