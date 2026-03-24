import SwiftUI
import SwiftData

enum UsageSortColumn: String {
    case date, item, quantity, estimate, notes
}

struct UsageListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Usage.date, order: .reverse) private var usageRecords: [Usage]

    @State private var showingAddUsage = false
    @State private var usageToEdit: Usage?
    @State private var searchText = ""
    @State private var selectedUsageID: Usage.ID?
    @State private var sortColumn: UsageSortColumn = .date
    @State private var sortAscending = false

    private var filteredUsage: [Usage] {
        var result = usageRecords
        if !searchText.isEmpty {
            result = result.filter {
                $0.item?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        result.sort { a, b in
            let cmp: Bool
            switch sortColumn {
            case .date: cmp = a.date < b.date
            case .item: cmp = (a.item?.name ?? "") < (b.item?.name ?? "")
            case .quantity: cmp = a.quantity < b.quantity
            case .estimate: cmp = !a.isEstimate && b.isEstimate
            case .notes: cmp = a.notes < b.notes
            }
            return sortAscending ? cmp : !cmp
        }
        return result
    }

    private func toggleSort(_ column: UsageSortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = column != .date
        }
    }

    var body: some View {
        NavigationStack {
            Table(filteredUsage, selection: $selectedUsageID) {
                TableColumn("Date") { usage in
                    Text(usage.date, format: .dateTime.month(.abbreviated).day().year())
                }
                .width(min: 90, ideal: 110)

                TableColumn("Item") { usage in
                    Text(usage.item?.name ?? "Unknown")
                        .lineLimit(1)
                }
                .width(min: 150, ideal: 220)

                TableColumn("Qty Used") { usage in
                    if let item = usage.item {
                        Text("\(usage.quantity) \(item.unit.abbreviation)")
                            .foregroundStyle(.red)
                    } else {
                        Text("\(usage.quantity)")
                            .foregroundStyle(.red)
                    }
                }
                .width(70)

                TableColumn("Est.") { usage in
                    if usage.isEstimate {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.teal)
                    }
                }
                .width(35)

                TableColumn("Notes") { usage in
                    Text(usage.notes.isEmpty ? "-" : usage.notes)
                        .foregroundStyle(usage.notes.isEmpty ? .tertiary : .secondary)
                        .lineLimit(1)
                }
                .width(min: 80, ideal: 150)
            }
            .contextMenu(forSelectionType: Usage.ID.self) { ids in
                if let id = ids.first, let usage = usageRecords.first(where: { $0.id == id }) {
                    Button("Edit") { usageToEdit = usage }
                    Divider()
                    Button("Delete", role: .destructive) {
                        modelContext.delete(usage)
                        if selectedUsageID == id { selectedUsageID = nil }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by item name")
            .navigationTitle("Usage")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddUsage = true }) {
                        Label("Record Usage", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        ForEach([
                            ("Date", UsageSortColumn.date),
                            ("Item", UsageSortColumn.item),
                            ("Quantity", UsageSortColumn.quantity),
                            ("Estimate", UsageSortColumn.estimate),
                        ], id: \.1) { title, column in
                            Button {
                                toggleSort(column)
                            } label: {
                                HStack {
                                    Text(title)
                                    if sortColumn == column {
                                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    .menuIndicator(.hidden)
                }
            }
            .sheet(isPresented: $showingAddUsage) {
                AddUsageView()
            }
            .sheet(item: $usageToEdit) { usage in
                EditUsageView(usage: usage)
            }
        }
    }
}

#Preview {
    UsageListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
