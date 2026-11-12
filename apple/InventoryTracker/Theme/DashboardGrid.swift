import SwiftUI

nonisolated struct DashboardTileSizeKey: LayoutValueKey {
    static let defaultValue = DashboardTileSize.small
}

/// A grid of equal cells. Each tile covers a block of cells set by its size.
struct DashboardGrid: Layout {
    static let cellHeight: CGFloat = 164
    private static let minimumCellWidth: CGFloat = 160
    private static let maximumColumns = 8

    var spacing: CGFloat = 16

    static func columns(for width: CGFloat, spacing: CGFloat = 16) -> Int {
        min(maximumColumns, max(2, Int((width + spacing) / (minimumCellWidth + spacing))))
    }

    private func slots(_ subviews: Subviews, width: CGFloat) -> [DashboardPacking.Slot] {
        DashboardPacking.slots(for: subviews.map { $0[DashboardTileSizeKey.self] }, columns: Self.columns(for: width, spacing: spacing))
    }

    private func length(cells: Int, cell: CGFloat) -> CGFloat {
        cell * CGFloat(cells) + spacing * CGFloat(cells - 1)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 800
        let rows = slots(subviews, width: width).map { $0.row + $0.rows }.max() ?? 0
        return CGSize(width: width, height: rows == 0 ? 0 : length(cells: rows, cell: Self.cellHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = Self.columns(for: bounds.width, spacing: spacing)
        let cellWidth = max(0, (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        for (subview, slot) in zip(subviews, slots(subviews, width: bounds.width)) {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(slot.column) * (cellWidth + spacing),
                    y: bounds.minY + CGFloat(slot.row) * (Self.cellHeight + spacing)
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(
                    width: length(cells: slot.columns, cell: cellWidth),
                    height: length(cells: slot.rows, cell: Self.cellHeight)
                )
            )
        }
    }
}
