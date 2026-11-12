import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct BackupItem: Codable {
    var id: String
    var name: String
    var unit: String
    var reorderLevel: Int
    var isPerishable: Bool
    var storageLocation: String
    var notes: String
    var createdAt: String
    var otherNames: String?
}

nonisolated struct BackupVendor: Codable {
    var id: String
    var name: String
    var contactName: String
    var phone: String
    var email: String
    var address: String
    var notes: String
    var createdAt: String
    var otherNames: String?
}

nonisolated struct BackupPurchase: Codable {
    var id: String
    var date: String
    var itemId: String
    var vendorId: String?
    var quantity: Int
    var pricePerUnit: Double
    var lotNumber: String
    var expirationDate: String?
    var notes: String
    var sourceId: String?
}

nonisolated struct BackupUsage: Codable {
    var id: String
    var date: String
    var itemId: String
    var quantity: Int
    var notes: String
    var isEstimate: Bool
    var purchaseId: String?
    var isAdjustment: Bool?
}

/// One file holds everything. `load` also reads the older layout of one JSON file per collection.
nonisolated struct Backup: Codable {
    var items: [BackupItem] = []
    var vendors: [BackupVendor] = []
    var purchases: [BackupPurchase] = []
    var usage: [BackupUsage] = []

    enum LoadError: LocalizedError {
        case noRecognizedFiles

        var errorDescription: String? {
            "Choose a backup file, or a data folder with items, vendors, purchases and usage JSON files."
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func load(from urls: [URL]) throws -> Backup {
        var backup = Backup()
        var recognized = false
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            recognized = try backup.absorb(url) || recognized
        }
        guard recognized else { throw LoadError.noRecognizedFiles }
        return backup
    }

    private mutating func absorb(_ url: URL) throws -> Bool {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            var recognized = false
            for name in ["items", "vendors", "purchases", "usage"] {
                let file = url.appendingPathComponent("\(name).json")
                if FileManager.default.fileExists(atPath: file.path) {
                    recognized = try absorb(file) || recognized
                }
            }
            return recognized
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        if let whole = try? decoder.decode(Backup.self, from: data) {
            items += whole.items
            vendors += whole.vendors
            purchases += whole.purchases
            usage += whole.usage
            return true
        }
        switch url.deletingPathExtension().lastPathComponent {
        case "items": items += try decoder.decode([BackupItem].self, from: data)
        case "vendors": vendors += try decoder.decode([BackupVendor].self, from: data)
        case "purchases": purchases += try decoder.decode([BackupPurchase].self, from: data)
        case "usage": usage += try decoder.decode([BackupUsage].self, from: data)
        default: return false
        }
        return true
    }
}

nonisolated struct BackupSummary: Equatable {
    var added = 0
    var updated = 0
    var skipped = 0
}

enum BackupMerge {
    /// Inserts new records and overwrites matching IDs, which makes repeat imports safe.
    @discardableResult
    static func merge(_ backup: Backup, into context: ModelContext) throws -> BackupSummary {
        var summary = BackupSummary()
        var items = Dictionary(try context.fetch(FetchDescriptor<Item>()).map { ($0.id, $0) }) { first, _ in first }
        var vendors = Dictionary(try context.fetch(FetchDescriptor<Vendor>()).map { ($0.id, $0) }) { first, _ in first }
        var purchases = Dictionary(try context.fetch(FetchDescriptor<Purchase>()).map { ($0.id, $0) }) { first, _ in first }
        let usage = Dictionary(try context.fetch(FetchDescriptor<UsageRecord>()).map { ($0.id, $0) }) { first, _ in first }

        func record(isNew: Bool) {
            if isNew { summary.added += 1 } else { summary.updated += 1 }
        }

        for source in backup.items {
            let target = items[source.id] ?? Item(id: source.id, name: source.name)
            record(isNew: items[source.id] == nil)
            target.name = source.name
            target.unitRaw = source.unit
            target.reorderLevel = source.reorderLevel
            target.isPerishable = source.isPerishable
            target.storageLocation = source.storageLocation
            target.notes = source.notes
            target.createdAt = source.createdAt
            target.otherNamesText = source.otherNames ?? target.otherNamesText
            if items[source.id] == nil { context.insert(target) }
            items[source.id] = target
        }

        for source in backup.vendors {
            let target = vendors[source.id] ?? Vendor(id: source.id, name: source.name)
            record(isNew: vendors[source.id] == nil)
            target.name = source.name
            target.contactName = source.contactName
            target.phone = source.phone
            target.email = source.email
            target.address = source.address
            target.notes = source.notes
            target.createdAt = source.createdAt
            target.otherNamesText = source.otherNames ?? target.otherNamesText
            if vendors[source.id] == nil { context.insert(target) }
            vendors[source.id] = target
        }

        for source in backup.purchases {
            guard let item = items[source.itemId] else {
                summary.skipped += 1
                continue
            }
            let existing = purchases[source.id]
            let target = existing ?? Purchase(id: source.id, date: source.date, item: nil, quantity: source.quantity, pricePerUnit: source.pricePerUnit)
            record(isNew: existing == nil)
            if existing == nil { context.insert(target) }
            target.date = source.date
            target.item = item
            target.vendor = source.vendorId.flatMap { vendors[$0] }
            target.quantity = source.quantity
            target.pricePerUnit = source.pricePerUnit
            target.productNumber = source.lotNumber
            target.expirationDate = source.expirationDate?.isEmpty == false ? source.expirationDate : nil
            target.notes = source.notes
            target.sourceId = source.sourceId
            purchases[source.id] = target
        }

        for source in backup.usage {
            guard let item = items[source.itemId] else {
                summary.skipped += 1
                continue
            }
            let existing = usage[source.id]
            let target = existing ?? UsageRecord(id: source.id, date: source.date, item: nil, quantity: source.quantity)
            record(isNew: existing == nil)
            if existing == nil { context.insert(target) }
            target.date = source.date
            target.item = item
            target.quantity = source.quantity
            target.notes = source.notes
            target.isEstimate = source.isEstimate
            target.isAdjustment = source.isAdjustment ?? false
            target.batch = source.purchaseId.flatMap { purchases[$0] }
        }

        try context.save()
        return summary
    }

    static func export(from context: ModelContext) throws -> Backup {
        Backup(
            items: try context.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.id)])).map {
                BackupItem(id: $0.id, name: $0.name, unit: $0.unitRaw, reorderLevel: $0.reorderLevel, isPerishable: $0.isPerishable, storageLocation: $0.storageLocation, notes: $0.notes, createdAt: $0.createdAt, otherNames: $0.otherNamesText.isEmpty ? nil : $0.otherNamesText)
            },
            vendors: try context.fetch(FetchDescriptor<Vendor>(sortBy: [SortDescriptor(\.id)])).map {
                BackupVendor(id: $0.id, name: $0.name, contactName: $0.contactName, phone: $0.phone, email: $0.email, address: $0.address, notes: $0.notes, createdAt: $0.createdAt, otherNames: $0.otherNamesText.isEmpty ? nil : $0.otherNamesText)
            },
            purchases: try context.fetch(FetchDescriptor<Purchase>(sortBy: [SortDescriptor(\.id)])).compactMap { purchase in
                guard let itemID = purchase.item?.id else { return nil }
                return BackupPurchase(id: purchase.id, date: purchase.date, itemId: itemID, vendorId: purchase.vendor?.id, quantity: purchase.quantity, pricePerUnit: purchase.pricePerUnit, lotNumber: purchase.productNumber, expirationDate: purchase.expirationDate, notes: purchase.notes, sourceId: purchase.sourceId)
            },
            usage: try context.fetch(FetchDescriptor<UsageRecord>(sortBy: [SortDescriptor(\.id)])).compactMap { record in
                guard let itemID = record.item?.id else { return nil }
                return BackupUsage(id: record.id, date: record.date, itemId: itemID, quantity: record.quantity, notes: record.notes, isEstimate: record.isEstimate, purchaseId: record.batch?.id, isAdjustment: record.isAdjustment)
            }
        )
    }
}

nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
