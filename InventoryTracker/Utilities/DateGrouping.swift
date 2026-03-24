import Foundation

enum DateGroup: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case earlier = "Earlier"
}

struct DateGrouper {
    static func group<T>(_ items: [T], by dateKeyPath: KeyPath<T, Date>, oldestFirst: Bool = false) -> [(String, [T])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today) ?? today

        var buckets: [DateGroup: [T]] = [:]
        for group in DateGroup.allCases {
            buckets[group] = []
        }

        for item in items {
            let itemDate = calendar.startOfDay(for: item[keyPath: dateKeyPath])
            if itemDate >= today {
                buckets[.today]?.append(item)
            } else if itemDate >= yesterday {
                buckets[.yesterday]?.append(item)
            } else if itemDate >= weekAgo {
                buckets[.thisWeek]?.append(item)
            } else if itemDate >= monthAgo {
                buckets[.thisMonth]?.append(item)
            } else {
                buckets[.earlier]?.append(item)
            }
        }

        let order: [DateGroup] = oldestFirst
            ? [.earlier, .thisMonth, .thisWeek, .yesterday, .today]
            : [.today, .yesterday, .thisWeek, .thisMonth, .earlier]

        return order.compactMap { group in
            guard let items = buckets[group], !items.isEmpty else { return nil }
            return (group.rawValue, items)
        }
    }
}
