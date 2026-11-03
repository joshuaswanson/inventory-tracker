import Foundation
import Testing
@testable import InventoryTracker

private let release = AppRelease(version: "1.1", pageURL: URL(string: "https://example.com/v1.1")!)

private func makeDefaults() -> UserDefaults {
    let name = "tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private final class FetchCounter {
    var count = 0
}

@Suite struct AppVersionTests {
    @Test func comparesNumerically() {
        #expect(AppVersion.isNewer("1.10", than: "1.9"))
        #expect(AppVersion.isNewer("2.0", than: "1.9.9"))
        #expect(AppVersion.isNewer("v1.1", than: "1.0"))
        #expect(!AppVersion.isNewer("1.9", than: "1.10"))
    }

    @Test func equalVersionsAreNotNewer() {
        #expect(!AppVersion.isNewer("1.0", than: "1.0"))
        #expect(!AppVersion.isNewer("1.0", than: "1.0.0"))
        #expect(!AppVersion.isNewer("v1.0", than: "1.0"))
    }
}

@Suite struct GitHubReleasesTests {
    @Test func decodesTheLatestRelease() throws {
        let json = #"{"tag_name":"v1.2","html_url":"https://github.com/o/r/releases/tag/v1.2","draft":false,"assets":[]}"#
        let decoded = try GitHubReleases.decode(Data(json.utf8))
        #expect(decoded.version == "1.2")
        #expect(decoded.pageURL.absoluteString == "https://github.com/o/r/releases/tag/v1.2")
    }
}

@Suite struct UpdateCheckerTests {
    @Test func newerReleaseIsShown() async {
        let checker = UpdateChecker(currentVersion: "1.0", defaults: makeDefaults(), fetchLatest: { release })
        await checker.checkIfDue()
        #expect(checker.available == release)
    }

    @Test func sameVersionShowsNothing() async {
        let checker = UpdateChecker(currentVersion: "1.1", defaults: makeDefaults(), fetchLatest: { release })
        await checker.checkIfDue()
        #expect(checker.available == nil)
    }

    @Test func noReleasesAndFailuresShowNothing() async {
        let none = UpdateChecker(currentVersion: "1.0", defaults: makeDefaults(), fetchLatest: { nil })
        await none.checkIfDue()
        #expect(none.available == nil)

        let failing = UpdateChecker(currentVersion: "1.0", defaults: makeDefaults(), fetchLatest: { throw URLError(.notConnectedToInternet) })
        await failing.checkIfDue()
        #expect(failing.available == nil)
    }

    @Test func checksAtMostOncePerDay() async {
        let defaults = makeDefaults()
        let counter = FetchCounter()
        var time = Date(timeIntervalSince1970: 1_000_000)
        let checker = UpdateChecker(currentVersion: "1.0", defaults: defaults, now: { time }, fetchLatest: {
            counter.count += 1
            return release
        })
        await checker.checkIfDue()
        time += UpdateChecker.checkInterval - 60
        await checker.checkIfDue()
        #expect(counter.count == 1)
        time += 120
        await checker.checkIfDue()
        #expect(counter.count == 2)
    }

    @Test func failedCheckRetriesSoon() async {
        let counter = FetchCounter()
        let checker = UpdateChecker(currentVersion: "1.0", defaults: makeDefaults(), fetchLatest: {
            counter.count += 1
            throw URLError(.timedOut)
        })
        await checker.checkIfDue()
        await checker.checkIfDue()
        #expect(counter.count == 2)
    }

    @Test func foundUpdateSurvivesARelaunchWithoutANewCheck() async {
        let defaults = makeDefaults()
        let first = UpdateChecker(currentVersion: "1.0", defaults: defaults, fetchLatest: { release })
        await first.checkIfDue()
        let relaunched = UpdateChecker(currentVersion: "1.0", defaults: defaults, fetchLatest: { nil })
        #expect(relaunched.available == release)
    }

    @Test func installedUpdateClearsTheBanner() async {
        let defaults = makeDefaults()
        let before = UpdateChecker(currentVersion: "1.0", defaults: defaults, fetchLatest: { release })
        await before.checkIfDue()
        let after = UpdateChecker(currentVersion: "1.1", defaults: defaults, fetchLatest: { release })
        #expect(after.available == nil)
    }

    @Test func dismissHidesThatVersionButNotTheNextOne() async {
        let defaults = makeDefaults()
        var time = Date(timeIntervalSince1970: 1_000_000)
        var latest = release
        let checker = UpdateChecker(currentVersion: "1.0", defaults: defaults, now: { time }, fetchLatest: { latest })
        await checker.checkIfDue()
        checker.dismiss()
        #expect(checker.available == nil)

        let relaunched = UpdateChecker(currentVersion: "1.0", defaults: defaults, now: { time }, fetchLatest: { latest })
        #expect(relaunched.available == nil)

        latest = AppRelease(version: "1.2", pageURL: release.pageURL)
        time += UpdateChecker.checkInterval + 1
        await relaunched.checkIfDue()
        #expect(relaunched.available?.version == "1.2")
    }
}
