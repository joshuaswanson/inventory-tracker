import SwiftUI

struct ImportOrdersView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var added = SupplierSettings.added()

    private var available: [Supplier] {
        Supplier.all.filter { !added.contains($0) }
    }

    var body: some View {
        FormSheet(title: "Import Orders", saveTitle: "Done", showsCancel: false, macHeight: 440, onSave: { dismiss() }) {
            Text("Bring in what you ordered from your suppliers. Only new orders are added, so it's safe to run anytime.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if added.isEmpty {
                PlaceholderText("Add a supplier to get started.")
            }
            VStack(spacing: 0) {
                ForEach(added) { supplier in
                    MiniRow(showsDivider: supplier != added.last) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(supplier.name)
                                .font(.system(size: 14, weight: .medium))
                            Text(status(of: supplier))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Import") { router.sheet = .supplier(supplier) }
                            .buttonStyle(.themedPrimary)
                            .accessibilityIdentifier("Import \(supplier.name)")
                        RowIconButton(systemImage: "xmark", label: "Remove \(supplier.name)") { setAdded(added.filter { $0 != supplier }) }
                    }
                }
            }

            if available.isEmpty {
                PlaceholderText("More suppliers are on the way.")
            } else {
                Menu("+ Add a Supplier") {
                    ForEach(available) { supplier in
                        Button(supplier.name) { setAdded(added + [supplier]) }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.themedSecondary)
                .fixedSize()
            }
        }
    }

    private func status(of supplier: Supplier) -> String {
        if let date = SupplierSettings.lastImport(for: supplier) {
            return "Last imported \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Not imported yet"
    }

    private func setAdded(_ suppliers: [Supplier]) {
        added = suppliers
        SupplierSettings.setAdded(suppliers)
    }
}
