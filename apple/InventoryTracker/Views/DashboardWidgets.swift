import Charts
import SwiftUI

struct WidgetRow: Identifiable {
    let id: String
    var label: String
    var trailing: String
    var badge: Badge?
    var action: (() -> Void)?
}

struct WidgetLink: Identifiable {
    let title: String
    let action: () -> Void

    var id: String { title }
}

struct WidgetContent {
    var systemImage: String
    var tone: Tone
    var title: String
    var value: String
    var valueColor: Color = Theme.text
    var caption: String
    var rows: [WidgetRow] = []
    var emptyMessage = ""
    var chart: [SpendingTotal] = []
    var links: [WidgetLink] = []
    var action: (() -> Void)?
}

/// One dashboard box, drawn differently for each of the four sizes.
struct DashboardTileView: View {
    private static let rowHeight: CGFloat = 34
    private static let mediumRows = 3
    private static let columnRows = 6
    private static let largeChartMonths = 6

    let content: WidgetContent
    let size: DashboardTileSize

    var body: some View {
        Group {
            switch size {
            case .small: headline
            case .medium: medium
            case .large: large
            case .extraLarge: extraLarge
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
        .contentShape(Rectangle())
        .onTapGesture { content.action?() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(content.title), \(content.value)")
    }

    private func icon(_ side: CGFloat) -> some View {
        Image(systemName: content.systemImage)
            .font(.system(size: side * 0.45))
            .foregroundStyle(content.tone.icon)
            .frame(width: side, height: side)
            .background(content.tone.background, in: RoundedRectangle(cornerRadius: side * 0.27))
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 2) {
            icon(36)
            Spacer(minLength: 4)
            Text(content.title)
                .sectionLabel(size: 11)
                .lineLimit(1)
            Text(content.value)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(content.valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(content.caption)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            headline.frame(width: 118)
            Divider().overlay(Theme.borderLight)
            rowList(Array(content.rows.prefix(Self.mediumRows)), showsBadges: false)
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            icon(30)
            VStack(alignment: .leading, spacing: 0) {
                Text(content.title).sectionLabel(size: 12)
                Text(content.caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(content.value)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(content.valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if content.chart.isEmpty {
                rowList(Array(content.rows.prefix(Self.columnRows)), showsBadges: true)
            } else {
                chart(Array(content.chart.suffix(Self.largeChartMonths))).frame(height: 96)
                rowList(Array(content.rows.prefix(3)), showsBadges: true)
            }
            Spacer(minLength: 0)
            links
        }
    }

    private var extraLarge: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            HStack(alignment: .top, spacing: 24) {
                if content.chart.isEmpty {
                    rowList(Array(content.rows.prefix(Self.columnRows)), showsBadges: true)
                    rowList(Array(content.rows.dropFirst(Self.columnRows).prefix(Self.columnRows)), showsBadges: true, emptyMessage: "")
                } else {
                    chart(content.chart).frame(maxHeight: .infinity)
                    rowList(Array(content.rows.prefix(Self.columnRows)), showsBadges: true)
                }
            }
            Spacer(minLength: 0)
            links
        }
    }

    private func rowList(_ rows: [WidgetRow], showsBadges: Bool, emptyMessage: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                PlaceholderText(emptyMessage ?? content.emptyMessage)
            }
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Text(row.label)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.trailing)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                    if showsBadges, let badge = row.badge { badge }
                }
                .frame(height: Self.rowHeight)
                .contentShape(Rectangle())
                .onTapGesture { (row.action ?? content.action)?() }
                if row.id != rows.last?.id {
                    Divider().overlay(Theme.borderLight)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func chart(_ months: [SpendingTotal]) -> some View {
        Chart(months) { month in
            BarMark(x: .value("Month", month.name), y: .value("Spent", month.total), width: .ratio(0.6))
                .cornerRadius(3)
                .foregroundStyle(Theme.primary)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(String(Format.month(name).prefix(1)))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Theme.borderLight)
            }
        }
        .accessibilityLabel("Spending by month")
    }

    @ViewBuilder
    private var links: some View {
        if !content.links.isEmpty {
            HStack(spacing: 16) {
                ForEach(content.links) { link in
                    Button(action: link.action) {
                        HStack(spacing: 3) {
                            Text(link.title)
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
