import Foundation
import SwiftData

@Model
final class Usage {
    var id: UUID
    var date: Date
    var quantity: Int
    var notes: String
    var isEstimate: Bool

    var item: Item?

    init(
        item: Item,
        date: Date = Date(),
        quantity: Int,
        notes: String = "",
        isEstimate: Bool = true
    ) {
        self.id = UUID()
        self.item = item
        self.date = date
        self.quantity = quantity
        self.notes = notes
        self.isEstimate = isEstimate
    }
}
