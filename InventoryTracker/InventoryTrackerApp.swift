import SwiftUI
import SwiftData

@main
struct InventoryTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Vendor.self,
            Purchase.self,
            Usage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 900, height: 600)
        #endif

        #if os(macOS)
        WindowGroup("Item", for: Item.ID.self) { $itemID in
            if let itemID {
                ItemWindowView(itemID: itemID)
                    .modelContainer(sharedModelContainer)
            }
        }
        .defaultSize(width: 600, height: 500)

        WindowGroup("Vendor", for: Vendor.ID.self) { $vendorID in
            if let vendorID {
                VendorWindowView(vendorID: vendorID)
                    .modelContainer(sharedModelContainer)
            }
        }
        .defaultSize(width: 600, height: 500)
        #endif
    }
}
