import SwiftUI
import SwiftData

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Item> { $0.isDeleted }, sort: \Item.deletedAt, order: .reverse) private var deletedItems: [Item]
    @Query(filter: #Predicate<Vendor> { $0.isDeleted }, sort: \Vendor.deletedAt, order: .reverse) private var deletedVendors: [Vendor]

    var body: some View {
        Group {
            if deletedItems.isEmpty && deletedVendors.isEmpty {
                ContentUnavailableView {
                    Label("No Recently Deleted Items", systemImage: "trash")
                } description: {
                    Text("Items and vendors you delete will appear here for 30 days.")
                }
            } else {
                List {
                    if !deletedItems.isEmpty {
                        Section("Items") {
                            ForEach(deletedItems) { item in
                                DeletedItemRow(item: item)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            modelContext.delete(item)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            item.isDeleted = false
                                            item.deletedAt = nil
                                        } label: {
                                            Image(systemName: "arrow.uturn.backward")
                                        }
                                        .tint(.green)
                                    }
                                    .contextMenu {
                                        Button {
                                            item.isDeleted = false
                                            item.deletedAt = nil
                                        } label: {
                                            Label("Recover", systemImage: "arrow.uturn.backward")
                                        }

                                        Divider()

                                        Button(role: .destructive) {
                                            modelContext.delete(item)
                                        } label: {
                                            Label("Delete Permanently", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }

                    if !deletedVendors.isEmpty {
                        Section("Vendors") {
                            ForEach(deletedVendors) { vendor in
                                DeletedVendorRow(vendor: vendor)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            modelContext.delete(vendor)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            vendor.isDeleted = false
                                            vendor.deletedAt = nil
                                        } label: {
                                            Image(systemName: "arrow.uturn.backward")
                                        }
                                        .tint(.green)
                                    }
                                    .contextMenu {
                                        Button {
                                            vendor.isDeleted = false
                                            vendor.deletedAt = nil
                                        } label: {
                                            Label("Recover", systemImage: "arrow.uturn.backward")
                                        }

                                        Divider()

                                        Button(role: .destructive) {
                                            modelContext.delete(vendor)
                                        } label: {
                                            Label("Delete Permanently", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !deletedItems.isEmpty || !deletedVendors.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        for item in deletedItems {
                            modelContext.delete(item)
                        }
                        for vendor in deletedVendors {
                            modelContext.delete(vendor)
                        }
                    } label: {
                        Label("Empty Trash", systemImage: "trash")
                    }
                }
            }
        }
    }
}

struct DeletedItemRow: View {
    let item: Item

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                if let deletedAt = item.deletedAt {
                    Text("Deleted \(deletedAt, style: .relative) ago")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct DeletedVendorRow: View {
    let vendor: Vendor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.name)
                    .font(.headline)

                if let deletedAt = vendor.deletedAt {
                    Text("Deleted \(deletedAt, style: .relative) ago")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "building.2")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RecentlyDeletedView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
