import SwiftUI

struct WidgetItem: Identifiable {
    let id: UUID?
    let name: String
    let detail: String
    let showPill: Bool

    init(name: String, detail: String, id: UUID? = nil, showPill: Bool = true) {
        self.id = id
        self.name = name
        self.detail = detail
        self.showPill = showPill
    }
}

struct WidgetCard: View {
    let title: String
    let value: Any
    let icon: String
    let color: Color
    let size: WidgetSize
    let items: [WidgetItem]
    var isPreview: Bool = false
    var onItemTap: ((UUID) -> Void)? = nil
    var onMoreTap: (() -> Void)? = nil

    private var displayValue: String {
        if let intVal = value as? Int {
            return "\(intVal)"
        } else if let doubleVal = value as? Double {
            return doubleVal.formatted(.currency(code: "USD"))
        }
        return "\(value)"
    }

    private var maxItems: Int {
        switch size {
        case .small: return 0
        case .medium: return 2
        case .large: return 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .small ? 8 : 14) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                if size != .small {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                if size != .small {
                    Text(displayValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                }
            }
            .padding(.horizontal, size == .small ? 0 : 4)

            if size == .small {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(title)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                if items.isEmpty {
                    Spacer()
                    Text("No items")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.prefix(maxItems).enumerated()), id: \.element.name) { index, item in
                            if index > 0 {
                                Divider()
                                    .padding(.horizontal, 4)
                            }
                            itemRow(item: item)
                        }
                        if items.count > maxItems {
                            Divider()
                                .padding(.horizontal, 4)
                            moreButton(count: items.count - maxItems)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, size == .small ? 14 : 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func itemRow(item: WidgetItem) -> some View {
        let rowContent = HStack(spacing: 8) {
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(item.showPill ? color : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(item.showPill ? color.opacity(0.15) : .clear)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)

        if let id = item.id, let onItemTap = onItemTap {
            Button {
                onItemTap(id)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    @ViewBuilder
    private func moreButton(count: Int) -> some View {
        if let onMoreTap = onMoreTap {
            Button {
                onMoreTap()
            } label: {
                Text("+\(count) more")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        } else {
            Text("+\(count) more")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
        }
    }
}

struct DashboardItemDropDelegate: DropDelegate {
    let item: DashboardItem
    @Binding var items: [DashboardItem]
    @Binding var draggingItem: DashboardItem?
    @Binding var droppingItem: DashboardItem?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        droppingItem = draggingItem
        draggingItem = nil
        onReorder()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            droppingItem = nil
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem != item,
              let fromIndex = items.firstIndex(of: draggingItem),
              let toIndex = items.firstIndex(of: item) else { return }

        withAnimation(.default) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
