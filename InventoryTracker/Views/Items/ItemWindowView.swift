import SwiftUI
import SwiftData

struct ItemWindowView: View {
    @Environment(\.modelContext) private var modelContext
    let itemID: UUID

    @Query private var items: [Item]

    init(itemID: UUID) {
        self.itemID = itemID
        _items = Query(filter: #Predicate<Item> { item in
            item.id == itemID
        })
    }

    var body: some View {
        Group {
            if let item = items.first {
                ItemDetailView(item: item)
            } else {
                ContentUnavailableView {
                    Label("Item Not Found", systemImage: "shippingbox")
                } description: {
                    Text("This item may have been deleted.")
                }
            }
        }
    }
}
