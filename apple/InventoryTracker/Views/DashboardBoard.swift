import SwiftUI

enum DashboardMotion {
    static let gridSpacing: CGFloat = 16
    static let layout = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let settle = Animation.spring(response: 0.42, dampingFraction: 0.6)
}

/// Layout and gesture state for the dashboard. Kept apart from the widget numbers, so moving
/// or resizing a widget redraws only the grid.
@Observable
final class DashboardModel {
    var layout = DashboardLayout.load() {
        didSet { if layout != oldValue { layout.save() } }
    }
    var isEditing: Bool
    var dragging: DashboardWidget?
    var resizing: ResizeStart?

    init(isEditing: Bool) {
        self.isEditing = isEditing
    }
}

struct ResizeStart {
    var widget: DashboardWidget
    var size: DashboardTileSize
    var tileSize: CGSize
    var cellWidth: CGFloat
    var translation = CGSize.zero

    /// Follows the pointer, but never smaller than the smallest widget or bigger than the biggest.
    var draggedSize: CGSize {
        let largest = DashboardTileSize.extraLarge
        let spacing = DashboardMotion.gridSpacing
        func length(_ cells: Int, _ cell: CGFloat) -> CGFloat { cell * CGFloat(cells) + spacing * CGFloat(cells - 1) }
        return CGSize(
            width: min(max(cellWidth, tileSize.width + translation.width), length(largest.columns, cellWidth)),
            height: min(max(DashboardGrid.cellHeight, tileSize.height + translation.height), length(largest.rows, DashboardGrid.cellHeight))
        )
    }
}

private struct TileDropDelegate: DropDelegate {
    let target: DashboardWidget
    let model: DashboardModel

    func dropEntered(info: DropInfo) {
        guard let dragging = model.dragging, dragging != target else { return }
        withAnimation(DashboardMotion.layout) { model.layout.move(dragging, onto: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        model.dragging = nil
        return true
    }
}

/// A thick stroke that hugs the rounded bottom right corner of a widget.
nonisolated private struct CornerHandle: Shape {
    var radius: CGFloat
    var inset: CGFloat
    var arm: CGFloat

    func path(in rect: CGRect) -> Path {
        let right = rect.maxX - inset
        let bottom = rect.maxY - inset
        var path = Path()
        path.move(to: CGPoint(x: right, y: bottom - radius - arm))
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addArc(center: CGPoint(x: right - radius, y: bottom - radius), radius: radius, startAngle: .zero, endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: right - radius - arm, y: bottom))
        return path
    }
}

struct DashboardEditActions: View {
    let model: DashboardModel
    @Environment(\.isWideLayout) private var isWide

    var body: some View {
        if model.isEditing {
            if !model.layout.hidden.isEmpty {
                Menu("Add a Widget") {
                    ForEach(model.layout.hidden) { widget in
                        Button(widget.title) { withAnimation(DashboardMotion.layout) { model.layout.add(widget) } }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.themedSecondary)
                .fixedSize()
            }
            if model.layout != .standard {
                Button("Reset") { withAnimation(DashboardMotion.layout) { model.layout = .standard } }
                    .buttonStyle(.themedSecondary)
            }
            Button("Done") {
                model.dragging = nil
                model.isEditing = false
            }
            .buttonStyle(.themedPrimary)
        } else if isWide {
            Button("Customize") { model.isEditing = true }
                .buttonStyle(.themedSecondary)
        } else {
            Button {
                model.isEditing = true
            } label: {
                Label("Customize", systemImage: "square.grid.2x2")
            }
        }
    }
}

struct DashboardBoard: View {
    let model: DashboardModel
    let contents: [DashboardWidget: WidgetContent]

    var body: some View {
        DashboardGrid(spacing: DashboardMotion.gridSpacing) {
            ForEach(model.layout.tiles) { tile in
                if let content = contents[tile.widget] {
                    DashboardTileContainer(tile: tile, content: content, model: model)
                        .layoutValue(key: DashboardTileSizeKey.self, value: tile.size)
                }
            }
        }
        .animation(DashboardMotion.layout, value: model.layout)
        if model.layout.tiles.isEmpty {
            PlaceholderText("Your dashboard is empty. Press Customize, then Add a Widget.")
        }
    }
}

/// The grid sizes an invisible placeholder. The widget sits on top of it, so it can follow the
/// pointer while its corner is dragged without pushing the other widgets around.
private struct DashboardTileContainer: View {
    let tile: DashboardTile
    let content: WidgetContent
    let model: DashboardModel
    @State private var isHovered = false

    private var resizing: ResizeStart? {
        model.resizing.flatMap { $0.widget == tile.widget ? $0 : nil }
    }

    var body: some View {
        let dragged = resizing?.draggedSize
        Color.clear
            .overlay(alignment: .topLeading) {
                GeometryReader { geometry in
                    widget(slotSize: geometry.size)
                        .frame(width: dragged?.width ?? geometry.size.width, height: dragged?.height ?? geometry.size.height)
                        .shadow(color: .black.opacity(dragged == nil ? 0 : 0.16), radius: 14, y: 6)
                }
            }
            .zIndex(dragged == nil ? 0 : 1)
    }

    private func widget(slotSize: CGSize) -> some View {
        DashboardTileView(content: content, size: tile.size)
            .allowsHitTesting(!model.isEditing)
            .overlay {
                if model.isEditing {
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(Theme.primary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                }
            }
            .opacity(model.dragging == tile.widget ? 0.4 : 1)
            .contentShape(Rectangle())
            .onDrag {
                model.dragging = tile.widget
                return NSItemProvider(object: tile.widget.rawValue as NSString)
            }
            .onDrop(of: [.plainText], delegate: TileDropDelegate(target: tile.widget, model: model))
            .overlay(alignment: .topTrailing) {
                if model.isEditing { removeButton }
            }
            .overlay(alignment: .bottomTrailing) {
                resizeHandle(slotSize: slotSize)
            }
            .onHover { isHovered = $0 }
            .contextMenu { menu }
    }

    @ViewBuilder
    private var menu: some View {
        Menu("Size") {
            ForEach(DashboardTileSize.allCases) { size in
                Button {
                    withAnimation(DashboardMotion.layout) { model.layout.resize(tile.widget, to: size) }
                } label: {
                    if size == tile.size {
                        Label(size.title, systemImage: "checkmark")
                    } else {
                        Text(size.title)
                    }
                }
            }
        }
        Divider()
        Button("Delete", role: .destructive) {
            withAnimation(DashboardMotion.layout) { model.layout.hide(tile.widget) }
        }
    }

    private var removeButton: some View {
        RowIconButton(systemImage: "xmark", isDestructive: true, label: "Remove \(tile.widget.title)") {
            withAnimation(DashboardMotion.layout) { model.layout.hide(tile.widget) }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        .padding(8)
    }

    private func resizeHandle(slotSize: CGSize) -> some View {
        let isActive = resizing != nil
        let isVisible = model.isEditing || isActive || isHovered
        let spacing = DashboardMotion.gridSpacing
        return CornerHandle(radius: Theme.radius - 4, inset: 5, arm: 7)
            .stroke(isActive ? Theme.primary : Theme.textTertiary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: isVisible)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { drag in
                        var start = resizing ?? {
                            let columns = CGFloat(tile.size.columns)
                            return ResizeStart(
                                widget: tile.widget,
                                size: tile.size,
                                tileSize: slotSize,
                                cellWidth: (slotSize.width - spacing * (columns - 1)) / columns
                            )
                        }()
                        start.translation = drag.translation
                        model.resizing = start
                        let columns = start.size.columns + Int((drag.translation.width / (start.cellWidth + spacing)).rounded())
                        let rows = start.size.rows + Int((drag.translation.height / (DashboardGrid.cellHeight + spacing)).rounded())
                        let size = DashboardTileSize.closest(columns: columns, rows: rows)
                        if size != tile.size {
                            withAnimation(DashboardMotion.layout) { model.layout.resize(tile.widget, to: size) }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(DashboardMotion.settle) { model.resizing = nil }
                    }
            )
            .help("Drag to resize")
            .accessibilityLabel("Resize \(tile.widget.title)")
    }
}
