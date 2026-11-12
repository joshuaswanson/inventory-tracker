import Charts
import SwiftData
import SwiftUI

struct SpendingView: View {
    private static let vendorLimit = 6
    private static let itemLimit = 5
    private static let monthLabelLimit = 8

    @Query private var purchases: [Purchase]
    @Environment(\.dismiss) private var dismiss
    @State private var period = SpendingPeriod.thisYear
    @State private var selectedMonth: String?
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

        FormSheet(title: "Spending", saveTitle: "Done", showsCancel: false, macWidth: 640, macHeight: 720, errorMessage: errorMessage, onSave: { dismiss() }) {
            SegmentedSwitch(options: SpendingPeriod.allCases, selection: $period, label: \.label)

            if entries.isEmpty {
                EmptyState(systemImage: "chart.bar", title: "No purchases in this period", message: "Pick another period above, or import your orders to see your spending here.")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                summary(report)
                monthChart(report.monthlySeries)
                ranking(
                    "By Vendor",
                    SpendingReport.leading(report.byVendor, limit: Self.vendorLimit) { "\($0) other vendors" },
                    total: report.total
                )
                ranking(
                    "Top Items",
                    SpendingReport.leading(report.byItem, limit: Self.itemLimit) { "\($0) other items" },
                    total: report.total
                )
                Button("Export Spreadsheet", systemImage: "square.and.arrow.up") {
                    exportDocument = BackupDocument(data: Data(SpendingReport.csv(entries).utf8))
                    isExporting = true
                }
                .buttonStyle(.themedSecondary)
            }
        }
        .onChange(of: period) { selectedMonth = nil }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "spending-\(Day.today)"
        ) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
    }

    private func summary(_ report: SpendingReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Spent").sectionLabel()
                Text(Format.currency(report.total))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            HStack(spacing: 24) {
                fact("\(report.purchaseCount)", report.purchaseCount == 1 ? "purchase" : "purchases")
                fact("\(report.byVendor.count)", report.byVendor.count == 1 ? "vendor" : "vendors")
                fact(Format.currency(report.averagePerMonth), "a month on average")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.primaryBackground, in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    private func fact(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func section<Content: View>(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).sectionLabel()
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .card()
    }

    private func monthChart(_ months: [SpendingTotal]) -> some View {
        let shown = months.first { $0.name == selectedMonth } ?? months.max { $0.total < $1.total }
        let caption = shown.map { "\(selectedMonth == nil ? "Biggest month: " : "")\(Format.month($0.name)), \(Format.currency($0.total))" }
        let labelStride = max(1, Int((Double(months.count) / Double(Self.monthLabelLimit)).rounded(.up)))
        let labelled = months.enumerated().filter { $0.offset % labelStride == 0 }.map(\.element.name)

        return section("By Month", detail: caption) {
            Chart(months) { month in
                BarMark(x: .value("Month", month.name), y: .value("Spent", month.total), width: .ratio(0.6))
                    .cornerRadius(4)
                    .foregroundStyle(Theme.primary.opacity(selectedMonth == nil || selectedMonth == month.name ? 1 : 0.35))
            }
            .chartXSelection(value: $selectedMonth)
            .chartXAxis {
                AxisMarks(values: labelled) { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) {
                            Text(monthLabel(name, showsYear: months.count > 12))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Theme.borderLight)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")).notation(.compactName).precision(.fractionLength(0...1))))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 170)
            .accessibilityLabel("Spending by month")
        }
    }

    private func monthLabel(_ yearMonth: String, showsYear: Bool) -> String {
        let month = Format.month(yearMonth).prefix(3)
        return showsYear ? "\(month) '\(yearMonth.dropFirst(2).prefix(2))" : String(month)
    }

    private func ranking(_ title: String, _ rows: [SpendingTotal], total: Double) -> some View {
        let largest = rows.map(\.total).max() ?? 0
        return section(title) {
            VStack(spacing: 12) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(row.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(total > 0 ? (row.total / total).formatted(.percent.precision(.fractionLength(0))) : "")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                            Text(Format.currency(row.total))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .monospacedDigit()
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.borderLight)
                                Capsule().fill(Theme.primary)
                                    .frame(width: largest > 0 ? max(4, geometry.size.width * row.total / largest) : 0)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
}
