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

    static var dataFolder: URL {
        #if os(macOS)
        URL.applicationSupportDirectory.appendingPathComponent("Inventory Tracker")
        #else
        URL.applicationSupportDirectory
        #endif
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory || usesEphemeralStore {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
        #if os(macOS)
        try FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(schema: schema, url: dataFolder.appendingPathComponent("Inventory.store"))
        #else
        let configuration = ModelConfiguration(schema: schema)
        #endif
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
