import SwiftData
import SwiftUI

struct SpendingView: View {
    @Query private var purchases: [Purchase]
    @Environment(\.dismiss) private var dismiss
    @State private var period = SpendingPeriod.thisYear
    @State private var isExporting = false
    @State private var exportDocument: BackupDocument?
    @State private var errorMessage: String?

    private var entries: [SpendingEntry] {
        let today = Day.today
        return purchases.filter { period.includes(day: $0.date, today: today) }.map {
            SpendingEntry(day: $0.date, item: $0.item?.name ?? "Unknown", vendor: $0.vendor?.name ?? "", quantity: $0.quantity, pricePerUnit: $0.pricePerUnit)
        }
    }

    var body: some View {
        let entries = entries
        let report = SpendingReport(entries: entries)

        FormSheet(title: "Spending", saveTitle: "Done", showsCancel: false, errorMessage: errorMessage, onSave: { dismiss() }) {
            Picker("", selection: $period) {
                ForEach(SpendingPeriod.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            StatCard(label: "Total Spent", value: Format.currency(report.total), valueColor: Theme.green)

            if entries.isEmpty {
                PlaceholderText("No purchases in this period.")
            } else {
                totals("By Vendor", report.byVendor) { $0 }
                totals("By Month", report.byMonth, name: Format.month)
                Button("Export Spreadsheet") {
                    exportDocument = BackupDocument(data: Data(SpendingReport.csv(entries).utf8))
                    isExporting = true
                }
                .buttonStyle(.themedSecondary)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "spending-\(Day.today)"
        ) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
    }

    private func totals(_ title: String, _ rows: [SpendingTotal], name: @escaping (String) -> String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .sectionLabel()
                .padding(.bottom, 4)
            ForEach(rows) { row in
                MiniRow(showsDivider: row.id != rows.last?.id) {
                    Text(name(row.name))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Format.currency(row.total)).fontWeight(.medium)
                }
            }
        }
    }
}
