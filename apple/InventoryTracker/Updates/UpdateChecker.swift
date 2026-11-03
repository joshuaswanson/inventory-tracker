import Foundation
import Observation

nonisolated struct AppRelease: Equatable {
    var version: String
    var pageURL: URL
}

nonisolated enum AppVersion {
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = parts(of: candidate)
        let currentParts = parts(of: current)
        for index in 0..<max(candidateParts.count, currentParts.count) {
            let first = index < candidateParts.count ? candidateParts[index] : 0
            let second = index < currentParts.count ? currentParts[index] : 0
            if first != second { return first > second }
        }
        return false
    }

    private static func parts(of version: String) -> [Int] {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}

nonisolated enum GitHubReleases {
    private static let latestURL = URL(string: "https://api.github.com/repos/joshuaswanson/inventory-tracker/releases/latest")!

    private struct Payload: Decodable {
        var tag_name: String
        var html_url: URL
    }

    static func decode(_ data: Data) throws -> AppRelease {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let version = payload.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        return AppRelease(version: version, pageURL: payload.html_url)
    }

    /// GitHub answers 404 until the first release exists.
    static func latest() async throws -> AppRelease? {
        var request = URLRequest(url: latestURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("InventoryTracker/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard status == 200 else { throw URLError(.badServerResponse) }
        return try decode(data)
    }
}

@Observable
final class UpdateChecker {
    static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let retryInterval = Duration.seconds(6 * 60 * 60)

    private enum Key {
        static let lastCheck = "updateLastCheck"
        static let latestVersion = "updateLatestVersion"
        static let latestPage = "updateLatestPage"
        static let dismissedVersion = "updateDismissedVersion"
    }

    private(set) var available: AppRelease?
    @ObservationIgnored private let currentVersion: String
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let fetchLatest: () async throws -> AppRelease?

    init(
        currentVersion: String = AppVersion.current,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        fetchLatest: @escaping () async throws -> AppRelease? = GitHubReleases.latest
    ) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.now = now
        self.fetchLatest = fetchLatest
        if let version = defaults.string(forKey: Key.latestVersion),
           let page = defaults.string(forKey: Key.latestPage).flatMap(URL.init(string:)) {
            show(AppRelease(version: version, pageURL: page))
        }
    }

    func run() async {
        while !Task.isCancelled {
            await checkIfDue()
            try? await Task.sleep(for: Self.retryInterval)
        }
    }

    func checkIfDue() async {
        let lastCheck = defaults.object(forKey: Key.lastCheck) as? Date
        if let lastCheck, now().timeIntervalSince(lastCheck) < Self.checkInterval { return }
        guard let release = try? await fetchLatest() else { return }
        defaults.set(now(), forKey: Key.lastCheck)
        defaults.set(release.version, forKey: Key.latestVersion)
        defaults.set(release.pageURL.absoluteString, forKey: Key.latestPage)
        show(release)
    }

    func dismiss() {
        defaults.set(available?.version, forKey: Key.dismissedVersion)
        available = nil
    }

    private func show(_ release: AppRelease) {
        let isDismissed = defaults.string(forKey: Key.dismissedVersion) == release.version
        available = AppVersion.isNewer(release.version, than: currentVersion) && !isDismissed ? release : nil
    }
}
