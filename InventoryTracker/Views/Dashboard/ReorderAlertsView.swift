import SwiftUI
import SwiftData

struct ReorderAlertsView: View {
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Reorder Alerts", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(items.count) item(s)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    ReorderAlertRow(item: item)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ReorderAlertRow: View {
    let item: Item

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text("Current: \(item.currentInventory) \(item.unit.abbreviation)")
                    Text("Reorder at: \(item.reorderLevel)")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let days = item.estimatedDaysUntilReorder {
                    if days <= 0 {
                        Text("Order Now")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red)
                            .clipShape(Capsule())
                    } else {
                        Text("\(days) days left")
                            .font(.footnote)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                    }
                }

                if let lowestPrice = item.lowestPricePaid,
                   let vendor = item.lowestPricePurchase?.vendor {
                    Text("Best: \(lowestPrice, format: .currency(code: "USD")) @ \(vendor.name)")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ReorderAlertsView(items: [
        Item(name: "Sample Item", reorderLevel: 10)
    ])
    .padding()
}
