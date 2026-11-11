import Foundation
import SwiftData

/// Practice records for a first look at the app. Every ID starts with `prefix` so they can be removed together.
nonisolated enum SampleData {
    static let prefix = "sample-"

    static func backup(today: String = Day.today) -> Backup {
        func day(_ offset: Int) -> String { Day.offset(today, by: offset) }
        var backup = Backup()

        let vendors = [("schein", "Henry Schein"), ("patterson", "Patterson Dental"), ("benco", "Benco Dental")]
        backup.vendors = vendors.map { key, name in
            BackupVendor(id: prefix + key, name: name, contactName: "", phone: "", email: "", address: "", notes: "Sample", createdAt: day(-90))
        }

        func addItem(_ key: String, _ name: String, unit: String, reorder: Int, perishable: Bool = false) {
            backup.items.append(BackupItem(id: prefix + key, name: name, unit: unit, reorderLevel: reorder, isPerishable: perishable, storageLocation: "", notes: "Sample", createdAt: day(-90)))
        }
        func addPurchase(_ item: String, _ vendor: String, daysAgo: Int, quantity: Int, price: Double, expiresIn: Int? = nil) {
            let id = "\(prefix)p-\(item)-\(daysAgo)"
            backup.purchases.append(BackupPurchase(id: id, date: day(-daysAgo), itemId: prefix + item, vendorId: prefix + vendor, quantity: quantity, pricePerUnit: price, lotNumber: "", expirationDate: expiresIn.map(day), notes: "", sourceId: nil))
        }
        func addUsage(_ item: String, daysAgo: Int, quantity: Int, batchDaysAgo: Int? = nil) {
            let id = "\(prefix)u-\(item)-\(daysAgo)"
            backup.usage.append(BackupUsage(id: id, date: day(-daysAgo), itemId: prefix + item, quantity: quantity, notes: "", isEstimate: false, purchaseId: batchDaysAgo.map { "\(prefix)p-\(item)-\($0)" }, isAdjustment: false))
        }

        addItem("gloves", "Nitrile Gloves - Medium", unit: "box", reorder: 10)
        addPurchase("gloves", "schein", daysAgo: 60, quantity: 20, price: 8.99)
        addPurchase("gloves", "patterson", daysAgo: 20, quantity: 10, price: 9.49)
        for week in 1...8 { addUsage("gloves", daysAgo: week * 7, quantity: 3) }

        addItem("masks", "Level 3 Face Masks", unit: "box", reorder: 5)
        addPurchase("masks", "benco", daysAgo: 45, quantity: 12, price: 14.5)
        for week in 1...6 { addUsage("masks", daysAgo: week * 7, quantity: 1) }

        addItem("gauze", "Gauze Sponges 2x2", unit: "pack", reorder: 6)
        addPurchase("gauze", "schein", daysAgo: 50, quantity: 15, price: 9.75)
        for week in 1...5 { addUsage("gauze", daysAgo: week * 9, quantity: 2) }

        addItem("ejectors", "Saliva Ejectors", unit: "bag", reorder: 4)
        addPurchase("ejectors", "patterson", daysAgo: 70, quantity: 8, price: 7.25)
        for week in 1...5 { addUsage("ejectors", daysAgo: week * 12, quantity: 1) }

        addItem("lidocaine", "Lidocaine 2% w/ Epi", unit: "box", reorder: 4, perishable: true)
        addPurchase("lidocaine", "schein", daysAgo: 80, quantity: 6, price: 42, expiresIn: 20)
        addPurchase("lidocaine", "schein", daysAgo: 15, quantity: 6, price: 45, expiresIn: 400)
        for week in 1...4 { addUsage("lidocaine", daysAgo: week * 14, quantity: 1, batchDaysAgo: 80) }

        addItem("bonding", "Universal Bonding Agent", unit: "bottle", reorder: 3, perishable: true)
        addPurchase("bonding", "benco", daysAgo: 40, quantity: 4, price: 115, expiresIn: 300)
        addUsage("bonding", daysAgo: 30, quantity: 1, batchDaysAgo: 40)
        addUsage("bonding", daysAgo: 10, quantity: 1, batchDaysAgo: 40)

        return backup
    }

    static func hasSamples(in items: [Item]) -> Bool {
        items.contains { $0.id.hasPrefix(prefix) }
    }

    @MainActor
    static func remove(from context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<Item>()) where item.id.hasPrefix(prefix) {
            context.delete(item)
        }
        for vendor in try context.fetch(FetchDescriptor<Vendor>()) where vendor.id.hasPrefix(prefix) {
            context.delete(vendor)
        }
        try context.save()
    }
}
