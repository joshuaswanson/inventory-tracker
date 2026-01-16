import Foundation
import SwiftData

@Model
final class Purchase {
    var id: UUID
    var date: Date
    var quantity: Int
    var pricePerUnit: Double
    var lotNumber: String
    var expirationDate: Date?
    var notes: String
    var usedQuantity: Int

    var item: Item?
    var vendor: Vendor?

    init(
        item: Item,
        vendor: Vendor?,
        date: Date = Date(),
        quantity: Int,
        pricePerUnit: Double,
        lotNumber: String = "",
        expirationDate: Date? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.item = item
        self.vendor = vendor
        self.date = date
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.lotNumber = lotNumber
        self.expirationDate = expirationDate
        self.notes = notes
        self.usedQuantity = 0
    }

    var totalCost: Double {
        Double(quantity) * pricePerUnit
    }

    var remainingQuantity: Int {
        quantity - usedQuantity
    }

    var isExpired: Bool {
        guard let expDate = expirationDate else { return false }
        return expDate < Date()
    }

    var daysUntilExpiration: Int? {
        guard let expDate = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expDate).day
    }

    var expirationStatus: ExpirationStatus {
        guard let days = daysUntilExpiration else { return .notApplicable }
        if days < 0 { return .expired }
        if days <= 7 { return .critical }
        if days <= 30 { return .warning }
        return .good
    }
}

enum ExpirationStatus: String {
    case expired = "Expired"
    case critical = "Expiring Soon"
    case warning = "Expiring Within 30 Days"
    case good = "Good"
    case notApplicable = "N/A"

    var color: String {
        switch self {
        case .expired: return "red"
        case .critical: return "orange"
        case .warning: return "yellow"
        case .good: return "green"
        case .notApplicable: return "gray"
        }
    }
}
