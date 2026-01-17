import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID
    var name: String
    var unitOfMeasure: String
    var reorderLevel: Int
    var isPerishable: Bool
    var notes: String
    var createdAt: Date
    var sortOrder: Int = 0
    var isPinned: Bool = false
    var isDeleted: Bool = false
    var deletedAt: Date?
    @Attribute(.externalStorage) var imageData: Data?

    @Relationship(deleteRule: .cascade, inverse: \Purchase.item)
    var purchases: [Purchase] = []

    @Relationship(deleteRule: .cascade, inverse: \Usage.item)
    var usageRecords: [Usage] = []

    init(
        name: String,
        unitOfMeasure: UnitOfMeasure = .each,
        reorderLevel: Int = 10,
        isPerishable: Bool = false,
        notes: String = "",
        sortOrder: Int = 0,
        imageData: Data? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.unitOfMeasure = unitOfMeasure.rawValue
        self.reorderLevel = reorderLevel
        self.isPerishable = isPerishable
        self.notes = notes
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.imageData = imageData
    }

    var unit: UnitOfMeasure {
        UnitOfMeasure(rawValue: unitOfMeasure) ?? .each
    }

    var currentInventory: Int {
        let totalPurchased = purchases.reduce(0) { $0 + $1.quantity }
        let totalUsed = usageRecords.reduce(0) { $0 + $1.quantity }
        return totalPurchased - totalUsed
    }

    var needsReorder: Bool {
        currentInventory <= reorderLevel
    }

    var lowestPricePaid: Double? {
        purchases.map { $0.pricePerUnit }.min()
    }

    var lowestPricePurchase: Purchase? {
        purchases.min { $0.pricePerUnit < $1.pricePerUnit }
    }

    var averagePricePaid: Double? {
        guard !purchases.isEmpty else { return nil }
        let total = purchases.reduce(0.0) { $0 + $1.pricePerUnit }
        return total / Double(purchases.count)
    }

    var usageRatePerDay: Double {
        guard !usageRecords.isEmpty else { return 0 }

        let sortedRecords = usageRecords.sorted { $0.date < $1.date }
        guard let firstDate = sortedRecords.first?.date,
              let lastDate = sortedRecords.last?.date else { return 0 }

        let daysBetween = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        guard daysBetween > 0 else { return Double(usageRecords.reduce(0) { $0 + $1.quantity }) }

        let totalUsed = usageRecords.reduce(0) { $0 + $1.quantity }
        return Double(totalUsed) / Double(daysBetween)
    }

    var estimatedDaysUntilReorder: Int? {
        guard usageRatePerDay > 0 else { return nil }
        let unitsAboveReorder = currentInventory - reorderLevel
        guard unitsAboveReorder > 0 else { return 0 }
        return Int(Double(unitsAboveReorder) / usageRatePerDay)
    }

    var nextExpiringPurchase: Purchase? {
        purchases
            .filter { $0.expirationDate != nil && $0.remainingQuantity > 0 }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
            .first
    }

    var expiringWithin30Days: [Purchase] {
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return purchases.filter { purchase in
            guard let expDate = purchase.expirationDate,
                  purchase.remainingQuantity > 0 else { return false }
            return expDate <= thirtyDaysFromNow && expDate >= Date()
        }
    }
}
