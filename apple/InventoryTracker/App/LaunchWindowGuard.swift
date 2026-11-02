#if os(macOS)
import AppKit
import OSLog

/// macOS occasionally finishes launching the app without creating its window, most often right
/// after an install. Opening the app a second time always creates one, so the app does that itself.
final class LaunchWindowGuard: NSObject, NSApplicationDelegate {
    private static let settleDelay = Duration.seconds(1)
    private let logger = Logger(subsystem: "com.joshuaswanson.inventorytracker", category: "launch")

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            try? await Task.sleep(for: Self.settleDelay)
            guard !NSApp.windows.contains(where: \.isVisible) else { return }
            logger.notice("Launched without a window, requesting one")
            _ = try? await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
#endif
