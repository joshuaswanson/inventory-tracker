import Foundation

nonisolated struct BatchBalance: Equatable, Identifiable {
    var id: String
    var day: String
    var quantity: Int
    var expirationDate: String?
    var available: Int
    var remaining: Int
}

/// A batch is a purchase, and usage records name the batch they came from. Usage without a batch
/// is applied to the oldest batches first, which makes the result an estimate until a shelf count
/// links it. Count corrections are usage records flagged `isAdjustment`, so stock stays purchases
/// minus usage while usage rates ignore them.
nonisolated enum BatchLedger {
    static func balances(purchases: [PurchaseFact], usage: [UsageFact]) -> (batches: [BatchBalance], isEstimated: Bool) {
        let known = Set(purchases.map(\.id))
        var linked: [String: Int] = [:]
        var unlinked = 0
        for record in usage {
            if let batchID = record.batchID, known.contains(batchID) {
                linked[batchID, default: 0] += record.quantity
            } else {
                unlinked += record.quantity
            }
        }

        let isEstimated = !purchases.isEmpty && unlinked != 0
        let oldestFirst = purchases.sorted { ($0.day, $0.id) < ($1.day, $1.id) }
        let batches = oldestFirst.map { purchase -> BatchBalance in
            let available = purchase.quantity - linked[purchase.id, default: 0]
            let applied = min(max(available, 0), unlinked)
            unlinked -= applied
            return BatchBalance(
                id: purchase.id,
                day: purchase.day,
                quantity: purchase.quantity,
                expirationDate: purchase.expirationDate,
                available: available,
                remaining: max(available - applied, 0)
            )
        }
        return (batches, isEstimated)
    }

    /// The batch to take from next: the first to expire that is still in date, or else the oldest in stock.
    static func suggestedBatch(in batches: [BatchBalance], today: String) -> BatchBalance? {
        let inStock = batches.filter { $0.remaining > 0 }
        let inDate = inStock.filter { batch in
            guard let expiration = batch.expirationDate else { return true }
            return expiration >= today
        }
        return inDate.min { ($0.expirationDate ?? "9999", $0.day) < ($1.expirationDate ?? "9999", $1.day) } ?? inStock.first
    }
}
