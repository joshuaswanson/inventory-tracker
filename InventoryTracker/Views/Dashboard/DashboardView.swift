import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var items: [Item]
    @Query private var purchases: [Purchase]
    @Query private var vendors: [Vendor]

    var itemsNeedingReorder: [Item] {
        items.filter { $0.needsReorder }
    }

    var expiringItems: [(item: Item, purchase: Purchase, daysLeft: Int)] {
        InventoryCalculator.itemsExpiringWithin(days: 30, from: items)
    }

    var totalInventoryValue: Double {
        InventoryCalculator.totalInventoryValue(for: items)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCards

                    if !itemsNeedingReorder.isEmpty {
                        ReorderAlertsView(items: itemsNeedingReorder)
                    }

                    if !expiringItems.isEmpty {
                        ExpirationTrackingView(expiringItems: expiringItems)
                    }

                    PriceAnalyticsView(items: items)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .frame(minWidth: 300, minHeight: 400)
            .navigationTitle("Dashboard")
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 150, maximum: 300), spacing: 16)
        ], spacing: 16) {
            SummaryCard(
                title: "Total Items",
                value: "\(items.count)",
                icon: "shippingbox.fill",
                color: .blue
            )

            SummaryCard(
                title: "Low Stock",
                value: "\(itemsNeedingReorder.count)",
                icon: "exclamationmark.triangle.fill",
                color: itemsNeedingReorder.isEmpty ? .green : .orange
            )

            SummaryCard(
                title: "Expiring Soon",
                value: "\(expiringItems.count)",
                icon: "clock.fill",
                color: expiringItems.isEmpty ? .green : .red
            )

            SummaryCard(
                title: "Inventory Value",
                value: totalInventoryValue.formatted(.currency(code: "USD")),
                icon: "dollarsign.circle.fill",
                color: .green
            )
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
