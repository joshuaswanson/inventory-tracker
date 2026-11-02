import Foundation
import SwiftData

@Model
final class UsageRecord {
    var id: String = UUID().uuidString.lowercased()
    var date: String = ""
    var item: Item?
    var batch: Purchase?
    var quantity: Int = 1
    var notes: String = ""
    var isEstimate: Bool = false
    var isAdjustment: Bool = false

    init(
        id: String = UUID().uuidString.lowercased(),
        date: String,
        item: Item?,
        quantity: Int,
        notes: String = "",
        isEstimate: Bool = false
    ) {
        self.id = id
        self.date = date
        self.item = item
        self.quantity = quantity
        self.notes = notes
        self.isEstimate = isEstimate
    }

    var unitAbbreviation: String { item?.unitAbbreviation ?? UnitOfMeasure.each.abbreviation }

    var quantityText: String {
        let sign = quantity < 0 ? "+" : "-"
        return "\(sign)\(abs(quantity)) \(unitAbbreviation)"
    }
}
