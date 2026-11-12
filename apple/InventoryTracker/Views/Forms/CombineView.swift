import SwiftData
import SwiftUI

struct CombineCandidate: Identifiable {
    let id: String
    let name: String
    let detail: String
    var warning: String?
    var similarity = 0
}

private struct CombineSheet: View {
    let kind: String
    let keeperName: String
    let movedThings: String
    let candidates: [CombineCandidate]
    let onCombine: (Set<String>) -> Void

    @State private var selected: Set<String> = []
    @State private var search = ""

    private var similar: [CombineCandidate] {
        candidates.filter { $0.similarity > 0 }.sorted { ($1.similarity, $0.name) < ($0.similarity, $1.name) }
    }

    private var others: [CombineCandidate] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return candidates
            .filter { $0.similarity == 0 || !query.isEmpty }
            .filter { query.isEmpty || $0.name.lowercased().contains(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var saveTitle: String {
        selected.isEmpty ? "Combine" : "Combine \(selected.count) into This One"
    }

    var body: some View {
        FormSheet(title: "Combine Duplicates", saveTitle: saveTitle, canSave: !selected.isEmpty, macWidth: 560, macHeight: 640, onSave: { onCombine(selected) }) {
            Text("Tick every entry that is really the same \(kind) as \"\(keeperName)\". \(movedThings) move over to it, and the extra entries are removed.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !similar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Look Similar").sectionLabel(tracking: 0.3)
                    ForEach(similar) { row($0) }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(similar.isEmpty ? "Pick From Your List" : "Everything Else").sectionLabel(tracking: 0.3)
                ThemedTextField("Search by name", text: $search)
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(others) { row($0) }
                }
                if others.isEmpty {
                    PlaceholderText("Nothing matches that search.")
                }
            }

            Text("Combining can't be undone, so only tick entries you're sure about.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ candidate: CombineCandidate) -> some View {
        let isOn = selected.contains(candidate.id)
        return Button {
            if isOn { selected.remove(candidate.id) } else { selected.insert(candidate.id) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17))
                    .foregroundStyle(isOn ? Theme.primary : Theme.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                    Text(candidate.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    if isOn, let warning = candidate.warning {
                        Text(warning)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(isOn ? Theme.primaryBackground : Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(isOn ? Theme.primary : Theme.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidate.name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct CombineItemsView: View {
    let keeper: Item
    @Query private var items: [Item]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var candidates: [CombineCandidate] {
        items.filter { $0.id != keeper.id }.map { item in
            let purchases = item.purchases?.count ?? 0
            return CombineCandidate(
                id: item.id,
                name: item.name,
                detail: "\(item.metrics().currentInventory) \(item.unitAbbreviation) in stock, \(purchases) purchase\(purchases == 1 ? "" : "s")",
                warning: item.unitRaw == keeper.unitRaw ? nil
                    : "This one is counted in \(item.unitAbbreviation) and \"\(keeper.name)\" in \(keeper.unitAbbreviation). Check the stock number after combining.",
                similarity: NameSimilarity.score(keeper.name, item.name)
            )
        }
    }

    var body: some View {
        CombineSheet(kind: "product", keeperName: keeper.name, movedThings: "Their purchases and usage", candidates: candidates) { chosen in
            try? DuplicateCombiner.combine(items.filter { chosen.contains($0.id) }, into: keeper, in: modelContext)
            dismiss()
        }
    }
}

struct CombineVendorsView: View {
    let keeper: Vendor
    @Query private var vendors: [Vendor]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var candidates: [CombineCandidate] {
        vendors.filter { $0.id != keeper.id }.map { vendor in
            CombineCandidate(
                id: vendor.id,
                name: vendor.name,
                detail: "\(vendor.orderCount) purchase\(vendor.orderCount == 1 ? "" : "s"), \(Format.currency(vendor.totalSpent)) spent",
                similarity: NameSimilarity.score(keeper.name, vendor.name)
            )
        }
    }

    var body: some View {
        CombineSheet(kind: "vendor", keeperName: keeper.name, movedThings: "Their purchases", candidates: candidates) { chosen in
            try? DuplicateCombiner.combine(vendors.filter { chosen.contains($0.id) }, into: keeper, in: modelContext)
            dismiss()
        }
    }
}
