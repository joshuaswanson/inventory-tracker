import Foundation
import SwiftData

enum InventoryStore {
    static let schema = Schema([Item.self, Vendor.self, Purchase.self, UsageRecord.self])

    private static var usesEphemeralStore: Bool {
        let environment = ProcessInfo.processInfo.environment
        #if DEBUG
        if environment["INVENTORY_EPHEMERAL"] != nil { return true }
        #endif
        return environment["XCTestConfigurationFilePath"] != nil
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory || usesEphemeralStore,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
