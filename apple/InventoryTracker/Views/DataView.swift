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
            return "Your inventory is backed up automatically every day once you add items."
        }
        return "Your inventory is backed up automatically every day. Last backup: \(lastBackup.formatted(date: .abbreviated, time: .shortened))."
    }

    var body: some View {
        FormSheet(title: "Settings", saveTitle: "Done", showsCancel: false, fitsContentOnMac: true, onSave: { dismiss() }) {
            section("Backups", detail: backupDetail) {
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
            extraFolder
            #endif

            section("Restore", detail: "Bring records back from a backup file. Nothing you have now is deleted.") {
                Button("Choose Backup File") { pick(.backup) }
                    .buttonStyle(.themedSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(title: "Reminders")
                CheckboxField(title: "Remind me before items expire or run low", isOn: reminders)
            }

            section("Getting Started", detail: "See a quick tour of the app.") {
                Button("Take the Tour") { Tour.start(router: router, context: modelContext) }
                    .buttonStyle(.themedSecondary)
                if SampleData.hasSamples(in: items) {
                    Button("Remove Practice Items", action: removeSamples)
                        .buttonStyle(.themedSecondary)
                }
            }

            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(messageIsError ? Theme.red : Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    #if os(macOS)
    @ViewBuilder
    private var extraFolder: some View {
        if let extraFolderName {
            section(nil, detail: "A second copy is also saved to the \"\(extraFolderName)\" folder.") {
                Button("Stop Saving There") {
                    ExtraBackupFolder.clear()
                    self.extraFolderName = nil
                }
                .buttonStyle(.themedSecondary)
            }
        } else {
            section(nil, detail: "For protection if this Mac is lost or breaks, keep a second copy in iCloud Drive or on another drive.") {
                Button("Choose a Second Folder") { pick(.folder) }
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

    private func section<Buttons: View>(_ title: String?, detail: String, @ViewBuilder buttons: () -> Buttons) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                FieldLabel(title: title)
            }
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) { buttons() }
        }
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
