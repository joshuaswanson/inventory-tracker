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
    @State private var contextMenuUsageId: UUID?

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

        // Reverse section order when sorting by oldest first
        if sortOption == .dateOldest {
            if !olderUsage.isEmpty { result.append(("Earlier", olderUsage)) }
            if !thisMonthUsage.isEmpty { result.append(("This Month", thisMonthUsage)) }
            if !thisWeekUsage.isEmpty { result.append(("This Week", thisWeekUsage)) }
            if !todayUsage.isEmpty { result.append(("Today", todayUsage)) }
        } else {
            if !todayUsage.isEmpty { result.append(("Today", todayUsage)) }
            if !thisWeekUsage.isEmpty { result.append(("This Week", thisWeekUsage)) }
            if !thisMonthUsage.isEmpty { result.append(("This Month", thisMonthUsage)) }
            if !olderUsage.isEmpty { result.append(("Earlier", olderUsage)) }
        }

        return result
    }

    // Summary calculations
    private var usedLastMonth: Int {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!
        return filteredUsage
            .filter { $0.date >= monthAgo }
            .reduce(0) { $0 + $1.quantity }
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
                        VStack(spacing: 20) {
                            // Summary Header
                            summaryHeader
                                .frame(maxWidth: 700)
                                .padding(.horizontal)
                                .padding(.top, 16)

                            // Grouped List
                            LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                                ForEach(groupedUsage, id: \.0) { section, sectionUsage in
                                    Section {
                                        VStack(spacing: 10) {
                                            ForEach(sectionUsage) { usage in
                                                UsageCardView(usage: usage, isHighlighted: contextMenuUsageId == usage.id)
                                                    .onRightClick {
                                                        contextMenuUsageId = usage.id
                                                    } onDismiss: {
                                                        contextMenuUsageId = nil
                                                    }
                                                    .contextMenu {
                                                        Button {
                                                            contextMenuUsageId = nil
                                                            usageToEdit = usage
                                                        } label: {
                                                            Label("Edit", systemImage: "pencil")
                                                        }

                                                        Divider()

                                                        Button(role: .destructive) {
                                                            contextMenuUsageId = nil
                                                            modelContext.delete(usage)
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                    }
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal)
                                    } header: {
                                        sectionHeader(section)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity)
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
                title: "Used Last Month",
                value: "\(usedLastMonth)",
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
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 110)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Usage Card View
struct UsageCardView: View {
    let usage: Usage
    var isHighlighted: Bool = false

    private var accentColor: Color {
        usage.isEstimate ? .teal : .blue
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left accent bar - blue for actual, teal for estimate
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor.gradient)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 10) {
                // Top row: Item name and quantity
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let item = usage.item {
                            HStack(spacing: 8) {
                                Text(item.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)

                                if item.isPerishable {
                                    Image(systemName: "leaf.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                }
                            }

                            // Current inventory hint
                            HStack(spacing: 5) {
                                Image(systemName: "shippingbox")
                                    .font(.caption)
                                Text("\(item.currentInventory) \(item.unit.abbreviation) remaining")
                            }
                            .font(.body)
                            .foregroundStyle(item.needsReorder ? .orange : .secondary)
                        } else {
                            Text("Unknown Item")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Quantity badge
                    VStack(alignment: .trailing, spacing: 4) {
                        if let item = usage.item {
                            Text("-\(usage.quantity)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.red)

                            Text(item.unit.abbreviation)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Divider
                Divider()

                // Bottom row: Date and estimate indicator
                HStack {
                    // Date
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.subheadline)
                        Text(usage.date, style: .date)
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)

                    Spacer()

                    // Estimate/Actual badge
                    HStack(spacing: 5) {
                        Image(systemName: usage.isEstimate ? "sparkle" : "checkmark.circle.fill")
                        Text(usage.isEstimate ? "Estimate" : "Actual")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(usage.isEstimate ? .teal : .blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((usage.isEstimate ? Color.teal : Color.blue).opacity(0.1))
                    .clipShape(Capsule())
                }

                // Notes if present
                if !usage.notes.isEmpty {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "note.text")
                            .font(.caption)
                        Text(usage.notes)
                            .lineLimit(2)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
        .padding(16)
        .frame(maxWidth: 700)
        .background(isHighlighted ? accentColor.opacity(0.1) : Color.clear)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accentColor.opacity(isHighlighted ? 0.6 : 0), lineWidth: 2)
        )
    }
}

#Preview {
    UsageListView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
