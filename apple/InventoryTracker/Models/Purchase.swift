import Foundation
import SwiftData

@Model
final class Purchase {
    var id: String = UUID().uuidString.lowercased()
    var date: String = ""
    var item: Item?
    var vendor: Vendor?
    var quantity: Int = 1
    var pricePerUnit: Double = 0
    var productNumber: String = ""
    var expirationDate: String?
    var notes: String = ""
    var sourceId: String?

    @Relationship(deleteRule: .nullify, inverse: \UsageRecord.batch)
    var usageRecords: [UsageRecord]? = []

    init(
        id: String = UUID().uuidString.lowercased(),
        date: String,
        item: Item?,
        vendor: Vendor? = nil,
        quantity: Int,
        pricePerUnit: Double,
        productNumber: String = "",
        expirationDate: String? = nil,
        notes: String = "",
        sourceId: String? = nil
    ) {
        self.id = id
        self.date = date
        self.item = item
        self.vendor = vendor
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.productNumber = productNumber
        self.expirationDate = expirationDate
        self.notes = notes
        self.sourceId = sourceId
    }

    var totalCost: Double { roundedToCents(Double(quantity) * pricePerUnit) }

    var unitsTaken: Int { (usageRecords ?? []).reduce(0) { $0 + $1.quantity } }
}
