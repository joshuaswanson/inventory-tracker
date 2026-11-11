import Foundation
import SwiftData

enum BatchOperations {
    private static let countNote = "Shelf count"

    static func balances(for item: Item, excluding record: UsageRecord? = nil) -> [BatchBalance] {
        let usage = (item.usageRecords ?? []).filter { $0.id != record?.id }.map {
            UsageFact(day: $0.date, quantity: $0.quantity, batchID: $0.batch?.id, isAdjustment: $0.isAdjustment)
        }
        return BatchLedger.balances(purchases: item.purchaseFacts, usage: usage).batches
    }

    /// Makes each counted batch hold exactly the counted units. Usage without a batch is linked
    /// first, oldest batches first, so the item has no estimates left afterwards.
    static func applyCount(_ counts: [String: Int], to item: Item, in context: ModelContext, today: String = Day.today) throws {
        settleUnlinkedUsage(of: item, in: context)
        try context.save()

        let purchases = item.purchases ?? []
        for batch in balances(for: item) {
            guard let counted = counts[batch.id], let purchase = purchases.first(where: { $0.id == batch.id }) else { continue }
            let difference = batch.available - counted
            guard difference != 0 else { continue }
            let adjustment = UsageRecord(date: today, item: nil, quantity: difference, notes: countNote)
            context.insert(adjustment)
            adjustment.item = item
            adjustment.batch = purchase
            adjustment.isAdjustment = true
        }
        try context.save()
    }

    /// For items counted as one number: records the gap between the records and the shelf.
    static func applyShelfCount(_ counted: Int, to item: Item, in context: ModelContext, today: String = Day.today) throws {
        let difference = item.metrics(today: today).currentInventory - counted
        guard difference != 0 else { return }
        let adjustment = UsageRecord(date: today, item: nil, quantity: difference, notes: countNote)
        context.insert(adjustment)
        adjustment.item = item
        adjustment.isAdjustment = true
        try context.save()
    }

    private static func settleUnlinkedUsage(of item: Item, in context: ModelContext) {
        let records = item.usageRecords ?? []
        let purchases = item.purchases ?? []
        guard !purchases.isEmpty else { return }

        let linkedOnly = records.filter { $0.batch != nil }.map {
            UsageFact(day: $0.date, quantity: $0.quantity, batchID: $0.batch?.id, isAdjustment: $0.isAdjustment)
        }
        let batches = BatchLedger.balances(purchases: item.purchaseFacts, usage: linkedOnly).batches
        var room = Dictionary(uniqueKeysWithValues: batches.map { ($0.id, max($0.available, 0)) })
        let order = batches.map(\.id)
        let purchasesByID = Dictionary(uniqueKeysWithValues: purchases.map { ($0.id, $0) })

        let unlinked = records.filter { $0.batch == nil }.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
        for record in unlinked {
            var current = record
            while true {
                let batchID = order.first { room[$0, default: 0] > 0 } ?? order[order.count - 1]
                let spare = room[batchID, default: 0]
                let take = spare > 0 ? min(current.quantity, spare) : current.quantity
                room[batchID] = spare - take
                let remainder = current.quantity - take
                current.batch = purchasesByID[batchID]
                current.quantity = take
                if remainder == 0 { break }

                let split = UsageRecord(date: record.date, item: nil, quantity: remainder, notes: record.notes, isEstimate: record.isEstimate)
                context.insert(split)
                split.item = item
                current = split
            }
        }
    }

    /// Forgets a batch: its count corrections go, and its usage becomes batchless.
    static func release(_ purchase: Purchase, in context: ModelContext) {
        for record in purchase.usageRecords ?? [] {
            if record.isAdjustment {
                context.delete(record)
            } else {
                record.batch = nil
            }
        }
    }

    static func delete(_ purchase: Purchase, in context: ModelContext) {
        release(purchase, in: context)
        context.delete(purchase)
    }
}
