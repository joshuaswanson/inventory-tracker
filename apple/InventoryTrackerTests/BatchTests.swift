import Foundation
import SwiftData
import Testing
@testable import InventoryTracker

private func makeContext() throws -> ModelContext {
    ModelContext(try InventoryStore.makeContainer(inMemory: true))
}

private func seededItem(in context: ModelContext, usage: [(quantity: Int, batch: String?)] = []) throws -> Item {
    let backup = Backup(
        items: [BackupItem(id: "i1", name: "Lidocaine", unit: "box", reorderLevel: 1, isPerishable: true, storageLocation: "", notes: "", createdAt: "2026-01-01")],
        purchases: [
            BackupPurchase(id: "old", date: "2026-01-01", itemId: "i1", vendorId: nil, quantity: 8, pricePerUnit: 40, lotNumber: "", expirationDate: "2026-04-20", notes: "", sourceId: nil),
            BackupPurchase(id: "new", date: "2026-02-01", itemId: "i1", vendorId: nil, quantity: 7, pricePerUnit: 45, lotNumber: "", expirationDate: "2027-05-18", notes: "", sourceId: nil),
        ],
        usage: usage.enumerated().map { index, record in
            BackupUsage(id: "u\(index)", date: "2026-02-0\(index + 1)", itemId: "i1", quantity: record.quantity, notes: "", isEstimate: false, purchaseId: record.batch, isAdjustment: false)
        }
    )
    try BackupMerge.merge(backup, into: context)
    return try #require(try context.fetch(FetchDescriptor<Item>()).first)
}

private func remaining(_ item: Item) -> [String: Int] {
    Dictionary(uniqueKeysWithValues: item.metrics(today: "2026-06-01").batches.map { ($0.id, $0.remaining) })
}

@Suite struct BatchCountTests {
    @Test func unlinkedUsageIsAnEstimateAppliedOldestFirst() throws {
        let item = try seededItem(in: makeContext(), usage: [(5, nil)])
        let metrics = item.metrics(today: "2026-06-01")
        #expect(remaining(item) == ["old": 3, "new": 7])
        #expect(metrics.expirationIsEstimated)
        #expect(metrics.daysUntilExpiration == -42)
    }

    @Test func linkedUsageIsExact() throws {
        let item = try seededItem(in: makeContext(), usage: [(8, "old")])
        let metrics = item.metrics(today: "2026-06-01")
        #expect(remaining(item) == ["old": 0, "new": 7])
        #expect(!metrics.expirationIsEstimated)
        #expect(metrics.nextExpiration == "2027-05-18")
    }

    @Test func countMakesTheItemExactAndKeepsUsageTotals() throws {
        let context = try makeContext()
        let item = try seededItem(in: context, usage: [(5, nil)])
        try BatchOperations.applyCount(["old": 0, "new": 7], to: item, in: context, today: "2026-06-01")

        let metrics = item.metrics(today: "2026-06-01")
        #expect(remaining(item) == ["old": 0, "new": 7])
        #expect(!metrics.expirationIsEstimated)
        #expect(metrics.currentInventory == 7)
        #expect(metrics.nextExpiration == "2027-05-18")
        let realUsage = (item.usageRecords ?? []).filter { !$0.isAdjustment }
        #expect(realUsage.reduce(0) { $0 + $1.quantity } == 5)
    }

    @Test func countAboveTheRecordsAddsStock() throws {
        let context = try makeContext()
        let item = try seededItem(in: context, usage: [(5, nil)])
        try BatchOperations.applyCount(["old": 8, "new": 7], to: item, in: context)
        #expect(remaining(item) == ["old": 8, "new": 7])
        #expect(item.metrics().currentInventory == 15)
    }

    @Test func countSplitsUsageThatSpansTwoBatches() throws {
        let context = try makeContext()
        let item = try seededItem(in: context, usage: [(10, nil)])
        try BatchOperations.applyCount(["old": 0, "new": 5], to: item, in: context)
        let real = (item.usageRecords ?? []).filter { !$0.isAdjustment }.map { "\($0.batch?.id ?? "none"):\($0.quantity)" }.sorted()
        #expect(real == ["new:2", "old:8"])
        #expect(remaining(item) == ["old": 0, "new": 5])
    }

    @Test func countHandlesMoreUsageThanStock() throws {
        let context = try makeContext()
        let item = try seededItem(in: context, usage: [(20, nil)])
        try BatchOperations.applyCount(["old": 0, "new": 2], to: item, in: context)
        #expect(remaining(item) == ["old": 0, "new": 2])
        #expect(!item.metrics().expirationIsEstimated)
    }

    @Test func countingTwiceAddsNothing() throws {
        let context = try makeContext()
        let item = try seededItem(in: context, usage: [(5, nil)])
        try BatchOperations.applyCount(["old": 1, "new": 7], to: item, in: context)
        let size = item.usageRecords?.count
        try BatchOperations.applyCount(["old": 1, "new": 7], to: item, in: context)
        #expect(item.usageRecords?.count == size)
    }

    @Test func adjustmentsStayOutOfUsageRate() throws {
        let context = try makeContext()
        let item = try seededItem(in: context, usage: [(1, "old"), (1, "old")])
        let before = item.metrics().usageRatePerDay
        try BatchOperations.applyCount(["old": 0, "new": 7], to: item, in: context)
        #expect(item.metrics().usageRatePerDay == before)
    }

    @Test func deletingABatchDropsCorrectionsAndUnlinksUsage() throws {
        let context = try makeContext()
        let item = try seededItem(in: context, usage: [(2, "old")])
        try BatchOperations.applyCount(["old": 5, "new": 7], to: item, in: context)
        let old = try #require(item.purchases?.first { $0.id == "old" })
        BatchOperations.delete(old, in: context)
        try context.save()

        let records = try context.fetch(FetchDescriptor<UsageRecord>())
        #expect(records.count == 1)
        #expect(records.first?.batch == nil)
        #expect(records.first?.isAdjustment == false)
    }

    @Test func balancesCanLeaveOutTheRecordBeingEdited() throws {
        let item = try seededItem(in: makeContext(), usage: [(8, "old")])
        let record = try #require(item.usageRecords?.first)
        #expect(BatchOperations.balances(for: item).first?.remaining == 0)
        #expect(BatchOperations.balances(for: item, excluding: record).first?.remaining == 8)
    }
}

@Suite struct SuggestedBatchTests {
    private func batch(_ id: String, expires: String?, remaining: Int) -> BatchBalance {
        BatchBalance(id: id, day: "2026-01-01", quantity: 10, expirationDate: expires, available: remaining, remaining: remaining)
    }

    @Test func picksTheFirstToExpireThatIsStillInDate() {
        let batches = [batch("expired", expires: "2026-01-01", remaining: 3), batch("later", expires: "2027-01-01", remaining: 3), batch("sooner", expires: "2026-09-01", remaining: 3)]
        #expect(BatchLedger.suggestedBatch(in: batches, today: "2026-06-01")?.id == "sooner")
    }

    @Test func skipsEmptyBatchesAndFallsBackToExpiredStock() {
        let batches = [batch("empty", expires: "2027-01-01", remaining: 0), batch("expired", expires: "2026-01-01", remaining: 3)]
        #expect(BatchLedger.suggestedBatch(in: batches, today: "2026-06-01")?.id == "expired")
    }

    @Test func emptyItemHasNoSuggestion() {
        #expect(BatchLedger.suggestedBatch(in: [], today: "2026-06-01") == nil)
    }
}
