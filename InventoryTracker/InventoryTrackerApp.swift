import SwiftUI
import SwiftData
import os

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
        .defaultSize(width: 1000, height: 600)
        .commands {
            CommandMenu("Developer") {
                Button("Reset to Sample Data") {
                    resetToSampleData()
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])

                Button("Clear All Data") {
                    clearAllData()
                }
            }
        }
        #endif
    }

    @MainActor
    private func clearAllData() {
        let context = sharedModelContainer.mainContext
        do {
            let usages = try context.fetch(FetchDescriptor<Usage>())
            for usage in usages { context.delete(usage) }

            let purchases = try context.fetch(FetchDescriptor<Purchase>())
            for purchase in purchases { context.delete(purchase) }

            let items = try context.fetch(FetchDescriptor<Item>())
            for item in items { context.delete(item) }

            let vendors = try context.fetch(FetchDescriptor<Vendor>())
            for vendor in vendors { context.delete(vendor) }

            try context.save()
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "InventoryTracker", category: "data")
                .error("Failed to clear data: \(error)")
        }
    }

    @MainActor
    private func resetToSampleData() {
        clearAllData()
        SampleData.populate(modelContext: sharedModelContainer.mainContext)
    }
}
