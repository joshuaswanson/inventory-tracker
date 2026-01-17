import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(filter: #Predicate<Item> { !$0.isDeleted }) private var items: [Item]
    @Query(filter: #Predicate<Vendor> { !$0.isDeleted }) private var vendors: [Vendor]
    @State private var selectedTab: AppTab = .dashboard

    enum AppTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case items = "Items"
        case purchases = "Purchases"
        case usage = "Usage"
        case vendors = "Vendors"
        case recentlyDeleted = "Recently Deleted"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .items: return "shippingbox.fill"
            case .purchases: return "cart.fill"
            case .usage: return "chart.line.downtrend.xyaxis"
            case .vendors: return "building.2.fill"
            case .recentlyDeleted: return "trash"
            }
        }
    }

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.icon)
                    .tag(AppTab.dashboard)

                Section("Inventory") {
                    HStack {
                        Label(AppTab.items.rawValue, systemImage: AppTab.items.icon)
                        Spacer()
                        Text("\(items.count)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .tag(AppTab.items)
                    HStack {
                        Label(AppTab.vendors.rawValue, systemImage: AppTab.vendors.icon)
                        Spacer()
                        Text("\(vendors.count)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .tag(AppTab.vendors)
                }

                Section("Activity") {
                    Label(AppTab.purchases.rawValue, systemImage: AppTab.purchases.icon)
                        .tag(AppTab.purchases)
                    Label(AppTab.usage.rawValue, systemImage: AppTab.usage.icon)
                        .tag(AppTab.usage)
                }

                Section("Utilities") {
                    Label(AppTab.recentlyDeleted.rawValue, systemImage: AppTab.recentlyDeleted.icon)
                        .tag(AppTab.recentlyDeleted)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            selectedView
                .frame(minWidth: 400, minHeight: 300)
        }
        .frame(minWidth: 600, minHeight: 400)
        #else
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                selectedView(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        #endif
    }

    @ViewBuilder
    private var selectedView: some View {
        selectedView(for: selectedTab)
    }

    @ViewBuilder
    private func selectedView(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView(selectedTab: $selectedTab)
        case .items:
            ItemsListView()
        case .purchases:
            PurchasesListView()
        case .usage:
            UsageListView()
        case .vendors:
            VendorsListView()
        case .recentlyDeleted:
            RecentlyDeletedView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
