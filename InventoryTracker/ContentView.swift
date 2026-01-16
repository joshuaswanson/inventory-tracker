import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard

    enum AppTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case items = "Items"
        case purchases = "Purchases"
        case usage = "Usage"
        case vendors = "Vendors"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .items: return "shippingbox.fill"
            case .purchases: return "cart.fill"
            case .usage: return "chart.line.downtrend.xyaxis"
            case .vendors: return "building.2.fill"
            }
        }
    }

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(AppTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
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
            DashboardView()
        case .items:
            ItemsListView()
        case .purchases:
            PurchasesListView()
        case .usage:
            UsageListView()
        case .vendors:
            VendorsListView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
