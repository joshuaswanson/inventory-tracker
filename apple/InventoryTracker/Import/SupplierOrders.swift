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

/// Some sites answer a page number past the end with their last page again.
nonisolated struct OrderPaging {
    private var seenPages: Set<String> = []

    mutating func isNewPage(_ lines: [OrderLine]) -> Bool {
        !lines.isEmpty && seenPages.insert(String(describing: lines)).inserted
    }
}

nonisolated struct CollectedOrders: Decodable {
    var signedOut: Bool?
    var ordersFound: Int
    var lines: [RawOrderLine]
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
        date = OrderText.date(raw.date)
        vendor = OrderText.decodingEntities(OrderText.stripping(raw.vendor, labels: ["Items from"]))
        suborderNumber = OrderText.stripping(raw.suborderNumber, labels: ["#"])
        name = OrderText.decodingEntities(raw.name)
        manuCode = OrderText.stripping(raw.manuCode, labels: ["Manu Code:"])
        quantity = OrderText.quantity(raw.quantity)
        unitPrice = OrderText.money(raw.unitPrice)
        status = OrderText.stripping(raw.status, labels: ["Status:"])
    }

    var isImportable: Bool {
        let lowered = status.lowercased()
        if ["cancel", "return", "refund", "declined"].contains(where: lowered.contains) { return false }
        return date != nil && !name.isEmpty && (quantity ?? 0) > 0 && unitPrice != nil
    }

    func sourceID(for supplier: Supplier) -> String {
        "\(supplier.id):\(suborderNumber):\(manuCode.isEmpty ? name : manuCode)"
    }
}

nonisolated enum OrderText {
    static func stripping(_ text: String, labels: [String]) -> String {
        labels.reduce(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            $0.replacingOccurrences(of: $1, with: "")
        }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Some sites escape product names twice, so "&amp;" survives into the page's text.
    static func decodingEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let named = ["&amp;": "&", "&quot;": "\"", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&reg;": "®", "&trade;": "™"]
        var decoded = named.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value, options: .caseInsensitive) }
        decoded.replace(/&#(\d+);/) { match in
            Int(match.1).flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? String(match.0)
        }
        return decoded
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

    /// Ordinary pages on Cloudflare sites also load a script from `/cdn-cgi/challenge-platform/`.
    static func isChallengePage(_ markup: String) -> Bool {
        ["_cf_chl_opt", "<title>Just a moment", "cf-challenge", "<title>Attention Required"].contains { markup.contains($0) }
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

nonisolated enum ImportWarning {
    /// An import that reads nothing looks the same as a quiet month unless the app says so.
    static func message(linesRead: Int, summary: OrderImportSummary, previouslyImported: Int, supplierName: String) -> String? {
        if linesRead == 0, previouslyImported > 0 {
            return "No orders were found on \(supplierName), but you have imported from it before. The site has probably changed. Nothing in your inventory was changed. Please tell the person who set up this app."
        }
        if linesRead == 0 {
            return "No orders were found on \(supplierName). If you have ordered from it before, the site may have changed. Please tell the person who set up this app."
        }
        if summary.skipped == linesRead {
            return "\(linesRead) orders were found on \(supplierName), but none could be read. The site has probably changed. Please tell the person who set up this app."
        }
        return nil
    }

    static func previouslyImported(from supplier: Supplier, in context: ModelContext) -> Int {
        knownOrders(from: supplier, in: context).count
    }

    /// Order numbers already imported from this supplier, read from the middle of each source ID.
    static func knownOrders(from supplier: Supplier, in context: ModelContext) -> Set<String> {
        let purchases = (try? context.fetch(FetchDescriptor<Purchase>())) ?? []
        let prefix = "\(supplier.id):"
        return Set(purchases.compactMap { purchase in
            guard let source = purchase.sourceId, source.hasPrefix(prefix) else { return nil }
            return source.dropFirst(prefix.count).split(separator: ":").first.map(String.init)
        })
    }
}

enum OrderMerge {
    private static let importedReorderLevel = 0

    @discardableResult
    static func merge(_ lines: [OrderLine], from supplier: Supplier, into context: ModelContext, today: String = Day.today) throws -> OrderImportSummary {
        var summary = OrderImportSummary()
        var occurrences: [String: Int] = [:]
        var itemsByName = Dictionary(try context.fetch(FetchDescriptor<Item>()).flatMap { item in ([item.name] + item.otherNames).map { ($0.lowercased(), item) } }) { first, _ in first }
        var vendorsByName = Dictionary(try context.fetch(FetchDescriptor<Vendor>()).flatMap { vendor in ([vendor.name] + vendor.otherNames).map { ($0.lowercased(), vendor) } }) { first, _ in first }
        var seenSources = Set(try context.fetch(FetchDescriptor<Purchase>()).compactMap(\.sourceId))

        for line in lines {
            guard line.isImportable, let date = line.date, let quantity = line.quantity, let unitPrice = line.unitPrice else {
                summary.skipped += 1
                continue
            }
            let baseID = line.sourceID(for: supplier)
            let occurrence = occurrences[baseID, default: 0] + 1
            occurrences[baseID] = occurrence
            let sourceID = occurrence == 1 ? baseID : "\(baseID)#\(occurrence)"
            guard !seenSources.contains(sourceID) else {
                summary.duplicates += 1
                continue
            }

            var vendor = vendorsByName[line.vendor.lowercased()]
            if vendor == nil, !line.vendor.isEmpty {
                let created = Vendor(name: line.vendor, createdAt: today)
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
                    unit: OrderText.unit(for: line.name),
                    reorderLevel: importedReorderLevel,
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
            purchase.notes = "\(supplier.name) order \(line.suborderNumber)"
            purchase.sourceId = sourceID
            seenSources.insert(sourceID)
            summary.imported += 1
        }

        try context.save()
        return summary
    }
}
