import SwiftUI

struct ImportOrdersView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var added = SupplierSettings.added()

    private var available: [Supplier] {
        Supplier.all.filter { !added.contains($0) }
    }

    var body: some View {
        FormSheet(title: "Import Orders", saveTitle: "Done", showsCancel: false, macWidth: 600, macHeight: 660, onSave: { dismiss() }) {
            Text("Bring in what you ordered from your suppliers. Only new orders are added, so it's safe to run anytime.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Your Suppliers").sectionLabel(tracking: 0.3)
                if added.isEmpty {
                    PlaceholderText("Add a supplier to get started.")
                        .padding(.vertical, 8)
                }
                ForEach(added) { supplier in
                    addedRow(supplier)
                }
            }

            if !available.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add a Supplier").sectionLabel(tracking: 0.3)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                        ForEach(available) { supplier in
                            availableTile(supplier)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: added)
    }

    private func addedRow(_ supplier: Supplier) -> some View {
        HStack(spacing: 14) {
            SupplierIcon(supplier: supplier)
            VStack(alignment: .leading, spacing: 3) {
                Text(supplier.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                status(of: supplier)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Import") { router.sheet = .supplier(supplier) }
                .buttonStyle(.themedPrimary)
                .accessibilityIdentifier("Import \(supplier.name)")
            RowIconButton(systemImage: "xmark", label: "Remove \(supplier.name)") { setAdded(added.filter { $0 != supplier }) }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private func status(of supplier: Supplier) -> some View {
        if let date = SupplierSettings.lastImport(for: supplier) {
            Label("Last imported \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.green)
        } else {
            Text("Not imported yet")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func availableTile(_ supplier: Supplier) -> some View {
        Button {
            setAdded(added + [supplier])
        } label: {
            HStack(spacing: 10) {
                SupplierIcon(supplier: supplier, size: 32)
                Text(supplier.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.primary)
            }
            .padding(10)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(supplier.name)")
    }

    private func setAdded(_ suppliers: [Supplier]) {
        added = suppliers
        SupplierSettings.setAdded(suppliers)
    }
}
