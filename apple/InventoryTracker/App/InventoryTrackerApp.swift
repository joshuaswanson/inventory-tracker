import SwiftData
import SwiftUI

@main
struct InventoryTrackerApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(LaunchWindowGuard.self) private var launchWindowGuard
    @State private var updateChecker = UpdateChecker()
    #endif
    @State private var router = Router()
    private let store = Result { try InventoryStore.makeContainer() }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                AppShell()
                    .environment(router)
                    .modelContainer(container)
                    .preferredColorScheme(.light)
                    .tint(Theme.primary)
                    #if os(macOS)
                    .environment(updateChecker)
                    .task { await updateChecker.run() }
                    #endif
                    #if DEBUG
                    .task { DebugLaunch.apply(context: container.mainContext, router: router) }
                    #endif
            case .failure(let error):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't open your inventory",
                    message: error.localizedDescription
                )
            }
        }
        #if os(macOS)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Item") { router.sheet = .item(nil) }
                    .keyboardShortcut("n")
                Button("New Purchase") { router.sheet = .purchase(nil, itemID: nil) }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Record Usage") { router.sheet = .usage(nil, itemID: nil) }
                    .keyboardShortcut("u", modifiers: [.command, .shift])
            }
            CommandMenu("Go") {
                ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.title) { router.show(section) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                }
            }
        }
        #endif
    }
}
