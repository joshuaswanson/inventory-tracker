import SwiftUI
import SwiftData

// Wrapper types to distinguish between Item and Vendor windows
struct ItemWindowID: Hashable, Codable {
    let id: UUID
}

struct VendorWindowID: Hashable, Codable {
    let id: UUID
}

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
        WindowGroup("Item", for: ItemWindowID.self) { $windowID in
            if let windowID {
                ItemWindowView(itemID: windowID.id)
                    .modelContainer(sharedModelContainer)
            }
        }
        .defaultSize(width: 600, height: 500)

        WindowGroup("Vendor", for: VendorWindowID.self) { $windowID in
            if let windowID {
                VendorWindowView(vendorID: windowID.id)
                    .modelContainer(sharedModelContainer)
            }
        }
        .defaultSize(width: 600, height: 500)
        #endif
    }
}
