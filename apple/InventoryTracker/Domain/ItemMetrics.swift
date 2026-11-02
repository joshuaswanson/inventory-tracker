import Foundation

nonisolated struct PurchaseFact {
    var id: String
    var day: String
    var quantity: Int
    var pricePerUnit: Double
    var expirationDate: String?
    var vendorName: String?
}

nonisolated struct UsageFact {
    var day: String
    var quantity: Int
    var batchID: String?
    var isAdjustment = false
}

nonisolated func roundedToCents(_ value: Double) -> Double {
    (value * 100).rounded() / 100
}

nonisolated struct ItemMetrics: Equatable {
    var currentInventory: Int
    var needsReorder: Bool
    var lowestPrice: Double?
    var averagePrice: Double?
    var bestPriceVendor: String?
    var usageRatePerDay: Double
    var daysUntilReorder: Int?
    var nextExpiration: String?
    var daysUntilExpiration: Int?
    var expirationIsEstimated: Bool
    var batches: [BatchBalance]

    static let expiringSoonDays = 30

    var isExpiringSoon: Bool {
        guard let daysUntilExpiration else { return false }
        return daysUntilExpiration <= Self.expiringSoonDays
    }

    init(reorderLevel: Int, isPerishable: Bool, purchases: [PurchaseFact], usage: [UsageFact], today: String) {
        let consumption = usage.filter { !$0.isAdjustment }
        let totalUsed = consumption.reduce(0) { $0 + $1.quantity }
        let stock = purchases.reduce(0) { $0 + $1.quantity } - usage.reduce(0) { $0 + $1.quantity }
        currentInventory = stock
        needsReorder = stock <= reorderLevel
        averagePrice = Self.weightedAveragePrice(purchases)

        let best = purchases.min { $0.pricePerUnit < $1.pricePerUnit }
        lowestPrice = best?.pricePerUnit
        bestPriceVendor = best?.vendorName

        let rate = Self.usageRate(consumption, totalUsed: totalUsed)
        usageRatePerDay = roundedToCents(rate)
        daysUntilReorder = rate > 0 ? max(0, Int(Double(stock - reorderLevel) / rate)) : nil

        let ledger = isPerishable ? BatchLedger.balances(purchases: purchases, usage: usage) : ([], false)
        batches = ledger.0
        expirationIsEstimated = ledger.1

        let soonest = batches.filter { $0.remaining > 0 }.compactMap(\.expirationDate).min()
        nextExpiration = soonest
        daysUntilExpiration = soonest.flatMap { Day.days(from: today, to: $0) }
    }

    private static func weightedAveragePrice(_ purchases: [PurchaseFact]) -> Double? {
        let units = purchases.reduce(0) { $0 + $1.quantity }
        guard units > 0 else { return nil }
        let spent = purchases.reduce(0.0) { $0 + Double($1.quantity) * $1.pricePerUnit }
        return roundedToCents(spent / Double(units))
    }

    private static func usageRate(_ usage: [UsageFact], totalUsed: Int) -> Double {
        guard usage.count >= 2 else { return 0 }
        let days = usage.map(\.day).sorted()
        guard let first = days.first, let last = days.last, let span = Day.days(from: first, to: last), span > 0 else {
            return 0
        }
        return Double(totalUsed) / Double(span)
    }
}
