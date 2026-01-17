import SwiftUI
import SwiftData

struct UsageListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Usage.date, order: .reverse) private var usageRecords: [Usage]

    @State private var showingAddUsage = false
    @State private var searchText = ""
    @State private var usageToEdit: Usage?

    var filteredUsage: [Usage] {
        if searchText.isEmpty {
            return usageRecords
        }
        return usageRecords.filter {
            $0.item?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredUsage.isEmpty {
                    ContentUnavailableView {
                        Label("No Usage Records", systemImage: "chart.line.downtrend.xyaxis")
                    } description: {
                        Text("Record usage to track consumption rates and forecast reorders.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredUsage) { usage in
                            UsageRowView(usage: usage)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(usage)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        usageToEdit = usage
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        modelContext.delete(usage)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Usage")
            .searchable(text: $searchText, prompt: "Search usage records")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddUsage = true }) {
                        Label("Record Usage", systemImage: "plus")
                    }
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

struct UsageRowView: View {
    let usage: Usage

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let item = usage.item {
                    Text(item.name)
                        .font(.headline)

                    HStack {
                        Text(usage.date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if usage.isEstimate {
                            Label("Estimate", systemImage: "sparkle")
                                .font(.footnote)
                                .foregroundStyle(.blue)
                        }
                    }
                } else {
                    Text("Unknown Item")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let item = usage.item {
                Text("-\(usage.quantity) \(item.unit.abbreviation)")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}

#Preview {
    UsageListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
