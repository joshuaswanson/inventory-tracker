import SwiftData
import SwiftUI

struct AppShell: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        GeometryReader { geometry in
            let isWide = usesWideLayout(width: geometry.size.width)
            Group {
                if isWide {
                    SidebarLayout()
                } else {
                    TabLayout()
                }
            }
            .environment(\.isWideLayout, isWide)
            .overlay(alignment: isWide ? .bottomTrailing : .bottom) {
                if let step = router.tourStep {
                    TourCard(step: step)
                        .padding(.horizontal, isWide ? 28 : 16)
                        .padding(.bottom, isWide ? 28 : 72)
                }
            }
        }
        .sheet(item: $router.sheet) { sheet in
            SheetContent(sheet: sheet)
        }
        .alert(
            router.pendingDelete?.message ?? "",
            isPresented: Binding(
                get: { router.pendingDelete != nil },
                set: { if !$0 { router.pendingDelete = nil } }
            ),
            presenting: router.pendingDelete
        ) { pending in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { pending.perform() }
        }
        #if os(macOS)
        .frame(minWidth: 1000, minHeight: 720)
        #endif
    }

    private func usesWideLayout(width: CGFloat) -> Bool {
        #if os(macOS)
        true
        #else
        width >= Theme.wideLayoutMinimumWidth
        #endif
    }
}

private struct SheetContent: View {
    let sheet: ActiveSheet

    var body: some View {
        switch sheet {
        case .item(let item): ItemFormView(item: item)
        case .vendor(let vendor): VendorFormView(vendor: vendor)
        case .purchase(let purchase, let itemID): PurchaseFormView(purchase: purchase, preselectedItemID: itemID)
        case .usage(let record, let itemID): UsageFormView(record: record, preselectedItemID: itemID)
        case .count(let item): CountStockView(item: item)
        case .countAll: StockCountView()
        case .reorder: ReorderListView()
        case .spending: SpendingView()
        case .data: DataView()
        case .importOrders: ImportOrdersView()
        case .supplier(let supplier): SupplierImportView(supplier: supplier)
        case .combineItem(let item): CombineItemsView(keeper: item)
        case .combineVendor(let vendor): CombineVendorsView(keeper: vendor)
        case .reviewNewItems(let itemIDs): ReviewImportedItemsView(itemIDs: itemIDs)
        case .duplicates(let kind): DuplicatesView(kind: kind)
        }
    }
}

private struct SectionStack: View {
    let section: AppSection
    @Environment(Router.self) private var router

    var body: some View {
        NavigationStack(path: router.path(for: section)) {
            root
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .item(let id): ItemDetailView(itemID: id)
                    case .vendor(let id): VendorDetailView(vendorID: id)
                    }
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        switch section {
        case .dashboard: DashboardView()
        case .items: ItemsView()
        case .vendors: VendorsView()
        case .purchases: PurchasesView()
        case .usage: UsageView()
        }
    }
}

private struct SidebarLayout: View {
    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            SectionStack(section: router.section)
                .id(router.section)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
        }
        .ignoresSafeArea()
    }
}

private struct Sidebar: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ToothShape()
                    .fill(.white.opacity(0.95))
                    .frame(width: 26, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inventory Tracker")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(-0.3)
                    Text("Dental Supplies")
                        .font(.system(size: 11))
                        .textCase(.uppercase)
                        .tracking(1)
                        .opacity(0.6)
                }
                .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 20)

            Divider().overlay(.white.opacity(0.1))

            VStack(spacing: 2) {
                ForEach(AppSection.allCases) { section in
                    SidebarButton(
                        title: section.title,
                        systemImage: section.systemImage,
                        isActive: router.section == section,
                        isHighlighted: router.tourStep.map { $0 != .settings && $0.section == section } ?? false
                    ) {
                        router.show(section)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)

            Spacer()

            SidebarButton(title: "Settings", systemImage: "gearshape.fill", isActive: false, isHighlighted: router.tourStep == .settings) {
                router.sheet = .data
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .foregroundStyle(.white)
        .frame(width: Theme.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.sidebarGradient)
    }
}

private struct SidebarButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    var isHighlighted = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .frame(width: 20)
                    .opacity(isActive || isHovering ? 1 : 0.7)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isActive || isHovering ? Color.white : Color.white.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(.white, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var background: Color {
        if isActive { return .white.opacity(0.15) }
        return isHovering ? .white.opacity(0.1) : .clear
    }
}

private struct TabLayout: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.section) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    SectionStack(section: section)
                }
            }
        }
    }
}

struct Screen<Actions: View, Content: View>: View {
    let title: String
    var searchPrompt: String?
    var search: Binding<String>?
    @ViewBuilder let actions: Actions
    @ViewBuilder let content: Content
    @Environment(\.isWideLayout) private var isWide

    var body: some View {
        if isWide {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    wideHeader
                    content
                }
                .padding(Theme.pagePadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .toolbar(.hidden)
        } else {
            compactBody
        }
    }

    private var wideHeader: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let search, let searchPrompt {
                SearchField(prompt: searchPrompt, text: search)
            }
            HStack(spacing: 12) { actions }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 36)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var compactBody: some View {
        let page = ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(Theme.compactPadding)
        }
        .background(Theme.background)
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) { actions }
        }

        if let search, let searchPrompt {
            page.searchable(text: search, prompt: searchPrompt)
        } else {
            page
        }
    }
}

struct DetailScreen<Actions: View, Content: View>: View {
    let title: String
    @ViewBuilder let actions: Actions
    @ViewBuilder let content: Content
    @Environment(\.isWideLayout) private var isWide
    @Environment(Router.self) private var router

    var body: some View {
        if isWide {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 16) {
                        Button {
                            router.goBack()
                        } label: {
                            Label(router.section.title, systemImage: "arrow.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Text(title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer(minLength: 16)
                        HStack(spacing: 8) { actions }
                    }
                    .frame(minHeight: 36)
                    .padding(.bottom, 24)
                    content
                }
                .padding(Theme.pagePadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .toolbar(.hidden)
            .navigationBarBackButtonHidden()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(Theme.compactPadding)
            }
            .background(Theme.background)
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) { actions }
            }
        }
    }
}

struct HeaderButton: View {
    let title: String
    let compactImage: String
    let action: () -> Void
    @Environment(\.isWideLayout) private var isWide

    var body: some View {
        if isWide {
            Button(title, action: action).buttonStyle(.themedPrimary)
        } else {
            Button(action: action) {
                Label(title, systemImage: compactImage)
            }
        }
    }
}
