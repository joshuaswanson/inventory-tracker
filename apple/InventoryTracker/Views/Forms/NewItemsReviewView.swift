import SwiftData
import SwiftUI

/// Asks which freshly imported items can expire, and when.
struct NewItemsReviewView: View {
    let itemIDs: [String]
    var macHeight: CGFloat = 520
    let onDone: () -> Void

    @Query private var allItems: [Item]
    @Environment(\.modelContext) private var modelContext
    @State private var perishableIDs: Set<String> = []
    @State private var expirations: [String: String] = [:]

    private var items: [Item] {
        allItems.filter { itemIDs.contains($0.id) }
            .sorted { orderedText($0.name, $1.name, ascending: true) }
    }

    var body: some View {
        FormSheet(title: "New Items", saveTitle: "Continue", showsCancel: false, macHeight: macHeight, onSave: finish) {
            Text("Which of these new items have an expiration date? Tick each one that does, then enter the date printed on the box.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    CheckboxField(title: item.name, isOn: Binding(
                        get: { perishableIDs.contains(item.id) },
                        set: { isOn in
                            if isOn { perishableIDs.insert(item.id) } else { perishableIDs.remove(item.id) }
                        }
                    ))
                    if perishableIDs.contains(item.id) {
                        HStack(spacing: 8) {
                            Text("Expires")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                            OptionalDayField(day: Binding(get: { expirations[item.id] }, set: { expirations[item.id] = $0 }))
                        }
                        .padding(.leading, 26)
                        if expirations[item.id] == nil {
                            Text("Box not nearby? Leave the date empty for now. You can add it later by editing the purchase on the Purchases page.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 26)
                        }
                    }
                }
            }
        }
    }

    private func finish() {
        for item in items where perishableIDs.contains(item.id) {
            item.isPerishable = true
            guard let expiration = expirations[item.id] else { continue }
            for purchase in item.purchases ?? [] where purchase.expirationDate == nil {
                purchase.expirationDate = expiration
            }
        }
        try? modelContext.save()
        onDone()
    }
}
