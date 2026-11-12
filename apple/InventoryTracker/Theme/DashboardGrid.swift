import SwiftUI

nonisolated struct DashboardTileSizeKey: LayoutValueKey {
    static let defaultValue = DashboardTileSize.small
}

/// Lays tiles out left to right in equal columns, starting a new row when a tile no longer fits.
struct DashboardGrid: Layout {
    var spacing: CGFloat = 16

    static func columns(for width: CGFloat) -> Int {
        if width >= 1050 { return 6 }
        if width >= 640 { return 4 }
        return 2
    }

    private struct Placement {
        var index: Int
        var column: Int
        var span: Int
        var row: Int
    }

    private struct Arrangement {
        var placements: [Placement]
        var rowHeights: [CGFloat]
        var columnWidth: CGFloat
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> Arrangement {
        let columns = Self.columns(for: width)
        let columnWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        var placements: [Placement] = []
        var rowHeights: [CGFloat] = []
        var column = 0
        var row = 0
        for (index, subview) in subviews.enumerated() {
            let span = min(columns, subview[DashboardTileSizeKey.self].span(columns: columns))
            if column + span > columns {
                column = 0
                row += 1
            }
            let height = subview.sizeThatFits(ProposedViewSize(width: tileWidth(span: span, columnWidth: columnWidth), height: nil)).height
            if rowHeights.count <= row { rowHeights.append(0) }
            rowHeights[row] = max(rowHeights[row], height)
            placements.append(Placement(index: index, column: column, span: span, row: row))
            column += span
        }
        return Arrangement(placements: placements, rowHeights: rowHeights, columnWidth: columnWidth)
    }

    private func tileWidth(span: Int, columnWidth: CGFloat) -> CGFloat {
        columnWidth * CGFloat(span) + spacing * CGFloat(span - 1)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 800
        let heights = arrange(subviews, width: width).rowHeights
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(subviews, width: bounds.width)
        var rowTops: [CGFloat] = []
        var top = bounds.minY
        for height in arrangement.rowHeights {
            rowTops.append(top)
            top += height + spacing
        }
        for placement in arrangement.placements {
            subviews[placement.index].place(
                at: CGPoint(x: bounds.minX + CGFloat(placement.column) * (arrangement.columnWidth + spacing), y: rowTops[placement.row]),
                anchor: .topLeading,
                proposal: ProposedViewSize(
                    width: tileWidth(span: placement.span, columnWidth: arrangement.columnWidth),
                    height: arrangement.rowHeights[placement.row]
                )
            )
        }
    }
}
