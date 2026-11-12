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

/// A duplicate that was folded into another entry, with enough detail to bring it back.
nonisolated struct AbsorbedEntry: Codable, Equatable, Identifiable {
    var name: String
    var otherNames: [String] = []
    var purchaseIDs: [String] = []
    var usageIDs: [String] = []
    var notes = ""
    var unitRaw: String?
    var reorderLevel: Int?
    var isPerishable: Bool?
    var storageLocation: String?
    var contactName: String?
    var phone: String?
    var email: String?
    var address: String?

    var id: String { name }

    static func decode(_ text: String) -> [AbsorbedEntry] {
        (try? JSONDecoder().decode([AbsorbedEntry].self, from: Data(text.utf8))) ?? []
    }

    static func encode(_ entries: [AbsorbedEntry]) -> String {
        guard !entries.isEmpty, let data = try? JSONEncoder().encode(entries) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

enum DuplicateCombiner {
    static func combine(_ duplicates: [Item], into keeper: Item, in context: ModelContext) throws {
        for duplicate in duplicates where duplicate.id != keeper.id {
            let inherited = duplicate.absorbed
            let entry = AbsorbedEntry(
                name: duplicate.name,
                otherNames: duplicate.otherNames.filter { name in !inherited.contains { $0.name == name || $0.otherNames.contains(name) } },
                purchaseIDs: (duplicate.purchases ?? []).map(\.id).filter { id in !inherited.contains { $0.purchaseIDs.contains(id) } },
                usageIDs: (duplicate.usageRecords ?? []).map(\.id).filter { id in !inherited.contains { $0.usageIDs.contains(id) } },
                notes: duplicate.notes,
                unitRaw: duplicate.unitRaw,
                reorderLevel: duplicate.reorderLevel,
                isPerishable: duplicate.isPerishable,
                storageLocation: duplicate.storageLocation
            )
            for purchase in duplicate.purchases ?? [] { purchase.item = keeper }
            for record in duplicate.usageRecords ?? [] { record.item = keeper }
            keeper.isPerishable = keeper.isPerishable || duplicate.isPerishable
            if keeper.storageLocation.isEmpty { keeper.storageLocation = duplicate.storageLocation }
            if keeper.notes.isEmpty { keeper.notes = duplicate.notes }
            keeper.otherNames = merged(keeper.otherNames, [duplicate.name] + duplicate.otherNames, excluding: keeper.name)
            keeper.absorbed = keeper.absorbed + inherited + [entry]
            context.delete(duplicate)
        }
        try context.save()
    }

    static func combine(_ duplicates: [Vendor], into keeper: Vendor, in context: ModelContext) throws {
        for duplicate in duplicates where duplicate.id != keeper.id {
            let inherited = duplicate.absorbed
            let entry = AbsorbedEntry(
                name: duplicate.name,
                otherNames: duplicate.otherNames.filter { name in !inherited.contains { $0.name == name || $0.otherNames.contains(name) } },
                purchaseIDs: (duplicate.purchases ?? []).map(\.id).filter { id in !inherited.contains { $0.purchaseIDs.contains(id) } },
                notes: duplicate.notes,
                contactName: duplicate.contactName,
                phone: duplicate.phone,
                email: duplicate.email,
                address: duplicate.address
            )
            for purchase in duplicate.purchases ?? [] { purchase.vendor = keeper }
            if keeper.contactName.isEmpty { keeper.contactName = duplicate.contactName }
            if keeper.phone.isEmpty { keeper.phone = duplicate.phone }
            if keeper.email.isEmpty { keeper.email = duplicate.email }
            if keeper.address.isEmpty { keeper.address = duplicate.address }
            if keeper.notes.isEmpty { keeper.notes = duplicate.notes }
            keeper.otherNames = merged(keeper.otherNames, [duplicate.name] + duplicate.otherNames, excluding: keeper.name)
            keeper.absorbed = keeper.absorbed + inherited + [entry]
            context.delete(duplicate)
        }
        try context.save()
    }

    /// Brings an absorbed item back as its own entry, with the purchases and usage it arrived with.
    @discardableResult
    static func separate(_ entry: AbsorbedEntry, from keeper: Item, in context: ModelContext) throws -> Item {
        let restored = Item(
            name: entry.name,
            unit: UnitOfMeasure(rawValue: entry.unitRaw ?? "") ?? keeper.unit,
            reorderLevel: entry.reorderLevel ?? keeper.reorderLevel,
            isPerishable: entry.isPerishable ?? keeper.isPerishable,
            storageLocation: entry.storageLocation ?? "",
            notes: entry.notes
        )
        context.insert(restored)
        restored.otherNames = entry.otherNames
        for purchase in keeper.purchases ?? [] where entry.purchaseIDs.contains(purchase.id) { purchase.item = restored }
        for record in keeper.usageRecords ?? [] where entry.usageIDs.contains(record.id) { record.item = restored }
        release(entry, otherNames: &keeper.otherNames, absorbed: &keeper.absorbed)
        try context.save()
        return restored
    }

    @discardableResult
    static func separate(_ entry: AbsorbedEntry, from keeper: Vendor, in context: ModelContext) throws -> Vendor {
        let restored = Vendor(
            name: entry.name,
            contactName: entry.contactName ?? "",
            phone: entry.phone ?? "",
            email: entry.email ?? "",
            address: entry.address ?? "",
            notes: entry.notes
        )
        context.insert(restored)
        restored.otherNames = entry.otherNames
        for purchase in keeper.purchases ?? [] where entry.purchaseIDs.contains(purchase.id) { purchase.vendor = restored }
        release(entry, otherNames: &keeper.otherNames, absorbed: &keeper.absorbed)
        try context.save()
        return restored
    }

    private static func release(_ entry: AbsorbedEntry, otherNames: inout [String], absorbed: inout [AbsorbedEntry]) {
        let released = Set(([entry.name] + entry.otherNames).map { $0.lowercased() })
        otherNames = otherNames.filter { !released.contains($0.lowercased()) }
        absorbed = absorbed.filter { $0.name != entry.name }
    }

    private static func merged(_ existing: [String], _ added: [String], excluding keeperName: String) -> [String] {
        var seen = Set([keeperName.lowercased()])
        return (existing + added).filter { seen.insert($0.lowercased()).inserted }
    }
}

/// Finds entries that are probably the same thing under different names.
nonisolated enum DuplicateDetector {
    static let dismissedKey = "dismissedDuplicateGroups"

    struct Candidate {
        var id: String
        var name: String
        var productNumbers: Set<String> = []
        var purchases = 0
    }

    struct Group: Identifiable, Equatable {
        /// The entry with the most purchases comes first and is the suggested one to keep.
        var ids: [String]

        var id: String { ids.sorted().joined(separator: "|") }
    }

    static func itemGroups(_ candidates: [Candidate], dismissed: Set<String> = []) -> [Group] {
        groups(candidates, dismissed: dismissed) { first, second in
            if !first.productNumbers.isDisjoint(with: second.productNumbers) { return true }
            let firstWords = NameSimilarity.words(in: first.name)
            let secondWords = NameSimilarity.words(in: second.name)
            guard let lead = firstWords.first, lead == secondWords.first else { return false }
            let shared = Set(firstWords).intersection(secondWords).count
            let smaller = min(Set(firstWords).count, Set(secondWords).count)
            guard shared >= 2, Double(shared) / Double(smaller) >= 0.6 else { return false }
            let firstSizes = Set(firstWords.filter { $0.contains(where: \.isNumber) })
            let secondSizes = Set(secondWords.filter { $0.contains(where: \.isNumber) })
            return firstSizes.isEmpty || secondSizes.isEmpty || !firstSizes.isDisjoint(with: secondSizes)
        }
    }

    static func vendorGroups(_ candidates: [Candidate], dismissed: Set<String> = []) -> [Group] {
        groups(candidates, dismissed: dismissed) { first, second in
            let firstWords = NameSimilarity.words(in: first.name)
            let secondWords = NameSimilarity.words(in: second.name)
            guard let lead = firstWords.first, lead == secondWords.first else { return false }
            return Set(firstWords).isSubset(of: secondWords) || Set(secondWords).isSubset(of: firstWords)
        }
    }

    private static func groups(_ candidates: [Candidate], dismissed: Set<String>, isMatch: (Candidate, Candidate) -> Bool) -> [Group] {
        var parent = Array(candidates.indices)
        func root(_ index: Int) -> Int {
            var index = index
            while parent[index] != index { index = parent[index] }
            return index
        }
        for first in candidates.indices {
            for second in candidates.indices where second > first && root(first) != root(second) && isMatch(candidates[first], candidates[second]) {
                parent[root(second)] = root(first)
            }
        }
        return Dictionary(grouping: candidates.indices, by: root).values
            .filter { $0.count > 1 }
            .map { members in
                Group(ids: members.map { candidates[$0] }
                    .sorted { ($1.purchases, $0.name) < ($0.purchases, $1.name) }
                    .map(\.id))
            }
            .filter { !dismissed.contains($0.id) }
            .sorted { $0.id < $1.id }
    }

    static func dismissed(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: dismissedKey) ?? [])
    }

    static func dismiss(_ group: Group, in defaults: UserDefaults = .standard) {
        defaults.set(Array(dismissed(in: defaults).union([group.id])), forKey: dismissedKey)
    }
}
