#if DEBUG
import Foundation
import SwiftData

/// Screenshot and simulator automation. `INVENTORY_SEED` names a backup in the app's Documents
/// folder, and `INVENTORY_SCREEN` picks the first screen.
enum DebugLaunch {
    static func apply(context: ModelContext, router: Router) {
        let environment = ProcessInfo.processInfo.environment
        if let seed = environment["INVENTORY_SEED"],
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let backup = try? Backup.load(from: [documents.appendingPathComponent(seed)]) {
            try? BackupMerge.merge(backup, into: context)
        }

        if let email = environment["INVENTORY_SEED_LOGIN"] {
            try? SavedLoginStore(supplierID: Supplier.supplyClinic.id).save(email: email, password: "fake-password")
        }

        let screen = environment["INVENTORY_SCREEN"] ?? ""
        if let section = AppSection(rawValue: screen) {
            router.show(section)
        }
        switch screen {
        case "expiring":
            router.show(.items, itemFilter: .expiring)
        case "item-detail":
            if let itemID = firstExpiredItemID(in: context) {
                router.show(.items)
                router.open(.item(itemID))
            }
        case "vendor-detail":
            if let vendorID = busiestVendorID(in: context) {
                router.show(.vendors)
                router.open(.vendor(vendorID))
            }
        case "new-purchase":
            router.show(.purchases)
            router.sheet = .purchase(nil, itemID: nil)
        case "new-item":
            router.show(.items)
            router.sheet = .item(nil)
        case "data":
            router.sheet = .data
        case "count-stock":
            if let itemID = firstExpiredItemID(in: context),
               let item = try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.id == itemID })).first {
                router.show(.items)
                router.open(.item(itemID))
                router.sheet = .count(item)
            }
        default:
            break
        }
    }

    private static func firstExpiredItemID(in context: ModelContext) -> String? {
        let items = (try? context.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.name)]))) ?? []
        return items.first { ($0.metrics().daysUntilExpiration ?? 0) < 0 }?.id ?? items.first?.id
    }

    private static func busiestVendorID(in context: ModelContext) -> String? {
        let vendors = (try? context.fetch(FetchDescriptor<Vendor>())) ?? []
        return vendors.max { $0.orderCount < $1.orderCount }?.id
    }
}
#endif
