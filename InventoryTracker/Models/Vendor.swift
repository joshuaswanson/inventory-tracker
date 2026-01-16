import Foundation
import SwiftData

@Model
final class Vendor {
    var id: UUID
    var name: String
    var contactName: String
    var phone: String
    var email: String
    var address: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Purchase.vendor)
    var purchases: [Purchase] = []

    init(
        name: String,
        contactName: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.contactName = contactName
        self.phone = phone
        self.email = email
        self.address = address
        self.notes = notes
        self.createdAt = Date()
    }

    var totalPurchases: Int {
        purchases.count
    }

    var totalSpent: Double {
        purchases.reduce(0.0) { $0 + $1.totalCost }
    }

    func lowestPriceForItem(_ item: Item) -> Double? {
        purchases
            .filter { $0.item?.id == item.id }
            .map { $0.pricePerUnit }
            .min()
    }

    func purchasesForItem(_ item: Item) -> [Purchase] {
        purchases.filter { $0.item?.id == item.id }
    }
}
