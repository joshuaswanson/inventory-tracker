import SwiftUI
import SwiftData

enum UsageSortOption: String, CaseIterable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case quantityHighest = "Highest Quantity"
    case quantityLowest = "Lowest Quantity"
}

struct UsageListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Usage.date, order: .reverse) private var usageRecords: [Usage]

    @State private var showingAddUsage = false
    @State private var searchText = ""
    @State private var usageToEdit: Usage?
    @State private var sortOption: UsageSortOption = .dateNewest
    @State private var showEstimatesOnly = false

    var filteredUsage: [Usage] {
        var result = usageRecords

        if !searchText.isEmpty {
            result = result.filter {
                $0.item?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        if showEstimatesOnly {
            result = result.filter { $0.isEstimate }
        }

        // Apply sorting
        switch sortOption {
        case .dateNewest:
            result.sort { $0.date > $1.date }
        case .dateOldest:
            result.sort { $0.date < $1.date }
        case .quantityHighest:
            result.sort { $0.quantity > $1.quantity }
        case .quantityLowest:
            result.sort { $0.quantity < $1.quantity }
        }

        return result
    }

    // Group usage by date
    private var groupedUsage: [(String, [Usage])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!

        var todayUsage: [Usage] = []
        var thisWeekUsage: [Usage] = []
        var thisMonthUsage: [Usage] = []
        var olderUsage: [Usage] = []

        for usage in filteredUsage {
            let usageDate = calendar.startOfDay(for: usage.date)
            if usageDate >= today {
                todayUsage.append(usage)
            } else if usageDate >= weekAgo {
                thisWeekUsage.append(usage)
            } else if usageDate >= monthAgo {
                thisMonthUsage.append(usage)
            } else {
                olderUsage.append(usage)
            }
        }

        var result: [(String, [Usage])] = []
        if !todayUsage.isEmpty { result.append(("Today", todayUsage)) }
        if !thisWeekUsage.isEmpty { result.append(("This Week", thisWeekUsage)) }
        if !thisMonthUsage.isEmpty { result.append(("This Month", thisMonthUsage)) }
        if !olderUsage.isEmpty { result.append(("Earlier", olderUsage)) }

        return result
    }

    // Summary calculations
    private var totalUsed: Int {
        filteredUsage.reduce(0) { $0 + $1.quantity }
    }

    private var estimatesCount: Int {
        usageRecords.filter { $0.isEstimate }.count
    }

    private var actualCount: Int {
        usageRecords.filter { !$0.isEstimate }.count
    }

    private var uniqueItemsCount: Int {
        Set(filteredUsage.compactMap { $0.item?.id }).count
    }

    // Calculate average daily usage
    private var averageDailyUsage: Double {
        guard !usageRecords.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedRecords = usageRecords.sorted { $0.date < $1.date }

        guard let firstDate = sortedRecords.first?.date,
              let lastDate = sortedRecords.last?.date else { return 0 }

        let daysBetween = max(1, calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1)
        let totalQuantity = usageRecords.reduce(0) { $0 + $1.quantity }

        return Double(totalQuantity) / Double(daysBetween)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Divider()

                if filteredUsage.isEmpty && searchText.isEmpty && !showEstimatesOnly {
                    emptyStateView
                } else if filteredUsage.isEmpty {
                    noResultsView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary Header
                            summaryHeader
                                .padding(.horizontal)
                                .padding(.top, 12)

                            // Grouped List
                            LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                                ForEach(groupedUsage, id: \.0) { section, sectionUsage in
                                    Section {
                                        VStack(spacing: 8) {
                                            ForEach(sectionUsage) { usage in
                                                UsageCardView(usage: usage)
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
                                        .padding(.horizontal)
                                    } header: {
                                        sectionHeader(section)
                                    }
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                    .background(Color.primary.opacity(0.03))
                }
            }
            .navigationTitle("Usage")
            .searchable(text: $searchText, prompt: "Search by item name")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddUsage = true }) {
                        Label("Record Usage", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Toggle(isOn: $showEstimatesOnly) {
                            Label("Estimates Only", systemImage: "sparkle")
                        }

                        Divider()

                        Menu("Sort By") {
                            ForEach(UsageSortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                } label: {
                                    if sortOption == option {
                                        Label(option.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: showEstimatesOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
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

    // MARK: - Summary Header
    private var summaryHeader: some View {
        HStack(spacing: 12) {
            UsageSummaryStatView(
                title: "Records",
                value: "\(filteredUsage.count)",
                icon: "list.bullet.clipboard.fill",
                color: .blue
            )

            UsageSummaryStatView(
                title: "Total Used",
                value: "\(totalUsed)",
                icon: "chart.line.downtrend.xyaxis",
                color: .red
            )

            UsageSummaryStatView(
                title: "Items",
                value: "\(uniqueItemsCount)",
                icon: "shippingbox.fill",
                color: .purple
            )

            if averageDailyUsage > 0 {
                UsageSummaryStatView(
                    title: "Avg/Day",
                    value: String(format: "%.1f", averageDailyUsage),
                    icon: "chart.bar.fill",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Usage Records", systemImage: "chart.line.downtrend.xyaxis")
        } description: {
            Text("Record usage to track consumption rates and forecast reorders.")
        } actions: {
            Button(action: { showingAddUsage = true }) {
                Text("Record Usage")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                showingAddUsage = true
            } label: {
                Label("Record Usage", systemImage: "plus")
            }
        }
    }

    // MARK: - No Results View
    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            if showEstimatesOnly {
                Text("No estimated usage records found.")
            } else {
                Text("No usage records match your search.")
            }
        } actions: {
            if showEstimatesOnly {
                Button("Show All Records") {
                    showEstimatesOnly = false
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Usage Summary Stat View
struct UsageSummaryStatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Usage Card View
struct UsageCardView: View {
    let usage: Usage

    var body: some View {
        HStack(spacing: 12) {
            // Left accent bar - blue for actual, teal for estimate
            RoundedRectangle(cornerRadius: 2)
                .fill((usage.isEstimate ? Color.teal : Color.blue).gradient)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                // Top row: Item name and quantity
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let item = usage.item {
                            HStack(spacing: 6) {
                                Text(item.name)
                                    .font(.headline)
                                    .lineLimit(1)

                                if item.isPerishable {
                                    Image(systemName: "leaf.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }

                            // Current inventory hint
                            HStack(spacing: 4) {
                                Image(systemName: "shippingbox")
                                    .font(.caption2)
                                Text("\(item.currentInventory) \(item.unit.abbreviation) remaining")
                            }
                            .font(.subheadline)
                            .foregroundStyle(item.needsReorder ? .orange : .secondary)
                        } else {
                            Text("Unknown Item")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Quantity badge
                    VStack(alignment: .trailing, spacing: 2) {
                        if let item = usage.item {
                            Text("-\(usage.quantity)")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.red)

                            Text(item.unit.abbreviation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Divider
                Divider()

                // Bottom row: Date and estimate indicator
                HStack {
                    // Date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(usage.date, style: .date)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Spacer()

                    // Estimate/Actual badge
                    HStack(spacing: 4) {
                        Image(systemName: usage.isEstimate ? "sparkle" : "checkmark.circle.fill")
                        Text(usage.isEstimate ? "Estimate" : "Actual")
                    }
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(usage.isEstimate ? .teal : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((usage.isEstimate ? Color.teal : Color.blue).opacity(0.1))
                    .clipShape(Capsule())
                }

                // Notes if present
                if !usage.notes.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.caption2)
                        Text(usage.notes)
                            .lineLimit(2)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    UsageListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
