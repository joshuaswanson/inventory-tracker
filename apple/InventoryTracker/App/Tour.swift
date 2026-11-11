import SwiftData
import SwiftUI

nonisolated enum TourStep: Int, CaseIterable {
    case dashboard, items, purchases, reorder, settings

    var title: String {
        switch self {
        case .dashboard: "Your dashboard"
        case .items: "Your items"
        case .purchases: "What you buy"
        case .reorder: "What to reorder"
        case .settings: "Backups are automatic"
        }
    }

    var message: String {
        switch self {
        case .dashboard: "This is the first thing you see. It shows what is running low and what expires soon."
        case .items: "Everything you stock is listed here. Click an item to see its details. Every month or two, press Count Stock and correct any numbers that are off."
        case .purchases: "Add a purchase when an order arrives, or import your orders from SupplyClinic. Your stock goes up by itself."
        case .reorder: "Items that run low show up here. Press Reorder List for a ready-made shopping list."
        case .settings: "Your inventory is saved every day by itself. Settings is where you find your backups and turn on reminders."
        }
    }

    var section: AppSection {
        switch self {
        case .dashboard, .reorder, .settings: .dashboard
        case .items: .items
        case .purchases: .purchases
        }
    }

    var next: TourStep? { TourStep(rawValue: rawValue + 1) }
    var previous: TourStep? { TourStep(rawValue: rawValue - 1) }
    var position: String { "\(rawValue + 1) of \(Self.allCases.count)" }
}

enum Tour {
    /// An empty inventory gets practice items so every screen has something to show.
    static func start(router: Router, context: ModelContext) {
        let itemCount = (try? context.fetchCount(FetchDescriptor<Item>())) ?? 0
        if itemCount == 0 {
            try? BackupMerge.merge(SampleData.backup(), into: context)
        }
        router.sheet = nil
        router.showTour(.dashboard)
    }
}

struct TourCard: View {
    let step: TourStep
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    private var hasPracticeItems: Bool { SampleData.hasSamples(in: items) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(step.position)
                    .sectionLabel(size: 11)
                Spacer()
                Button("Skip Tour") { router.tourStep = nil }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(step.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(step.message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if step.next == nil, hasPracticeItems {
                Text("The items you just saw are practice items.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 8) {
                if let previous = step.previous {
                    Button("Back") { router.showTour(previous) }
                        .buttonStyle(.themedSecondary)
                }
                Spacer()
                if let next = step.next {
                    Button("Next") { router.showTour(next) }
                        .buttonStyle(.themedPrimary)
                } else if hasPracticeItems {
                    Button("Keep for Now") { router.tourStep = nil }
                        .buttonStyle(.themedSecondary)
                    Button("Remove Practice Items") {
                        try? SampleData.remove(from: modelContext)
                        router.tourStep = nil
                    }
                    .buttonStyle(.themedPrimary)
                } else {
                    Button("Done") { router.tourStep = nil }
                        .buttonStyle(.themedPrimary)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: 480)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.primary, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 6)
    }
}
