import Foundation
import SwiftData

nonisolated enum NameSimilarity {
    private static let fillerWords: Set<String> = [
        "the", "and", "for", "with", "inc", "llc", "co", "dental", "supply", "supplies",
        "box", "pack", "case", "bag", "each", "pkg",
    ]

    static func words(in name: String) -> [String] {
        name.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 && !fillerWords.contains($0) }
    }

    /// Zero means the names have nothing in common. Sharing the leading word counts most,
    /// since that is usually the brand.
    static func score(_ first: String, _ second: String) -> Int {
        let firstWords = words(in: first)
        let secondWords = words(in: second)
        guard let firstLead = firstWords.first, let secondLead = secondWords.first else { return 0 }
        let shared = Set(firstWords).intersection(secondWords).count
        if firstLead == secondLead { return 10 + shared }
        return shared >= 2 ? shared : 0
    }
}

enum DuplicateCombiner {
    static func combine(_ duplicates: [Item], into keeper: Item, in context: ModelContext) throws {
        for duplicate in duplicates where duplicate.id != keeper.id {
            for purchase in duplicate.purchases ?? [] { purchase.item = keeper }
            for record in duplicate.usageRecords ?? [] { record.item = keeper }
            keeper.isPerishable = keeper.isPerishable || duplicate.isPerishable
            if keeper.storageLocation.isEmpty { keeper.storageLocation = duplicate.storageLocation }
            if keeper.notes.isEmpty { keeper.notes = duplicate.notes }
            keeper.otherNames = merged(keeper.otherNames, [duplicate.name] + duplicate.otherNames, excluding: keeper.name)
            context.delete(duplicate)
        }
        try context.save()
    }

    static func combine(_ duplicates: [Vendor], into keeper: Vendor, in context: ModelContext) throws {
        for duplicate in duplicates where duplicate.id != keeper.id {
            for purchase in duplicate.purchases ?? [] { purchase.vendor = keeper }
            if keeper.contactName.isEmpty { keeper.contactName = duplicate.contactName }
            if keeper.phone.isEmpty { keeper.phone = duplicate.phone }
            if keeper.email.isEmpty { keeper.email = duplicate.email }
            if keeper.address.isEmpty { keeper.address = duplicate.address }
            if keeper.notes.isEmpty { keeper.notes = duplicate.notes }
            keeper.otherNames = merged(keeper.otherNames, [duplicate.name] + duplicate.otherNames, excluding: keeper.name)
            context.delete(duplicate)
        }
        try context.save()
    }

    private static func merged(_ existing: [String], _ added: [String], excluding keeperName: String) -> [String] {
        var seen = Set([keeperName.lowercased()])
        return (existing + added).filter { seen.insert($0.lowercased()).inserted }
    }
}
