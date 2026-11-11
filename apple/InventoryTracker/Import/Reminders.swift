import Foundation
import SwiftData
import UserNotifications

enum Reminders {
    static let enabledKey = "remindersEnabled"
    private static let deliveryHour = 9

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }

        let today = Day.today
        let items = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        let inputs = items.map { item in
            let metrics = item.metrics(today: today)
            return ReminderInput(
                id: item.id,
                name: item.name,
                needsReorder: metrics.needsReorder,
                daysUntilReorder: metrics.daysUntilReorder,
                expirationsInStock: metrics.batches.filter { $0.remaining > 0 }.compactMap(\.expirationDate)
            )
        }
        for reminder in ReminderPlanner.plan(inputs, today: today) {
            guard let date = Day.localDate(from: reminder.day) else { continue }
            var when = Calendar.current.dateComponents([.year, .month, .day], from: date)
            when.hour = deliveryHour
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
