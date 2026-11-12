import Foundation
import SwiftData

@Model
final class Item {
    var id: String = UUID().uuidString.lowercased()
    var name: String = ""
    var unitRaw: String = UnitOfMeasure.each.rawValue
    var reorderLevel: Int = 10
    var isPerishable: Bool = false
    var storageLocation: String = ""
    var notes: String = ""
    var createdAt: String = ""
    /// Names this entry absorbed when duplicates were combined, one per line.
    var otherNamesText: String = ""
    /// What each absorbed duplicate looked like, kept so it can be separated again.
    var absorbedJSON: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Purchase.item)
    var purchases: [Purchase]? = []

    @Relationship(deleteRule: .cascade, inverse: \UsageRecord.item)
    var usageRecords: [UsageRecord]? = []

    init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        unit: UnitOfMeasure = .each,
        reorderLevel: Int = 10,
        isPerishable: Bool = false,
        storageLocation: String = "",
        notes: String = "",
        createdAt: String = Day.today
    ) {
        self.id = id
        self.name = name
        self.unitRaw = unit.rawValue
        self.reorderLevel = reorderLevel
        self.isPerishable = isPerishable
        self.storageLocation = storageLocation
        self.notes = notes
        self.createdAt = createdAt
    }

    var absorbed: [AbsorbedEntry] {
        get { AbsorbedEntry.decode(absorbedJSON) }
        set { absorbedJSON = AbsorbedEntry.encode(newValue) }
    }

    var otherNames: [String] {
        get { otherNamesText.split(separator: "\n").map(String.init) }
        set { otherNamesText = newValue.joined(separator: "\n") }
    }

    var unit: UnitOfMeasure {
        get { UnitOfMeasure(rawValue: unitRaw) ?? .each }
        set { unitRaw = newValue.rawValue }
    }

    var unitAbbreviation: String { unit.abbreviation }

    var usageFacts: [UsageFact] {
        (usageRecords ?? []).map {
            UsageFact(day: $0.date, quantity: $0.quantity, batchID: $0.batch?.id, isAdjustment: $0.isAdjustment)
        }
    }

    var purchaseFacts: [PurchaseFact] {
        (purchases ?? []).sorted { ($0.date, $0.id) < ($1.date, $1.id) }.map {
            PurchaseFact(
                id: $0.id,
                day: $0.date,
                quantity: $0.quantity,
                pricePerUnit: $0.pricePerUnit,
                expirationDate: $0.expirationDate,
                vendorName: $0.vendor?.name
            )
        }
    }

    func metrics(today: String = Day.today) -> ItemMetrics {
        ItemMetrics(
            reorderLevel: reorderLevel,
            isPerishable: isPerishable,
            purchases: purchaseFacts,
            usage: usageFacts,
            today: today
        )
    }
}
