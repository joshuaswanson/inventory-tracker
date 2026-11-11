import Foundation
import SwiftData

nonisolated enum BackupFiles {
    static let keepCount = 30
    private static let prefix = "inventory-backup-"

    static func fileName(day: String) -> String { "\(prefix)\(day).json" }

    static func names(in folder: URL) -> [String] {
        let all = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return all.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }.sorted()
    }

    static func expired(among names: [String]) -> [String] {
        Array(names.sorted().dropLast(keepCount))
    }

    static func write(_ data: Data, day: String, to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appendingPathComponent(fileName(day: day)), options: .atomic)
        for name in expired(among: names(in: folder)) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    static func latestDate(in folder: URL) -> Date? {
        guard let newest = names(in: folder).last else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(newest).path)
        return attributes?[.modificationDate] as? Date
    }
}

enum AutoBackup {
    static var folder: URL {
        #if os(macOS)
        InventoryStore.dataFolder.appendingPathComponent("Backups")
        #else
        URL.documentsDirectory.appendingPathComponent("Backups")
        #endif
    }

    /// Rewrites today's file on every run, so the newest backup is at most one run old.
    static func run(context: ModelContext) {
        let itemCount = (try? context.fetchCount(FetchDescriptor<Item>())) ?? 0
        guard itemCount > 0, let data = try? BackupMerge.export(from: context).encoded() else { return }
        try? BackupFiles.write(data, day: Day.today, to: folder)
        #if os(macOS)
        ExtraBackupFolder.write(data, day: Day.today)
        #endif
    }
}

#if os(macOS)
enum ExtraBackupFolder {
    private static let key = "extraBackupFolderBookmark"

    static var name: String? { resolved()?.lastPathComponent }

    static func choose(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        UserDefaults.standard.set(try url.bookmarkData(options: .withSecurityScope), forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func write(_ data: Data, day: String) {
        guard let folder = resolved() else { return }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        try? BackupFiles.write(data, day: day, to: folder)
    }

    private static func resolved() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}
#endif
