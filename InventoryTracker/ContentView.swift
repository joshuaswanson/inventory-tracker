import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            ItemsListView()
                .tabItem {
                    Label("Items", systemImage: "shippingbox.fill")
                }
                .tag(1)

            PurchasesListView()
                .tabItem {
                    Label("Purchases", systemImage: "cart.fill")
                }
                .tag(2)

            UsageListView()
                .tabItem {
                    Label("Usage", systemImage: "chart.line.downtrend.xyaxis")
                }
                .tag(3)

            VendorsListView()
                .tabItem {
                    Label("Vendors", systemImage: "building.2.fill")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Vendor.self, Purchase.self, Usage.self], inMemory: true)
}
