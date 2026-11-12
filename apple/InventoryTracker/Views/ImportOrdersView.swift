import SwiftUI

struct ImportOrdersView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var added = SupplierSettings.added()
    @State private var importAll = ImportAllRun()

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
                HStack {
                    Text("Your Suppliers").sectionLabel(tracking: 0.3)
                    Spacer()
                    if added.count > 1 {
                        Button(importAll.isRunning ? "Importing..." : "Import All") {
                            Task { await importAll.run(added, into: modelContext) }
                        }
                        .buttonStyle(.themedSecondary)
                        .disabled(importAll.isRunning)
                    }
                }
                if importAll.hasFinished { importAllSummary }
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
            if importAll.status(of: supplier) == .working {
                ProgressView().controlSize(.small)
            }
            Button(importAll.status(of: supplier) == .needsSignIn ? "Sign In" : "Import") { router.sheet = .supplier(supplier) }
                .buttonStyle(.themedPrimary)
                .accessibilityIdentifier("Import \(supplier.name)")
                .disabled(importAll.isRunning)
            RowIconButton(systemImage: "xmark", label: "Remove \(supplier.name)") { setAdded(added.filter { $0 != supplier }) }
                .disabled(importAll.isRunning)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private var importAllSummary: some View {
        let needSignIn = added.filter { importAll.status(of: $0) == .needsSignIn }.count
        let purchases = importAll.newPurchases
        let items = importAll.newItemIDs.count
        return VStack(alignment: .leading, spacing: 10) {
            Text(purchases == 0
                ? "Nothing new to bring in."
                : "\(purchases) new purchase\(purchases == 1 ? "" : "s") added\(items == 0 ? "" : ", with \(items) new item\(items == 1 ? "" : "s")").")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            if needSignIn > 0 {
                Text("\(needSignIn) supplier\(needSignIn == 1 ? " needs" : "s need") you to sign in first. Press Sign In next to \(needSignIn == 1 ? "it" : "each one").")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if items > 0 || purchases > 0 {
                HStack(spacing: 8) {
                    if items > 0 {
                        Button("Review New Items") { router.sheet = .reviewNewItems(importAll.newItemIDs) }
                            .buttonStyle(.themedPrimary)
                    }
                    Button("Count Stock Now") { router.sheet = .countAll }
                        .buttonStyle(.themedSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.primaryBackground, in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    @ViewBuilder
    private func status(of supplier: Supplier) -> some View {
        if let run = importAll.status(of: supplier) {
            runStatus(run)
        } else if let date = SupplierSettings.lastImport(for: supplier) {
            Label("Last imported \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.green)
        } else {
            Text("Not imported yet")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func runStatus(_ status: ImportAllStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .waiting: ("Waiting...", Theme.textTertiary)
        case .working: ("Importing...", Theme.primaryDark)
        case .finished(let newPurchases): (newPurchases == 0 ? "Up to date" : "\(newPurchases) new purchase\(newPurchases == 1 ? "" : "s") added", Theme.green)
        case .needsSignIn: ("Sign in needed", Theme.amber)
        case .failed(let message): (message, Theme.red)
        }
        return Text(text)
            .font(.system(size: 12))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
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

struct ReviewImportedItemsView: View {
    let itemIDs: [String]
    @Environment(Router.self) private var router

    var body: some View {
        NewItemsReviewView(itemIDs: itemIDs) { router.sheet = .importOrders }
    }
}
