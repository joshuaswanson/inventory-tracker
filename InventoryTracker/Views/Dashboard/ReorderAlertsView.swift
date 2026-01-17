import SwiftUI
import SwiftData

struct ReorderAlertsView: View {
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Reorder Alerts", systemImage: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(items.count) item(s)")
                    .font(.body)
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
                    .font(.body)
                    .fontWeight(.medium)

                HStack {
                    Text("Current: \(item.currentInventory) \(item.unit.abbreviation)")
                    Text("Reorder at: \(item.reorderLevel)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let days = item.estimatedDaysUntilReorder {
                    if days <= 0 {
                        Text("Order Now")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.red)
                            .clipShape(Capsule())
                    } else {
                        Text("\(days) days left")
                            .font(.subheadline)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                    }
                }

                if let lowestPrice = item.lowestPricePaid,
                   let vendor = item.lowestPricePurchase?.vendor {
                    Text("Best: \(lowestPrice, format: .currency(code: "USD")) @ \(vendor.name)")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ReorderAlertsView(items: [
        Item(name: "Sample Item", reorderLevel: 10)
    ])
    .padding()
}
