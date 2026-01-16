import Foundation
import SwiftData

struct InventoryCalculator {

    static func calculateUsageRate(for item: Item, over days: Int = 30) -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentUsage = item.usageRecords.filter { $0.date >= cutoffDate }
        let totalUsed = recentUsage.reduce(0) { $0 + $1.quantity }
        return Double(totalUsed) / Double(days)
    }

    static func estimatedReorderDate(for item: Item) -> Date? {
        let dailyUsage = calculateUsageRate(for: item)
        guard dailyUsage > 0 else { return nil }

        let unitsAboveReorder = item.currentInventory - item.reorderLevel
        guard unitsAboveReorder > 0 else { return Date() }

        let daysUntilReorder = Int(Double(unitsAboveReorder) / dailyUsage)
        return Calendar.current.date(byAdding: .day, value: daysUntilReorder, to: Date())
    }

    static func lowestPriceByVendor(for item: Item) -> [(vendor: Vendor, price: Double)] {
        var vendorPrices: [UUID: (vendor: Vendor, price: Double)] = [:]

        for purchase in item.purchases {
            guard let vendor = purchase.vendor else { continue }
            if let existing = vendorPrices[vendor.id] {
                if purchase.pricePerUnit < existing.price {
                    vendorPrices[vendor.id] = (vendor, purchase.pricePerUnit)
                }
            } else {
                vendorPrices[vendor.id] = (vendor, purchase.pricePerUnit)
            }
        }

        return vendorPrices.values.sorted { $0.price < $1.price }
    }

    static func purchaseHistory(for item: Item, limit: Int? = nil) -> [Purchase] {
        let sorted = item.purchases.sorted { $0.date > $1.date }
        if let limit = limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }

    static func itemsNeedingReorder(from items: [Item]) -> [Item] {
        items.filter { $0.needsReorder }
    }

    static func itemsExpiringWithin(days: Int, from items: [Item]) -> [(item: Item, purchase: Purchase, daysLeft: Int)] {
        var results: [(item: Item, purchase: Purchase, daysLeft: Int)] = []
        let targetDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()

        for item in items {
            for purchase in item.purchases {
                guard let expDate = purchase.expirationDate,
                      purchase.remainingQuantity > 0,
                      expDate <= targetDate,
                      expDate >= Date() else { continue }

                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day ?? 0
                results.append((item, purchase, daysLeft))
            }
        }

        return results.sorted { $0.daysLeft < $1.daysLeft }
    }

    static func totalInventoryValue(for items: [Item]) -> Double {
        var total = 0.0
        for item in items {
            if let avgPrice = item.averagePricePaid {
                total += Double(item.currentInventory) * avgPrice
            }
        }
        return total
    }
}
