import Foundation
import SwiftData

@Model
final class Vendor {
    var id: String = UUID().uuidString.lowercased()
    var name: String = ""
    var contactName: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var notes: String = ""
    var createdAt: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Purchase.vendor)
    var purchases: [Purchase]? = []

    init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        contactName: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
        notes: String = "",
        createdAt: String = Day.today
    ) {
        self.id = id
        self.name = name
        self.contactName = contactName
        self.phone = phone
        self.email = email
        self.address = address
        self.notes = notes
        self.createdAt = createdAt
    }

    var orderCount: Int { purchases?.count ?? 0 }

    var totalSpent: Double {
        roundedToCents((purchases ?? []).reduce(0) { $0 + $1.totalCost })
    }
}
