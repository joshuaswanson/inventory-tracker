import Foundation
import SwiftData
import Testing
@testable import InventoryTracker

private func makeContext() throws -> ModelContext {
    ModelContext(try InventoryStore.makeContainer(inMemory: true))
}

@Suite struct BackupFilesTests {
    @Test func writesTodayAndKeepsOnlyTheNewestThirty() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        for offset in 0..<35 {
            try BackupFiles.write(Data("x".utf8), day: Day.offset("2026-01-01", by: offset), to: folder)
        }
        let names = BackupFiles.names(in: folder)
        #expect(names.count == BackupFiles.keepCount)
        #expect(names.first == "inventory-backup-2026-01-06.json")
        #expect(names.last == "inventory-backup-2026-02-04.json")
        #expect(BackupFiles.latestDate(in: folder) != nil)
    }

    @Test func sameDayIsOverwrittenAndOtherFilesAreLeftAlone() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        try BackupFiles.write(Data("one".utf8), day: "2026-01-01", to: folder)
        try BackupFiles.write(Data("two".utf8), day: "2026-01-01", to: folder)
        #expect(BackupFiles.names(in: folder).count == 1)
        #expect(try Data(contentsOf: folder.appendingPathComponent("inventory-backup-2026-01-01.json")) == Data("two".utf8))
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("notes.txt").path))
    }

    @Test func emptyInventoryWritesNoBackup() throws {
        #expect(BackupFiles.latestDate(in: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) == nil)
    }
}

@Suite struct SampleDataTests {
    @Test func samplesLoadWithLowStockAndAnExpiringBatch() throws {
        let context = try makeContext()
        try BackupMerge.merge(SampleData.backup(today: "2026-06-01"), into: context)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 6)
        #expect(SampleData.hasSamples(in: items))
        let rows = items.map { $0.metrics(today: "2026-06-01") }
        #expect(rows.contains { $0.needsReorder })
        #expect(rows.contains { $0.isExpiringSoon })
        #expect(rows.allSatisfy { $0.currentInventory >= 0 })
        #expect(rows.allSatisfy { !$0.expirationIsEstimated })
    }

    @Test func removingSamplesKeepsEverythingElse() throws {
        let context = try makeContext()
        try BackupMerge.merge(SampleData.backup(), into: context)
        let mine = Item(name: "My Item")
        context.insert(mine)
        let purchase = Purchase(date: Day.today, item: nil, quantity: 2, pricePerUnit: 3)
        context.insert(purchase)
        purchase.item = mine
        purchase.vendor = try context.fetch(FetchDescriptor<Vendor>()).first
        try context.save()

        try SampleData.remove(from: context)
        #expect(try context.fetch(FetchDescriptor<Item>()).map(\.name) == ["My Item"])
        #expect(try context.fetchCount(FetchDescriptor<Vendor>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Purchase>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<UsageRecord>()) == 0)
    }
}

@Suite struct ShelfCountTests {
    private func item(in context: ModelContext, bought: Int) throws -> Item {
        let item = Item(name: "Gauze", reorderLevel: 2)
        context.insert(item)
        if bought > 0 {
            let purchase = Purchase(date: "2026-01-01", item: nil, quantity: bought, pricePerUnit: 1)
            context.insert(purchase)
            purchase.item = item
        }
        try context.save()
        return item
    }

    @Test func countSetsStockDownAndUp() throws {
        let context = try makeContext()
        let item = try item(in: context, bought: 10)
        try BatchOperations.applyShelfCount(6, to: item, in: context, today: "2026-02-01")
        #expect(item.metrics().currentInventory == 6)
        try BatchOperations.applyShelfCount(9, to: item, in: context, today: "2026-02-02")
        #expect(item.metrics().currentInventory == 9)
    }

    @Test func countWithoutPurchasesStillSetsStock() throws {
        let context = try makeContext()
        let item = try item(in: context, bought: 0)
        try BatchOperations.applyShelfCount(4, to: item, in: context)
        #expect(item.metrics().currentInventory == 4)
    }

    @Test func unchangedCountAddsNothing() throws {
        let context = try makeContext()
        let item = try item(in: context, bought: 10)
        try BatchOperations.applyShelfCount(10, to: item, in: context)
        #expect(item.usageRecords?.isEmpty == true)
    }

    @Test func twoCountsGiveAUsageRateAndFoundUnitsDoNot() throws {
        let context = try makeContext()
        let item = try item(in: context, bought: 40)
        try BatchOperations.applyShelfCount(30, to: item, in: context, today: "2026-02-01")
        try BatchOperations.applyShelfCount(20, to: item, in: context, today: "2026-02-11")
        #expect(item.metrics().usageRatePerDay == 2)
        try BatchOperations.applyShelfCount(25, to: item, in: context, today: "2026-02-21")
        #expect(item.metrics().usageRatePerDay == 2)
        #expect(item.metrics().currentInventory == 25)
    }
}

@Suite struct ReorderListTests {
    private let lines = [
        ReorderLine(id: "1", name: "Gloves", unit: "bx", stock: 6, reorderLevel: 10, vendor: "Schein", bestPrice: 6.5),
        ReorderLine(id: "2", name: "Bibs", unit: "cs", stock: 0, reorderLevel: 0, vendor: nil, bestPrice: nil),
        ReorderLine(id: "3", name: "Angles", unit: "pk", stock: 1, reorderLevel: 2, vendor: "Schein", bestPrice: 153.59),
    ]

    @Test func suggestsEnoughToReachTwiceTheReorderLevel() {
        #expect(lines.map(\.suggestedQuantity) == [14, 1, 3])
    }

    @Test func groupsByVendorWithUnknownLast() {
        let groups = ReorderList.groups(lines)
        #expect(groups.map(\.vendor) == ["Schein", ReorderList.noVendor])
        #expect(groups[0].lines.map(\.name) == ["Angles", "Gloves"])
    }

    @Test func textIsReadyToPaste() {
        let text = ReorderList.text(lines, day: "2026-11-11")
        #expect(text.hasPrefix("Shopping list, Nov 11, 2026\n\nSchein\n- Angles: order 3 pk (have 1), best price $153.59\n"))
        #expect(text.hasSuffix("No vendor yet\n- Bibs: order 1 cs (have 0)"))
    }
}

@Suite struct DashboardLayoutTests {
    @Test func boxesCanBeMovedResizedRemovedAndAddedBack() {
        var layout = DashboardLayout.standard
        layout.move(.inventoryValue, onto: .totalItems)
        #expect(layout.tiles.prefix(2).map(\.widget) == [.inventoryValue, .totalItems])
        layout.move(.inventoryValue, onto: .vendors)
        #expect(layout.tiles.prefix(4).map(\.widget) == [.totalItems, .lowStockCount, .expiringCount, .vendors])
        #expect(layout.tiles[4].widget == .inventoryValue)

        layout.resize(.lowStockAlerts)
        #expect(layout.tiles.first { $0.widget == .lowStockAlerts }?.size == .full)
        layout.resize(.lowStockAlerts)
        #expect(layout.tiles.first { $0.widget == .lowStockAlerts }?.size == .half)

        layout.hide(.vendors)
        #expect(layout.hidden == [.vendors, .spentThisMonth, .recentPurchases])
        layout.add(.recentPurchases)
        layout.add(.recentPurchases)
        #expect(layout.tiles.last == DashboardTile(widget: .recentPurchases, size: .half))
    }

    @Test func layoutIsSavedAndUnreadableSavesFallBackToTheStandardOne() throws {
        let defaults = try #require(UserDefaults(suiteName: "dashboard-layout-test"))
        defaults.removePersistentDomain(forName: "dashboard-layout-test")
        #expect(DashboardLayout.load(from: defaults) == .standard)
        var layout = DashboardLayout.standard
        layout.hide(.totalItems)
        layout.save(to: defaults)
        #expect(DashboardLayout.load(from: defaults) == layout)
        defaults.set(Data("nonsense".utf8), forKey: DashboardLayout.storageKey)
        #expect(DashboardLayout.load(from: defaults) == .standard)
    }

    @Test func tileWidthsFollowTheNumberOfColumns() {
        #expect(DashboardTileSize.small.span(columns: 6) == 1)
        #expect(DashboardTileSize.wide.span(columns: 6) == 2)
        #expect(DashboardTileSize.half.span(columns: 6) == 3)
        #expect(DashboardTileSize.half.span(columns: 2) == 2)
        #expect(DashboardTileSize.full.span(columns: 4) == 4)
    }
}

@Suite struct SpendingReportTests {
    private let entries = [
        SpendingEntry(day: "2026-03-02", item: "Gloves", vendor: "Schein", quantity: 10, pricePerUnit: 6.5),
        SpendingEntry(day: "2026-03-20", item: "Wrap 20\" x 20\", blue", vendor: "", quantity: 1, pricePerUnit: 31.57),
        SpendingEntry(day: "2025-12-01", item: "Masks", vendor: "Benco", quantity: 2, pricePerUnit: 100),
    ]

    @Test func totalsByVendorAndMonth() {
        let report = SpendingReport(entries: entries)
        #expect(report.total == 296.57)
        #expect(report.byVendor == [SpendingTotal(name: "Benco", total: 200), SpendingTotal(name: "Schein", total: 65), SpendingTotal(name: SpendingReport.noVendor, total: 31.57)])
        #expect(report.byMonth == [SpendingTotal(name: "2026-03", total: 96.57), SpendingTotal(name: "2025-12", total: 200)])
        #expect(Format.month("2026-03") == "March 2026")
    }

    @Test func monthlySeriesRunsOldestFirstAndFillsQuietMonths() {
        let report = SpendingReport(entries: entries)
        #expect(report.monthlySeries.map(\.name) == ["2025-12", "2026-01", "2026-02", "2026-03"])
        #expect(report.monthlySeries.map(\.total) == [200, 0, 0, 96.57])
        #expect(report.averagePerMonth == 74.14)
        #expect(report.purchaseCount == 3)
        #expect(report.byItem.first == SpendingTotal(name: "Masks", total: 200))
        #expect(SpendingReport(entries: []).monthlySeries.isEmpty)
    }

    @Test func smallRowsFoldIntoOther() {
        let rows = (1...6).map { SpendingTotal(name: "V\($0)", total: Double(10 - $0)) }
        let folded = SpendingReport.leading(rows, limit: 3) { "\($0) others" }
        #expect(folded.map(\.name) == ["V1", "V2", "V3", "3 others"])
        #expect(folded.last?.total == 15)
        #expect(SpendingReport.leading(Array(rows.prefix(4)), limit: 3) { "\($0) others" }.count == 4)
    }

    @Test func periodsFilterByYear() {
        #expect(SpendingPeriod.thisYear.includes(day: "2026-03-02", today: "2026-11-11"))
        #expect(!SpendingPeriod.thisYear.includes(day: "2025-12-01", today: "2026-11-11"))
        #expect(SpendingPeriod.lastYear.includes(day: "2025-12-01", today: "2026-11-11"))
        #expect(SpendingPeriod.allTime.includes(day: "2019-01-01", today: "2026-11-11"))
    }

    @Test func csvQuotesCommasAndQuotes() {
        let csv = SpendingReport.csv(entries)
        let rows = csv.split(separator: "\n").map(String.init)
        #expect(rows[0] == "Date,Item,Vendor,Quantity,Price per Unit,Total")
        #expect(rows[1] == "2025-12-01,Masks,Benco,2,100.00,200.00")
        #expect(rows[3] == "2026-03-20,\"Wrap 20\"\" x 20\"\", blue\",,1,31.57,31.57")
    }
}

@Suite struct ReminderPlannerTests {
    private func input(_ id: String, needsReorder: Bool = false, reorderIn: Int? = nil, expires: [String] = []) -> ReminderInput {
        ReminderInput(id: id, name: "Item \(id)", needsReorder: needsReorder, daysUntilReorder: reorderIn, expirationsInStock: expires)
    }

    @Test func expirationReminderComesTwoWeeksAhead() {
        let plan = ReminderPlanner.plan([input("a", expires: ["2026-12-31", "2026-08-01"])], today: "2026-06-01")
        #expect(plan == [PlannedReminder(id: "expire-a", day: "2026-07-18", title: "Expiring soon", body: "Item a expires on Aug 1, 2026.")])
    }

    @Test func nearExpirationRemindsTomorrowAndPastOnesAreSkipped() {
        let plan = ReminderPlanner.plan([input("a", expires: ["2026-06-05"]), input("b", expires: ["2026-05-01"])], today: "2026-06-01")
        #expect(plan.map(\.day) == ["2026-06-02"])
    }

    @Test func lowStockReminderUsesThePredictedDay() {
        let plan = ReminderPlanner.plan([input("a", reorderIn: 10), input("b", needsReorder: true, reorderIn: 0), input("c")], today: "2026-06-01")
        #expect(plan.map(\.id) == ["low-a"])
        #expect(plan.first?.day == "2026-06-11")
    }

    @Test func planIsCappedAndSoonestFirst() {
        let inputs = (1...40).map { input("\($0)", reorderIn: $0) }
        let plan = ReminderPlanner.plan(inputs, today: "2026-06-01")
        #expect(plan.count == ReminderPlanner.maxReminders)
        #expect(plan.first?.day == "2026-06-02")
    }
}

@Suite struct TourTests {
    @Test func stepsRunInOrderAndEndAtSettings() {
        var visited: [TourStep] = []
        var step: TourStep? = .dashboard
        while let current = step {
            visited.append(current)
            step = current.next
        }
        #expect(visited == TourStep.allCases)
        #expect(TourStep.dashboard.previous == nil)
        #expect(TourStep.settings.previous == .reorder)
        #expect(TourStep.items.position == "2 of 5")
    }

    @Test func startingOnAnEmptyInventoryAddsPracticeItemsOnce() throws {
        let context = try makeContext()
        let router = Router()
        Tour.start(router: router, context: context)
        #expect(router.tourStep == .dashboard)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 6)
        Tour.start(router: router, context: context)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 6)
    }

    @Test func startingWithRealItemsAddsNothing() throws {
        let context = try makeContext()
        context.insert(Item(name: "Mine"))
        try context.save()
        Tour.start(router: Router(), context: context)
        #expect(try context.fetch(FetchDescriptor<Item>()).map(\.name) == ["Mine"])
    }
}

@Suite struct DayOffsetTests {
    @Test func offsetCrossesMonthsAndLeapDays() {
        #expect(Day.offset("2026-01-31", by: 1) == "2026-02-01")
        #expect(Day.offset("2024-03-01", by: -1) == "2024-02-29")
        #expect(Day.offset("2026-11-11", by: 0) == "2026-11-11")
    }
}
