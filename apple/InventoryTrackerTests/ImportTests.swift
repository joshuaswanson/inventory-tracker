import Foundation
import SwiftData
import Testing
@testable import InventoryTracker

private func rawLine(
    date: String = "Ordered on 03/14/2026",
    name: String = "Gauze Sponges 2x2 200/Pkg",
    manuCode: String = "Manu Code: GZ-22",
    price: String = "$1,204.50",
    status: String = "Status: Delivered"
) -> RawOrderLine {
    RawOrderLine(
        date: date,
        vendor: "Items from Acme Dental",
        suborderNumber: "#S-100",
        name: name,
        manuCode: manuCode,
        quantity: "Qty: 3",
        unitPrice: price,
        status: status
    )
}

private func sampleBackup() -> Backup {
    Backup(
        items: [BackupItem(id: "i1", name: "Gloves", unit: "box", reorderLevel: 0, isPerishable: true, storageLocation: "Cabinet A", notes: "Blue", createdAt: "2026-01-01")],
        vendors: [BackupVendor(id: "v1", name: "Acme", contactName: "Sam", phone: "8005551212", email: "a@example.com", address: "1 Main", notes: "", createdAt: "2026-01-01")],
        purchases: [
            BackupPurchase(id: "p1", date: "2026-01-10", itemId: "i1", vendorId: "v1", quantity: 10, pricePerUnit: 5.5, lotNumber: "A-1", expirationDate: "2026-09-01", notes: "", sourceId: "supplyclinic:S-1:A-1"),
            BackupPurchase(id: "p2", date: "2026-01-11", itemId: "missing", vendorId: nil, quantity: 1, pricePerUnit: 1, lotNumber: "", expirationDate: "", notes: "", sourceId: nil),
        ],
        usage: [BackupUsage(id: "u1", date: "2026-02-01", itemId: "i1", quantity: 2, notes: "", isEstimate: true, purchaseId: "p1", isAdjustment: false)]
    )
}

@Suite struct SupplyClinicParsingTests {
    @Test func lineParsesEveryField() {
        let line = OrderLine(raw: rawLine())
        #expect(line.date == "2026-03-14")
        #expect(line.vendor == "Acme Dental")
        #expect(line.suborderNumber == "S-100")
        #expect(line.manuCode == "GZ-22")
        #expect(line.quantity == 3)
        #expect(line.unitPrice == 1204.5)
        #expect(line.status == "Delivered")
        #expect(line.sourceID == "supplyclinic:S-100:GZ-22")
    }

    @Test func unitIsInferredFromTheProductName() {
        #expect(SupplyClinicText.unit(for: "Ultimate Bib 250/Case") == .case)
        #expect(SupplyClinicText.unit(for: "Syringe 50/Bx") == .box)
        #expect(SupplyClinicText.unit(for: "Angles 200/Pkg") == .pack)
        #expect(SupplyClinicText.unit(for: "Rinse 4 oz Bottle") == .bottle)
        #expect(SupplyClinicText.unit(for: "Debacterol 1.5ml Vial") == .each)
    }

    @Test func pageDetection() {
        #expect(SupplyClinicText.isChallengePage("<title>Just a moment...</title>"))
        #expect(!SupplyClinicText.isChallengePage("<div class=\"order\"></div>"))
        #expect(SupplyClinicText.isSignInPage(url: "https://www.supplyclinic.com/users/sign_in", markup: ""))
        #expect(SupplyClinicText.isSignInPage(url: "https://x", markup: "<input name=\"user[password]\">"))
    }
}

@Suite struct SupplyClinicMergeTests {
    @Test func mergeCreatesRecordsAndSkipsReturns() throws {
        let context = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        let lines = [
            OrderLine(raw: rawLine()),
            OrderLine(raw: rawLine(name: "Returned Thing", manuCode: "Manu Code: RT-1", status: "Status: Returned")),
        ]
        let summary = try SupplyClinicMerge.merge(lines, into: context, today: "2026-04-01")
        #expect(summary == OrderImportSummary(imported: 1, duplicates: 0, skipped: 1, newItems: 1, newVendors: 1))

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.unit == .pack)
        #expect(item.reorderLevel == 2)
        let purchase = try #require(item.purchases?.first)
        #expect(purchase.vendor?.name == "Acme Dental")
        #expect(purchase.productNumber == "GZ-22")
    }

    @Test func secondImportOnlyReportsDuplicates() throws {
        let context = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        let lines = [OrderLine(raw: rawLine())]
        try SupplyClinicMerge.merge(lines, into: context)
        let summary = try SupplyClinicMerge.merge(lines, into: context)
        #expect(summary.imported == 0)
        #expect(summary.duplicates == 1)
        #expect(try context.fetchCount(FetchDescriptor<Purchase>()) == 1)
    }

    @Test func importedSourceIDsPreventReimporting() throws {
        let context = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        var backup = sampleBackup()
        backup.purchases[0].sourceId = "supplyclinic:S-100:GZ-22"
        try BackupMerge.merge(backup, into: context)
        let summary = try SupplyClinicMerge.merge([OrderLine(raw: rawLine())], into: context)
        #expect(summary.duplicates == 1)
    }

    @Test func lineWithoutADateIsSkipped() throws {
        let context = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        let summary = try SupplyClinicMerge.merge([OrderLine(raw: rawLine(date: "soon"))], into: context)
        #expect(summary.imported == 0)
        #expect(summary.skipped == 1)
    }
}

@Suite struct BackupTests {
    @Test func mergePreservesRelationshipsAndSkipsOrphans() throws {
        let context = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        let summary = try BackupMerge.merge(sampleBackup(), into: context)
        #expect(summary == BackupSummary(added: 4, updated: 0, skipped: 1))

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.unit == .box)
        #expect(item.reorderLevel == 0)
        #expect(item.purchases?.first?.vendor?.name == "Acme")
        #expect(item.usageRecords?.first?.isEstimate == true)
    }

    @Test func repeatedMergeUpdatesWithoutDuplicating() throws {
        let context = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        try BackupMerge.merge(sampleBackup(), into: context)
        var changed = sampleBackup()
        changed.items[0].name = "Gloves XL"
        let summary = try BackupMerge.merge(changed, into: context)
        #expect(summary == BackupSummary(added: 0, updated: 4, skipped: 1))
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Item>()).first?.name == "Gloves XL")
    }

    @Test func exportRoundTripsIntoAnEmptyStore() throws {
        let source = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        try BackupMerge.merge(sampleBackup(), into: source)
        let data = try BackupMerge.export(from: source).encoded()

        let target = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        try BackupMerge.merge(try JSONDecoder().decode(Backup.self, from: data), into: target)
        #expect(try BackupMerge.export(from: target).encoded() == data)
        let purchase = try #require(try target.fetch(FetchDescriptor<Purchase>()).first)
        #expect(purchase.sourceId == "supplyclinic:S-1:A-1")
        #expect(purchase.expirationDate == "2026-09-01")
        #expect(try target.fetch(FetchDescriptor<UsageRecord>()).first?.batch?.id == "p1")
    }

    @Test func recordsWrittenBeforeBatchesExistedStillDecode() throws {
        let json = #"{"id":"u","date":"2026-02-01","itemId":"i","quantity":2,"notes":"","isEstimate":false}"#
        let record = try JSONDecoder().decode(BackupUsage.self, from: Data(json.utf8))
        #expect(record.purchaseId == nil)
        #expect(record.isAdjustment == nil)
    }

    @Test func olderDataFolderLoads() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let encoder = JSONEncoder()
        try encoder.encode(sampleBackup().items).write(to: folder.appendingPathComponent("items.json"))
        try encoder.encode(sampleBackup().usage).write(to: folder.appendingPathComponent("usage.json"))

        let backup = try Backup.load(from: [folder])
        #expect(backup.items.count == 1)
        #expect(backup.usage.count == 1)
        #expect(backup.vendors.isEmpty)
    }

    @Test func unrelatedFileIsRejected() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try Data("[]".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(throws: Backup.LoadError.self) { try Backup.load(from: [file]) }
    }
}

@Suite struct ModelBehaviorTests {
    @Test func deletingAnItemCascadesAndDeletingAVendorKeepsPurchases() throws {
        let context = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        try BackupMerge.merge(sampleBackup(), into: context)

        let vendor = try #require(try context.fetch(FetchDescriptor<Vendor>()).first)
        context.delete(vendor)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Purchase>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Purchase>()).first?.vendor == nil)

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        context.delete(item)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Purchase>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<UsageRecord>()) == 0)
    }

    @Test func metricsReadThroughModelRelationships() throws {
        let context = ModelContext(try InventoryStore.makeContainer(inMemory: true))
        try BackupMerge.merge(sampleBackup(), into: context)
        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        let metrics = item.metrics(today: "2026-06-01")
        #expect(metrics.currentInventory == 8)
        #expect(metrics.bestPriceVendor == "Acme")
        #expect(metrics.daysUntilExpiration == 92)
    }
}
