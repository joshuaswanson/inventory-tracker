import SwiftUI

struct SortState<Key: Equatable>: Equatable {
    var key: Key
    var ascending = true

    mutating func toggle(_ newKey: Key) {
        if key == newKey {
            ascending.toggle()
        } else {
            key = newKey
            ascending = true
        }
    }
}

func ordered<Value: Comparable>(_ first: Value, _ second: Value, ascending: Bool) -> Bool {
    ascending ? first < second : second < first
}

func orderedText(_ first: String, _ second: String, ascending: Bool) -> Bool {
    let result = first.localizedCaseInsensitiveCompare(second)
    return ascending ? result == .orderedAscending : result == .orderedDescending
}

struct DataColumn<Row, Key> {
    var title: String
    var sortKey: Key?
    var weight: CGFloat
    var isNumeric: Bool
    var cell: (Row) -> AnyView

    init<Cell: View>(
        _ title: String,
        sortKey: Key? = nil,
        weight: CGFloat = 1,
        isNumeric: Bool = false,
        @ViewBuilder cell: @escaping (Row) -> Cell
    ) {
        self.title = title
        self.sortKey = sortKey
        self.weight = weight
        self.isNumeric = isNumeric
        self.cell = { AnyView(cell($0)) }
    }
}

private struct WeightedColumns: Layout {
    let weights: [CGFloat]
    var spacing: CGFloat = 16

    private var totalSpacing: CGFloat { spacing * CGFloat(max(0, weights.count - 1)) }

    private func widths(for total: CGFloat) -> [CGFloat] {
        let sum = weights.reduce(0, +)
        return weights.map { max(0, total - totalSpacing) * $0 / sum }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 800
        let columnWidths = widths(for: width)
        let height = zip(subviews, columnWidths).map { subview, columnWidth in
            subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
        }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, columnWidth) in zip(subviews, widths(for: bounds.width)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: columnWidth, height: bounds.height)
            )
            x += columnWidth + spacing
        }
    }
}

struct DataTable<Row: Identifiable, Key: Equatable>: View {
    let rows: [Row]
    let columns: [DataColumn<Row, Key>]
    @Binding var sort: SortState<Key>
    var onSelect: ((Row) -> Void)?

    private var weights: [CGFloat] { columns.map(\.weight) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.border)
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    DataTableRow(isClickable: onSelect != nil, showsDivider: row.id != rows.last?.id) {
                        WeightedColumns(weights: weights) {
                            ForEach(columns.indices, id: \.self) { index in
                                columns[index].cell(row)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                    .minimumScaleFactor(columns[index].isNumeric ? 0.7 : 1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } onTap: {
                        onSelect?(row)
                    }
                }
            }
        }
        .card()
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    private var header: some View {
        WeightedColumns(weights: weights) {
            ForEach(columns.indices, id: \.self) { index in
                headerCell(columns[index])
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.borderLight)
    }

    @ViewBuilder
    private func headerCell(_ column: DataColumn<Row, Key>) -> some View {
        if let key = column.sortKey {
            let isSorted = sort.key == key
            Button {
                sort.toggle(key)
            } label: {
                HStack(spacing: 4) {
                    Text(column.title)
                    if isSorted {
                        Image(systemName: sort.ascending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(Theme.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sectionLabel(size: 11)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text(column.title)
                .sectionLabel(size: 11)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DataTableRow<Content: View>: View {
    let isClickable: Bool
    let showsDivider: Bool
    @ViewBuilder let content: Content
    let onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isHovering ? Theme.primary.opacity(isClickable ? 0.06 : 0.03) : .clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isClickable { onTap() }
                }
                .onHover { isHovering = $0 }
            if showsDivider {
                Divider().overlay(Theme.borderLight)
            }
        }
    }
}

struct CompactRowCard<Content: View>: View {
    var onSelect: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        Button {
            onSelect?()
        } label: {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .card()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
