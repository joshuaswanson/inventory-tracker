import SwiftUI
import SwiftData
import PhotosUI
import Charts

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item

    @State private var showingEditItem = false
    @State private var showingAddPurchase = false
    @State private var showingAddUsage = false
    @FocusState private var isNotesFocused: Bool

    private var stockPercentage: Double {
        guard item.reorderLevel > 0 else { return 1.0 }
        return min(Double(item.currentInventory) / Double(item.reorderLevel * 2), 1.0)
    }

    private var stockColor: Color {
        if item.needsReorder { return .orange }
        if stockPercentage > 0.5 { return .green }
        return .yellow
    }

    private func weeklyActivityData(weekCount: Int) -> [WeeklyActivity] {
        let calendar = Calendar.current
        let today = Date()

        guard let weeksAgo = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: today) else {
            return []
        }
        let startOfPeriod = calendar.startOfWeek(for: weeksAgo)

        var weekBuckets: [Date: (purchases: Int, usage: Int)] = [:]

        for weekOffset in 0..<weekCount {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfPeriod) {
                let normalizedWeekStart = calendar.startOfWeek(for: weekStart)
                weekBuckets[normalizedWeekStart] = (purchases: 0, usage: 0)
            }
        }

        for purchase in item.purchases where purchase.date >= startOfPeriod {
            let weekStart = calendar.startOfWeek(for: purchase.date)
            var bucket = weekBuckets[weekStart] ?? (purchases: 0, usage: 0)
            bucket.purchases += purchase.quantity
            weekBuckets[weekStart] = bucket
        }

        for usage in item.usageRecords where usage.date >= startOfPeriod {
            let weekStart = calendar.startOfWeek(for: usage.date)
            var bucket = weekBuckets[weekStart] ?? (purchases: 0, usage: 0)
            bucket.usage += usage.quantity
            weekBuckets[weekStart] = bucket
        }

        return weekBuckets.map { date, values in
            WeeklyActivity(weekStart: date, purchases: values.purchases, usage: values.usage)
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    var body: some View {
        GeometryReader { outerGeometry in
        ScrollView {
            VStack(spacing: 12) {
                // Hero Card - Inventory Status
                heroCard

                // Activity Chart
                activityChart(containerWidth: outerGeometry.size.width)

                // Pricing & Expiration Row
                HStack(spacing: 12) {
                    if item.lowestPricePaid != nil || item.averagePricePaid != nil {
                        pricingCard
                    }

                    if item.isPerishable {
                        expirationCard
                    }
                }

                // Vendors
                vendorsCard

                // Recent Activity
                recentPurchasesCard
                recentUsageCard

                // Notes
                notesCard
            }
            .padding()
        }
        } // GeometryReader
        .contentShape(Rectangle())
        .onTapGesture {
            isNotesFocused = false
        }
        .background(Color.primary.opacity(0.03))
        .navigationTitle(item.name)
        .onAppear {
            // Prevent notes from auto-focusing - delay needed because system focus happens after onAppear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNotesFocused = false
            }
        }
        .sheet(isPresented: $showingEditItem) {
            EditItemView(item: item)
        }
        .sheet(isPresented: $showingAddPurchase) {
            AddPurchaseView(preselectedItem: item)
        }
        .sheet(isPresented: $showingAddUsage) {
            AddUsageView(preselectedItem: item)
        }
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack {
                if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Current Stock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if item.isPerishable {
                            Image(systemName: "leaf.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(item.currentInventory)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(item.unit.abbreviation)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                stockIndicator
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(stockColor.gradient)
                            .frame(width: geometry.size.width * stockPercentage, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Reorder at \(item.reorderLevel) \(item.unit.abbreviation)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let days = item.estimatedDaysUntilReorder {
                        Text(days <= 0 ? "Reorder now" : "\(days) days until reorder")
                            .font(.footnote)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Activity Chart
    private func activityChart(containerWidth: CGFloat) -> some View {
        // Compute week count from available width
        // containerWidth is the full view width; subtract padding (32), card padding (32), Y axis (~40)
        let chartHeight: CGFloat = 150
        let plotWidth = containerWidth - 104
        let weekCount = max(4, min(26, Int(plotWidth / (chartHeight * 0.38))))
        let data = weeklyActivityData(weekCount: weekCount)
        let hasData = data.contains { $0.purchases > 0 || $0.usage > 0 }
        let weeksWithUsage = data.filter { $0.usage > 0 }
        let avgWeeklyUsage = weeksWithUsage.isEmpty ? 0.0
            : Double(weeksWithUsage.reduce(0) { $0 + $1.usage }) / Double(weeksWithUsage.count)
        let avgDailyUsage = avgWeeklyUsage / 7

        return VStack(alignment: .leading, spacing: 12) {
            Label("Activity", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(.teal)

            if hasData {
                Chart {
                    ForEach(data) { week in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Quantity", Double(week.purchases))
                        )
                        .foregroundStyle(Color.green.gradient)

                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Quantity", Double(-week.usage))
                        )
                        .foregroundStyle(Color.red.gradient)
                    }

                    RuleMark(y: .value("Quantity", 0.0))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text("\(Int(abs(doubleValue)))")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisGridLine()
                        AxisValueLabel(centered: true) {
                            if let date = value.as(Date.self) {
                                let calendar = Calendar.current
                                let endOfWeek = calendar.date(byAdding: .day, value: 6, to: date) ?? date
                                let sameMonth = calendar.component(.month, from: date) == calendar.component(.month, from: endOfWeek)
                                let startFormat = date.formatted(.dateTime.month(.abbreviated).day())
                                let endFormat = sameMonth
                                    ? endOfWeek.formatted(.dateTime.day())
                                    : endOfWeek.formatted(.dateTime.month(.abbreviated).day())
                                Text("\(startFormat) - \(endFormat)")
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if avgWeeklyUsage > 0,
                           let yPosition = proxy.position(forY: -avgWeeklyUsage) {
                            let lineY = yPosition
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: lineY))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: lineY))
                            }
                            .stroke(.blue.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))

                            Text(String(format: "~%.1f/day", avgDailyUsage))
                                .font(.system(size: 9))
                                .foregroundStyle(.blue)
                                .position(x: 35, y: lineY - 8)
                        }
                    }
                }
                .frame(height: chartHeight)

                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green.gradient)
                            .frame(width: 10, height: 10)
                        Text("Purchased")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red.gradient)
                            .frame(width: 10, height: 10)
                        Text("Used")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if avgWeeklyUsage > 0 {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(.blue.opacity(0.6))
                                .frame(width: 12, height: 1)
                            Text("Avg usage")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("Last \(weekCount) weeks")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var stockIndicator: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(stockColor.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: item.needsReorder ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(stockColor)
            }
            Text(item.needsReorder ? "Low Stock" : "In Stock")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(stockColor)
        }
    }

    // MARK: - Pricing Card
    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pricing", systemImage: "dollarsign.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            HStack(spacing: 20) {
                if let lowest = item.lowestPricePaid {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best Price")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(lowest, format: .currency(code: "USD"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        if let purchase = item.lowestPricePurchase, let vendor = purchase.vendor {
                            Text(vendor.name)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let average = item.averagePricePaid {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(average, format: .currency(code: "USD"))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Expiration Card
    private var expirationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Expiration", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            if let nextExpiring = item.nextExpiringPurchase {
                HStack {
                    if let days = nextExpiring.daysUntilExpiration {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next Expiring")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("\(days) days")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(expirationColor(days: days))
                        }
                    }

                    Spacer()

                    if let expDate = nextExpiring.expirationDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Date")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(expDate, style: .date)
                                .font(.subheadline)
                        }
                    }
                }

                let expiringItems = item.expiringWithin30Days
                if !expiringItems.isEmpty {
                    Divider()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(expiringItems.count) batch(es) expiring within 30 days")
                            .font(.subheadline)
                    }
                }
            } else {
                Text("No expiring items")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Vendors Card
    private var vendorsCard: some View {
        let uniqueVendors: [Vendor] = {
            var seenIDs = Set<UUID>()
            return item.purchases
                .compactMap { $0.vendor }
                .filter { seenIDs.insert($0.id).inserted }
                .sorted { $0.name < $1.name }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            Label("Vendors", systemImage: "building.2.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            if uniqueVendors.isEmpty {
                Text("No vendors yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(uniqueVendors, id: \.id) { vendor in
                        let vendorPurchases = vendor.purchasesForItem(item)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vendor.name)
                                    .font(.subheadline)
                                Text("\(vendorPurchases.count) purchase\(vendorPurchases.count == 1 ? "" : "s")")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let bestPrice = vendor.lowestPriceForItem(item) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(bestPrice, format: .currency(code: "USD"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("best price")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        if vendor.id != uniqueVendors.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Purchases Card
    private var recentPurchasesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent Purchases", systemImage: "cart.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)
                if !item.purchases.isEmpty {
                    Text("\(item.purchases.count) total")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { showingAddPurchase = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
            }

            if item.purchases.isEmpty {
                Text("No purchases yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(item.purchases.sorted { $0.date > $1.date }.prefix(3), id: \.id) { purchase in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(purchase.date, style: .date)
                                    .font(.subheadline)
                                if let vendor = purchase.vendor {
                                    Text(vendor.name)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(purchase.pricePerUnit, format: .currency(code: "USD"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(purchase.quantity) \(item.unit.abbreviation)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        if purchase.id != item.purchases.sorted(by: { $0.date > $1.date }).prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Usage Card
    private var recentUsageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent Usage", systemImage: "chart.line.downtrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(.blue)
                if !item.usageRecords.isEmpty {
                    Text("\(item.usageRecords.count) total")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { showingAddUsage = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if item.usageRecords.isEmpty {
                Text("No usage recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(item.usageRecords.sorted { $0.date > $1.date }.prefix(3), id: \.id) { usage in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(usage.date, style: .date)
                                    .font(.subheadline)
                                if usage.isEstimate {
                                    Text("Estimated")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("-\(usage.quantity) \(item.unit.abbreviation)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                        if usage.id != item.usageRecords.sorted(by: { $0.date > $1.date }).prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
                .contentShape(Rectangle())
                .onTapGesture {
                    isNotesFocused = true
                }
            TextEditor(text: $item.notes)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
                .focused($isNotesFocused)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            isNotesFocused = true
        }
    }

    private func expirationColor(days: Int) -> Color {
        if days < 0 { return .red }
        if days <= 7 { return .orange }
        if days <= 30 { return .yellow }
        return .green
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text(unit)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Weekly Activity Data
struct WeeklyActivity: Identifiable {
    let id = UUID()
    let weekStart: Date
    let purchases: Int
    let usage: Int
}

// MARK: - Calendar Extension
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

struct EditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Item

    @State private var name: String = ""
    @State private var selectedUnit: UnitOfMeasure = .each
    @State private var reorderLevel: Int = 10
    @State private var isPerishable: Bool = false
    @State private var notes: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    HStack {
                        if let imageData, let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Select Photo", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.bordered)

                            if imageData != nil {
                                Button(role: .destructive) {
                                    imageData = nil
                                    selectedPhoto = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Item Details") {
                    TextField("Item Name", text: $name)

                    Picker("Unit of Measure", selection: $selectedUnit) {
                        ForEach(UnitOfMeasure.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }

                    Stepper("Reorder Level: \(reorderLevel)", value: $reorderLevel, in: 0...1000)

                    Toggle("Perishable Item", isOn: $isPerishable)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
            .formStyle(.grouped)
                        .navigationTitle("Edit Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = item.name
                selectedUnit = item.unit
                reorderLevel = item.reorderLevel
                isPerishable = item.isPerishable
                notes = item.notes
                imageData = item.imageData
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 350)
        #endif
    }

    private func saveChanges() {
        item.name = name
        item.unitOfMeasure = selectedUnit.rawValue
        item.reorderLevel = reorderLevel
        item.isPerishable = isPerishable
        item.notes = notes
        item.imageData = imageData
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: Item(name: "Sample Item", reorderLevel: 5))
    }
    .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
