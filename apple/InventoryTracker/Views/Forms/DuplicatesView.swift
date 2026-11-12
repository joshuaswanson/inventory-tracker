import SwiftData
import SwiftUI

enum DuplicateKind: String {
    case items, vendors
}

struct DuplicateEntry: Identifiable {
    let id: String
    let name: String
    let detail: String
}

/// A reminder that some entries look like the same thing, shown above a list.
struct DuplicatesBanner: View {
    let count: Int
    let noun: String
    let action: () -> Void

    var body: some View {
        if count > 0 {
            HStack(spacing: 12) {
                Image(systemName: "square.on.square.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.amber)
                    .frame(width: 32, height: 32)
                    .background(Theme.amberLight, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                Text(count == 1
                    ? "You may have the same \(noun) listed more than once."
                    : "You may have \(count) \(noun)s listed more than once.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Review", action: action)
                    .buttonStyle(.themedPrimary)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: Theme.radius, bottomLeadingRadius: Theme.radius)
                    .fill(Theme.amber)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.amber.opacity(0.45)))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .padding(.bottom, 16)
        }
    }
}

private struct DuplicateGroupCard: View {
    let entries: [DuplicateEntry]
    let noun: String
    let startsTicked: Bool
    let onCombine: (_ keeper: String, _ others: [String]) -> Void
    let onDismiss: () -> Void

    @State private var ticked: Set<String> = []

    private var chosen: [DuplicateEntry] { entries.filter { ticked.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(entries) { entry in
                let isOn = ticked.contains(entry.id)
                Button {
                    if isOn { ticked.remove(entry.id) } else { ticked.insert(entry.id) }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: isOn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 17))
                            .foregroundStyle(isOn ? Theme.primary : Theme.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                            Text(entry.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
            if chosen.count > 1, let keeper = chosen.first {
                Text("They will become one \(noun) called \"\(keeper.name)\".")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button("Combine Ticked") {
                    guard let keeper = chosen.first else { return }
                    onCombine(keeper.id, chosen.dropFirst().map(\.id))
                }
                .buttonStyle(.themedPrimary)
                .disabled(chosen.count < 2)
                Button("None Are the Same", action: onDismiss)
                    .buttonStyle(.themedSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.border))
        .onAppear {
            if startsTicked { ticked = Set(entries.map(\.id)) }
        }
    }
}

struct DuplicatesView: View {
    let kind: DuplicateKind
    @Query private var items: [Item]
    @Query private var vendors: [Vendor]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dismissed = DuplicateDetector.dismissed()

    static func itemCandidates(_ items: [Item]) -> [DuplicateDetector.Candidate] {
        items.map { item in
            DuplicateDetector.Candidate(
                id: item.id,
                name: item.name,
                productNumbers: Set((item.purchases ?? []).map { $0.productNumber.lowercased() }.filter { $0.count >= 4 }),
                purchases: item.purchases?.count ?? 0
            )
        }
    }

    static func vendorCandidates(_ vendors: [Vendor]) -> [DuplicateDetector.Candidate] {
        vendors.map { DuplicateDetector.Candidate(id: $0.id, name: $0.name, purchases: $0.orderCount) }
    }

    private var groups: [DuplicateDetector.Group] {
        switch kind {
        case .items: DuplicateDetector.itemGroups(Self.itemCandidates(items), dismissed: dismissed)
        case .vendors: DuplicateDetector.vendorGroups(Self.vendorCandidates(vendors), dismissed: dismissed)
        }
    }

    private func entries(in group: DuplicateDetector.Group) -> [DuplicateEntry] {
        group.ids.compactMap { id in
            switch kind {
            case .items:
                guard let item = items.first(where: { $0.id == id }) else { return nil }
                let purchases = item.purchases?.count ?? 0
                return DuplicateEntry(id: id, name: item.name, detail: "\(item.metrics().currentInventory) \(item.unitAbbreviation) in stock, \(purchases) purchase\(purchases == 1 ? "" : "s")")
            case .vendors:
                guard let vendor = vendors.first(where: { $0.id == id }) else { return nil }
                return DuplicateEntry(id: id, name: vendor.name, detail: "\(vendor.orderCount) purchase\(vendor.orderCount == 1 ? "" : "s"), \(Format.currency(vendor.totalSpent)) spent")
            }
        }
    }

    var body: some View {
        let groups = groups
        let noun = kind == .items ? "item" : "vendor"
        FormSheet(title: "Possible Duplicates", saveTitle: "Done", showsCancel: false, macWidth: 600, macHeight: 680, onSave: { dismiss() }) {
            Text(kind == .items
                ? "These items have very similar names. In each box, tick the ones that are really the same product, then press Combine Ticked. Different sizes, colors or flavors are not the same product, so leave those unticked."
                : "These vendors have very similar names. In each box, tick the ones that are really the same company, then press Combine Ticked.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if groups.isEmpty {
                EmptyState(systemImage: "checkmark.circle", title: "Nothing left to review", message: "No more \(noun)s look like duplicates.")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            ForEach(groups) { group in
                DuplicateGroupCard(entries: entries(in: group), noun: noun, startsTicked: kind == .vendors) { keeper, others in
                    combine(keeper: keeper, others: others)
                } onDismiss: {
                    DuplicateDetector.dismiss(group)
                    withAnimation(.snappy) { dismissed = DuplicateDetector.dismissed() }
                }
            }
            Text("You can separate combined entries again later: open the kept one and press Combine Duplicates.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func combine(keeper: String, others: [String]) {
        withAnimation(.snappy) {
            switch kind {
            case .items:
                guard let kept = items.first(where: { $0.id == keeper }) else { return }
                try? DuplicateCombiner.combine(items.filter { others.contains($0.id) }, into: kept, in: modelContext)
            case .vendors:
                guard let kept = vendors.first(where: { $0.id == keeper }) else { return }
                try? DuplicateCombiner.combine(vendors.filter { others.contains($0.id) }, into: kept, in: modelContext)
            }
        }
    }
}
