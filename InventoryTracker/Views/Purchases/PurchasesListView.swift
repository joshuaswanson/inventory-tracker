import SwiftUI
import SwiftData

struct PurchasesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]

    @State private var showingAddPurchase = false
    @State private var searchText = ""
    @State private var selectedItem: Item?

    var filteredPurchases: [Purchase] {
        var result = purchases

        if let item = selectedItem {
            result = result.filter { $0.item?.id == item.id }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.item?.name.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.vendor?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredPurchases.isEmpty {
                    ContentUnavailableView {
                        Label("No Purchases", systemImage: "cart")
                    } description: {
                        Text("Record purchases to track inventory and pricing.")
                    }
                } else {
                    ForEach(filteredPurchases) { purchase in
                        PurchaseRowView(purchase: purchase)
                    }
                    .onDelete(perform: deletePurchases)
                }
            }
            .navigationTitle("Purchases")
            .searchable(text: $searchText, prompt: "Search purchases")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPurchase = true }) {
                        Label("Add Purchase", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPurchase) {
                AddPurchaseView()
            }
        }
    }

    private func deletePurchases(at offsets: IndexSet) {
        for index in offsets {
            let purchase = filteredPurchases[index]
            modelContext.delete(purchase)
        }
    }
}

struct PurchaseRowView: View {
    let purchase: Purchase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let item = purchase.item {
                    Text(item.name)
                        .font(.headline)
                } else {
                    Text("Unknown Item")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                    .fontWeight(.semibold)
            }

            HStack {
                Text(purchase.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let vendor = purchase.vendor {
                    Text("from \(vendor.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let item = purchase.item {
                    Text("\(purchase.quantity) \(item.unit.abbreviation)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if purchase.isExpired {
                Label("Expired", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let days = purchase.daysUntilExpiration, days <= 30 {
                Label("Expires in \(days) days", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(days <= 7 ? .orange : .yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PurchasesListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
