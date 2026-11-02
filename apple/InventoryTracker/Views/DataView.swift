import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router
    @Query private var items: [Item]
    @Query private var vendors: [Vendor]
    @Query private var purchases: [Purchase]
    @Query private var usage: [UsageRecord]
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument: BackupDocument?
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        FormSheet(title: "Data", saveTitle: "Done", onSave: { dismiss() }) {
            VStack(spacing: 0) {
                InfoRow("Items", value: "\(items.count)")
                InfoRow("Vendors", value: "\(vendors.count)")
                InfoRow("Purchases", value: "\(purchases.count)")
                InfoRow("Usage records", value: "\(usage.count)", showsDivider: false)
            }

            action(
                title: "Import",
                detail: "Choose a backup file or an older data folder. Matching records are updated, so importing twice is safe.",
                button: "Choose Files"
            ) {
                isImporting = true
            }

            action(
                title: "Back Up",
                detail: "Save everything to one JSON file. Import that file on another device to copy your data there. Deletions do not carry over.",
                button: "Export Backup",
                action: export
            )

            action(
                title: "SupplyClinic",
                detail: "Sign in to SupplyClinic and bring in your order history. Only new orders are added.",
                button: "Import Orders"
            ) {
                router.sheet = .supplyClinic
            }

            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(messageIsError ? Theme.red : Theme.green)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json, .folder],
            allowsMultipleSelection: true,
            onCompletion: importFiles
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

    private func action(title: String, detail: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(title: title)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(button, action: action)
                .buttonStyle(.themedSecondary)
        }
    }

    private func export() {
        do {
            exportDocument = BackupDocument(data: try BackupMerge.export(from: modelContext).encoded())
            isExporting = true
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let backup = try Backup.load(from: try result.get())
            let summary = try BackupMerge.merge(backup, into: modelContext)
            let skipped = summary.skipped > 0 ? ", \(summary.skipped) skipped" : ""
            show("Imported. \(summary.added) added, \(summary.updated) updated\(skipped).", isError: false)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}
