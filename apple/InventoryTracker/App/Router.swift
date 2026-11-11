import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard, items, vendors, purchases, usage

    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var systemImage: String {
        switch self {
        case .dashboard: "house.fill"
        case .items: "archivebox.fill"
        case .vendors: "building.2.fill"
        case .purchases: "cart.fill"
        case .usage: "chart.bar.doc.horizontal.fill"
        }
    }
}

enum AppRoute: Hashable {
    case item(String)
    case vendor(String)
}

enum ActiveSheet: Identifiable {
    case item(Item?)
    case vendor(Vendor?)
    case purchase(Purchase?, itemID: String?)
    case usage(UsageRecord?, itemID: String?)
    case count(Item)
    case countAll
    case reorder
    case spending
    case data
    case supplyClinic

    var id: String {
        switch self {
        case .item(let item): "item-\(item?.id ?? "new")"
        case .vendor(let vendor): "vendor-\(vendor?.id ?? "new")"
        case .purchase(let purchase, let itemID): "purchase-\(purchase?.id ?? "new")-\(itemID ?? "")"
        case .usage(let record, let itemID): "usage-\(record?.id ?? "new")-\(itemID ?? "")"
        case .count(let item): "count-\(item.id)"
        case .countAll: "count-all"
        case .reorder: "reorder"
        case .spending: "spending"
        case .data: "data"
        case .supplyClinic: "supply-clinic"
        }
    }
}

struct PendingDelete: Identifiable {
    let id = UUID()
    let message: String
    let perform: () -> Void
}

@Observable
final class Router {
    var section: AppSection = .dashboard
    var paths: [AppSection: [AppRoute]] = [:]
    var itemFilter: ItemFilter = .all
    var sheet: ActiveSheet?
    var pendingDelete: PendingDelete?

    func show(_ section: AppSection, itemFilter: ItemFilter = .all) {
        self.itemFilter = itemFilter
        self.section = section
        paths[section] = []
    }

    func open(_ route: AppRoute) {
        paths[section, default: []].append(route)
    }

    func goBack() {
        _ = paths[section]?.popLast()
    }

    func path(for section: AppSection) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[section] ?? [] },
            set: { self.paths[section] = $0 }
        )
    }
}
