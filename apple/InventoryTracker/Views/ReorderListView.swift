import SwiftData
import SwiftUI

struct ReorderListView: View {
    @Query private var items: [Item]
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    private var lines: [ReorderLine] {
        ItemRow.rows(for: items).filter(\.metrics.needsReorder).map { row in
            ReorderLine(
                id: row.item.id,
                name: row.item.name,
                unit: row.item.unitAbbreviation,
                stock: max(0, row.metrics.currentInventory),
                reorderLevel: row.item.reorderLevel,
                vendor: row.metrics.bestPriceVendor,
                bestPrice: row.metrics.lowestPrice
            )
        }
    }

    var body: some View {
        let lines = lines
        let text = ReorderList.text(lines, day: Day.today)

        FormSheet(title: "Shopping List", saveTitle: "Done", showsCancel: false, onSave: { dismiss() }) {
            if lines.isEmpty {
                PlaceholderText("Nothing needs buying right now.")
            } else {
                Text("Items that are running low, grouped by the vendor with the best past price.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(didCopy ? "Copied" : "Copy List") {
                        copy(text)
                        didCopy = true
                    }
                    .buttonStyle(.themedSecondary)
                    ShareLink(item: text) { Text("Share") }
                        .buttonStyle(.themedSecondary)
                }
                ForEach(ReorderList.groups(lines)) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.vendor)
                            .sectionLabel()
                            .padding(.bottom, 4)
                        ForEach(group.lines) { line in
                            MiniRow(showsDivider: line.id != group.lines.last?.id) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.name).lineLimit(2)
                                    Text("Have \(line.stock) \(line.unit)\(line.bestPrice.map { ", best price \(Format.currency($0))" } ?? "")")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Order \(line.suggestedQuantity) \(line.unit)")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
        }
    }

    private func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
