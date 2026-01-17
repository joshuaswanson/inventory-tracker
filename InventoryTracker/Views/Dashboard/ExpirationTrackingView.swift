import SwiftUI
import SwiftData

struct ExpirationTrackingView: View {
    let expiringItems: [(item: Item, purchase: Purchase, daysLeft: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Expiring Soon", systemImage: "clock.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                Spacer()
                Text("\(expiringItems.count) item(s)")
                    .font(.body)
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
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .font(.body)
                    .fontWeight(.medium)

                HStack {
                    if let expDate = purchase.expirationDate {
                        Text("Expires: \(expDate, style: .date)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !purchase.lotNumber.isEmpty {
                        Text("Lot: \(purchase.lotNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(purchase.remainingQuantity) \(item.unit.abbreviation) left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if daysLeft <= 0 {
                    Text("EXPIRED")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.red)
                        .clipShape(Capsule())
                } else {
                    Text("\(daysLeft) days")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(expirationColor)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ExpirationTrackingView(expiringItems: [])
        .padding()
}
