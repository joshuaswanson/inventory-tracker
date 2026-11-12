import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataView: View {
    private enum FilePicker {
        case backup, folder
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router
    @Environment(\.checkForUpdates) private var checkForUpdates
    @Query private var items: [Item]
    @AppStorage(Reminders.enabledKey) private var remindersEnabled = false
    @State private var picker = FilePicker.backup
    @State private var isPicking = false
    @State private var isExporting = false
    @State private var exportDocument: BackupDocument?
    @State private var lastBackup = BackupFiles.latestDate(in: AutoBackup.folder)
    @State private var extraFolderName: String?
    @State private var message: String?
    @State private var messageIsError = false

    private var backupDetail: String {
        guard let lastBackup else {
            return "Saved automatically every day once you add items."
        }
        return "Saved automatically every day. Last backup: \(lastBackup.formatted(date: .abbreviated, time: .shortened))."
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        FormSheet(title: "Settings", saveTitle: "Done", showsCancel: false, macWidth: 860, fitsContentOnMac: true, onSave: { dismiss() }) {
            if let message {
                Label(message, systemImage: messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(messageIsError ? Theme.redDark : Theme.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(messageIsError ? Theme.redLight : Theme.greenLight, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            }

            #if os(macOS)
            HStack(alignment: .top, spacing: 16) {
                backupsCard
                    .frame(maxWidth: .infinity)
                VStack(spacing: 16) { otherCards }
                    .frame(maxWidth: .infinity)
            }
            #else
            backupsCard
            otherCards
            #endif
        }
        .task {
            #if os(macOS)
            extraFolderName = ExtraBackupFolder.name
            #endif
        }
        .fileImporter(
            isPresented: $isPicking,
            allowedContentTypes: picker == .folder ? [.folder] : [.json, .folder],
            allowsMultipleSelection: picker == .backup,
            onCompletion: picked
        )
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "inventory-backup-\(Day.today)"
        ) { result in
            if case .failure(let error) = result {
                show(error.localizedDescription, isError: true)
            } else {
                show("Backup saved.", isError: false)
            }
        }
    }

    private var backupsCard: some View {
        card("Backups", systemImage: "externaldrive.fill", tone: .green, detail: backupDetail) {
            HStack(spacing: 8) {
                Button("Save a Copy", action: export)
                    .buttonStyle(.themedSecondary)
                #if os(macOS)
                Button("Show Backups") {
                    try? FileManager.default.createDirectory(at: AutoBackup.folder, withIntermediateDirectories: true)
                    NSWorkspace.shared.activateFileViewerSelecting([AutoBackup.folder])
                }
                .buttonStyle(.themedSecondary)
                #endif
            }
            #if os(macOS)
            Divider().overlay(Theme.borderLight)
            extraFolder
            #endif
            Divider().overlay(Theme.borderLight)
            row("Restore from a backup", detail: "Brings records back from a backup file. Nothing you have now is deleted.") {
                Button("Choose Backup File") { pick(.backup) }
                    .buttonStyle(.themedSecondary)
            }
        }
    }

    @ViewBuilder
    private var otherCards: some View {
        card("Reminders", systemImage: "bell.fill", tone: .amber, detail: "Get a notification before items expire or run low.") {
            Toggle("Remind me", isOn: reminders)
                .toggleStyle(.switch)
                .tint(Theme.primary)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
        }

        if let checkForUpdates {
            card("Updates", systemImage: "arrow.down.circle.fill", tone: .blue, detail: "You have version \(version). The app also checks for new versions by itself.") {
                Button("Check for Updates", action: checkForUpdates)
                    .buttonStyle(.themedSecondary)
            }
        }

        card("Help", systemImage: "lightbulb.fill", tone: .purple, detail: "A short tour shows where everything is.") {
            HStack(spacing: 8) {
                Button("Take the Tour") { Tour.start(router: router, context: modelContext) }
                    .buttonStyle(.themedSecondary)
                if SampleData.hasSamples(in: items) {
                    Button("Remove Practice Items", action: removeSamples)
                        .buttonStyle(.themedSecondary)
                }
            }
        }
    }

    #if os(macOS)
    @ViewBuilder
    private var extraFolder: some View {
        if let extraFolderName {
            row("Second copy", detail: "Also saved to the \"\(extraFolderName)\" folder.") {
                Button("Stop Saving There") {
                    ExtraBackupFolder.clear()
                    self.extraFolderName = nil
                }
                .buttonStyle(.themedSecondary)
            }
        } else {
            row("Second copy", detail: "In case this Mac is lost or breaks, keep another copy in iCloud Drive or on another drive.") {
                Button("Choose a Folder") { pick(.folder) }
                    .buttonStyle(.themedSecondary)
            }
        }
    }
    #endif

    private var reminders: Binding<Bool> {
        Binding(
            get: { remindersEnabled },
            set: { isOn in
                Task {
                    let allowed = isOn ? await Reminders.requestPermission() : false
                    remindersEnabled = allowed
                    if isOn, !allowed {
                        show("Allow notifications for Inventory Tracker in System Settings, then try again.", isError: true)
                    }
                    await Reminders.reschedule(context: modelContext)
                }
            }
        )
    }

    private func card<Content: View>(_ title: String, systemImage: String, tone: Tone, detail: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(tone.icon)
                .frame(width: 36, height: 36)
                .background(tone.background, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.border))
    }

    private func row<Trailing: View>(_ title: String, detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                rowText(title, detail: detail)
                trailing().fixedSize()
            }
            VStack(alignment: .leading, spacing: 8) {
                rowText(title, detail: detail)
                trailing()
            }
        }
    }

    private func rowText(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pick(_ kind: FilePicker) {
        picker = kind
        isPicking = true
    }

    private func export() {
        do {
            exportDocument = BackupDocument(data: try BackupMerge.export(from: modelContext).encoded())
            isExporting = true
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func picked(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            switch picker {
            case .backup:
                let summary = try BackupMerge.merge(try Backup.load(from: urls), into: modelContext)
                show("Restored. \(summary.added) added, \(summary.updated) updated.", isError: false)
            case .folder:
                #if os(macOS)
                guard let folder = urls.first else { return }
                try ExtraBackupFolder.choose(folder)
                extraFolderName = ExtraBackupFolder.name
                AutoBackup.run(context: modelContext)
                lastBackup = BackupFiles.latestDate(in: AutoBackup.folder)
                #endif
            }
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func removeSamples() {
        do {
            try SampleData.remove(from: modelContext)
            show("Practice items removed.", isError: false)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}
