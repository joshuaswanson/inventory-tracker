import Foundation
import SwiftData

nonisolated struct RawOrderLine: Decodable {
    var date: String
    var vendor: String
    var suborderNumber: String
    var name: String
    var manuCode: String
    var quantity: String
    var unitPrice: String
    var status: String
}

nonisolated struct OrderLine: Equatable {
    var date: String?
    var vendor: String
    var suborderNumber: String
    var name: String
    var manuCode: String
    var quantity: Int?
    var unitPrice: Double?
    var status: String

    init(raw: RawOrderLine) {
        date = SupplyClinicText.date(raw.date)
        vendor = SupplyClinicText.stripping(raw.vendor, labels: ["Items from"])
        suborderNumber = SupplyClinicText.stripping(raw.suborderNumber, labels: ["#"])
        name = raw.name
        manuCode = SupplyClinicText.stripping(raw.manuCode, labels: ["Manu Code:"])
        quantity = SupplyClinicText.quantity(raw.quantity)
        unitPrice = SupplyClinicText.money(raw.unitPrice)
        status = SupplyClinicText.stripping(raw.status, labels: ["Status:"])
    }

    var isImportable: Bool {
        let lowered = status.lowercased()
        if lowered.contains("cancel") || lowered.contains("return") { return false }
        return date != nil && !name.isEmpty && (quantity ?? 0) > 0 && unitPrice != nil
    }

    var sourceID: String {
        "supplyclinic:\(suborderNumber):\(manuCode.isEmpty ? name : manuCode)"
    }
}

nonisolated enum SupplyClinicText {
    static func stripping(_ text: String, labels: [String]) -> String {
        labels.reduce(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            $0.replacingOccurrences(of: $1, with: "")
        }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func date(_ text: String) -> String? {
        guard let match = text.firstMatch(of: /(\d{2})\/(\d{2})\/(\d{4})/) else { return nil }
        return "\(match.3)-\(match.1)-\(match.2)"
    }

    static func money(_ text: String) -> Double? {
        guard let match = text.firstMatch(of: /\$([\d,]+\.\d{2})/) else { return nil }
        return Double(match.1.replacingOccurrences(of: ",", with: ""))
    }

    static func quantity(_ text: String) -> Int? {
        text.firstMatch(of: /\d+/).flatMap { Int($0.output) }
    }

    static func unit(for name: String) -> UnitOfMeasure {
        let lowered = name.lowercased()
        if lowered.contains(/\/\s*(cs|case)\b/) || lowered.contains("case") { return .case }
        if lowered.contains(/\/\s*bx\b/) || lowered.contains("box") { return .box }
        if lowered.contains("/pk") || lowered.contains("pkg") || lowered.contains("pack") { return .pack }
        if lowered.contains("bottle") { return .bottle }
        if lowered.contains("bag") { return .bag }
        if lowered.contains("roll") { return .roll }
        return .each
    }

    static func isChallengePage(_ markup: String) -> Bool {
        ["challenge-platform", "Just a moment", "cf-challenge", "Attention Required"].contains { markup.contains($0) }
    }

    static func isSignInPage(url: String, markup: String) -> Bool {
        url.contains("/users/sign_in") || markup.contains("name=\"user[password]\"")
    }
}

nonisolated struct OrderImportSummary: Equatable {
    var imported = 0
    var duplicates = 0
    var skipped = 0
    var newItems = 0
    var newVendors = 0
    var newItemIDs: [String] = []
}

enum SupplyClinicMerge {
    private static let importNote = "Imported from SupplyClinic"
    private static let importedReorderLevel = 2

    @discardableResult
    static func merge(_ lines: [OrderLine], into context: ModelContext, today: String = Day.today) throws -> OrderImportSummary {
        var summary = OrderImportSummary()
        var itemsByName = Dictionary(try context.fetch(FetchDescriptor<Item>()).map { ($0.name.lowercased(), $0) }) { first, _ in first }
        var vendorsByName = Dictionary(try context.fetch(FetchDescriptor<Vendor>()).map { ($0.name.lowercased(), $0) }) { first, _ in first }
        var seenSources = Set(try context.fetch(FetchDescriptor<Purchase>()).compactMap(\.sourceId))

        for line in lines {
            guard line.isImportable, let date = line.date, let quantity = line.quantity, let unitPrice = line.unitPrice else {
                summary.skipped += 1
                continue
            }
            guard !seenSources.contains(line.sourceID) else {
                summary.duplicates += 1
                continue
            }

            var vendor = vendorsByName[line.vendor.lowercased()]
            if vendor == nil, !line.vendor.isEmpty {
                let created = Vendor(name: line.vendor, notes: importNote, createdAt: today)
                context.insert(created)
                vendorsByName[line.vendor.lowercased()] = created
                vendor = created
                summary.newVendors += 1
            }

            let item: Item
            if let existing = itemsByName[line.name.lowercased()] {
                item = existing
            } else {
                item = Item(
                    name: line.name,
                    unit: SupplyClinicText.unit(for: line.name),
                    reorderLevel: importedReorderLevel,
                    notes: importNote,
                    createdAt: today
                )
                context.insert(item)
                itemsByName[line.name.lowercased()] = item
                summary.newItems += 1
                summary.newItemIDs.append(item.id)
            }

            let purchase = Purchase(date: date, item: nil, quantity: quantity, pricePerUnit: unitPrice)
            context.insert(purchase)
            purchase.item = item
            purchase.vendor = vendor
            purchase.productNumber = line.manuCode
            purchase.notes = "SupplyClinic order \(line.suborderNumber)"
            purchase.sourceId = line.sourceID
            seenSources.insert(line.sourceID)
            summary.imported += 1
        }

        try context.save()
        return summary
    }
}
