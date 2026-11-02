import Foundation
import Testing
@testable import InventoryTracker

private struct ParityFixture: Decodable {
    struct FixturePurchase: Decodable {
        var id: String
        var date: String
        var quantity: Int
        var pricePerUnit: Double
        var expirationDate: String?
        var vendorId: String?
    }

    struct FixtureUsage: Decodable {
        var date: String
        var quantity: Int
        var purchaseId: String?
        var isAdjustment: Bool
    }

    struct Expected: Decodable {
        var currentInventory: Int
        var needsReorder: Bool
        var lowestPrice: Double?
        var averagePrice: Double?
        var bestPriceVendor: String?
        var usageRatePerDay: Double
        var daysUntilReorder: Int?
        var nextExpiration: String?
        var daysUntilExpiration: Int?
        var expirationIsEstimated: Bool
        var batchRemaining: [String: Int]
    }

    struct FixtureItem: Decodable {
        var id: String
        var reorderLevel: Int
        var isPerishable: Bool
        var purchases: [FixturePurchase]
        var usage: [FixtureUsage]
        var expected: Expected
    }

    var today: String
    var vendorName: String
    var items: [FixtureItem]
}

@Suite struct MetricsParityTests {
    private func fixture() throws -> ParityFixture {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "metrics-parity", withExtension: "json"))
        return try JSONDecoder().decode(ParityFixture.self, from: Data(contentsOf: url))
    }

    @Test func metricsMatchTheReferenceResultsForEveryFixtureItem() throws {
        let parity = try fixture()
        #expect(parity.items.count >= 13)

        for item in parity.items {
            let metrics = ItemMetrics(
                reorderLevel: item.reorderLevel,
                isPerishable: item.isPerishable,
                purchases: item.purchases.map {
                    PurchaseFact(
                        id: $0.id,
                        day: $0.date,
                        quantity: $0.quantity,
                        pricePerUnit: $0.pricePerUnit,
                        expirationDate: $0.expirationDate,
                        vendorName: $0.vendorId == nil ? nil : parity.vendorName
                    )
                },
                usage: item.usage.map { UsageFact(day: $0.date, quantity: $0.quantity, batchID: $0.purchaseId, isAdjustment: $0.isAdjustment) },
                today: parity.today
            )
            let expected = item.expected
            #expect(metrics.currentInventory == expected.currentInventory, "\(item.id)")
            #expect(metrics.needsReorder == expected.needsReorder, "\(item.id)")
            #expect(metrics.lowestPrice == expected.lowestPrice, "\(item.id)")
            #expect(metrics.averagePrice == expected.averagePrice, "\(item.id)")
            #expect(metrics.bestPriceVendor == expected.bestPriceVendor, "\(item.id)")
            #expect(metrics.usageRatePerDay == expected.usageRatePerDay, "\(item.id)")
            #expect(metrics.daysUntilReorder == expected.daysUntilReorder, "\(item.id)")
            #expect(metrics.nextExpiration == expected.nextExpiration, "\(item.id)")
            #expect(metrics.daysUntilExpiration == expected.daysUntilExpiration, "\(item.id)")
            #expect(metrics.expirationIsEstimated == expected.expirationIsEstimated, "\(item.id)")
            #expect(
                Dictionary(uniqueKeysWithValues: metrics.batches.map { ($0.id, $0.remaining) }) == expected.batchRemaining,
                "\(item.id)"
            )
        }
    }
}

private final class BundleToken {}
