import SwiftUI
import SwiftData

struct PriceAnalyticsView: View {
    let items: [Item]

    var itemsWithPricing: [Item] {
        items.filter { $0.lowestPricePaid != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Best Prices by Item", systemImage: "dollarsign.circle.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                Spacer()
            }

            if itemsWithPricing.isEmpty {
                Text("No purchase history yet. Add purchases to see price analytics.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(itemsWithPricing.prefix(5)) { item in
                        PriceAnalyticsRow(item: item)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PriceAnalyticsRow: View {
    let item: Item

    var vendorPrices: [(vendor: Vendor, price: Double)] {
        InventoryCalculator.lowestPriceByVendor(for: item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                if let lowest = item.lowestPricePaid {
                    Text(lowest, format: .currency(code: "USD"))
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }

            if !vendorPrices.isEmpty {
                HStack(spacing: 12) {
                    ForEach(vendorPrices.prefix(3), id: \.vendor.id) { vp in
                        HStack(spacing: 4) {
                            if vp.price == item.lowestPricePaid {
                                Image(systemName: "star.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.yellow)
                            }
                            Text("\(vp.vendor.name): \(vp.price, format: .currency(code: "USD"))")
                                .font(.subheadline)
                                .foregroundStyle(vp.price == item.lowestPricePaid ? .green : .secondary)
                        }
                    }
                }
            }

            if let avg = item.averagePricePaid {
                Text("Average: \(avg, format: .currency(code: "USD"))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    PriceAnalyticsView(items: [
        Item(name: "Sample Item")
    ])
    .padding()
}
