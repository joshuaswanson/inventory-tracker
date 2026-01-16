import SwiftUI
import SwiftData

struct ExpirationTrackingView: View {
    let expiringItems: [(item: Item, purchase: Purchase, daysLeft: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Expiring Soon", systemImage: "clock.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Spacer()
                Text("\(expiringItems.count) item(s)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(expiringItems, id: \.purchase.id) { expiring in
                    ExpirationRow(
                        item: expiring.item,
                        purchase: expiring.purchase,
                        daysLeft: expiring.daysLeft
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ExpirationRow: View {
    let item: Item
    let purchase: Purchase
    let daysLeft: Int

    var expirationColor: Color {
        if daysLeft <= 0 { return .red }
        if daysLeft <= 7 { return .orange }
        return .yellow
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    if let expDate = purchase.expirationDate {
                        Text("Expires: \(expDate, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !purchase.lotNumber.isEmpty {
                        Text("Lot: \(purchase.lotNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(purchase.remainingQuantity) \(item.unit.abbreviation) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if daysLeft <= 0 {
                    Text("EXPIRED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.red)
                        .clipShape(Capsule())
                } else {
                    Text("\(daysLeft) days")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(expirationColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let item = Item(name: "Sample Perishable", isPerishable: true)
    return ExpirationTrackingView(expiringItems: [])
        .padding()
}
