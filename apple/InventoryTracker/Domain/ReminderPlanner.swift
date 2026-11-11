import Foundation

nonisolated struct ReminderInput {
    var id: String
    var name: String
    var needsReorder: Bool
    var daysUntilReorder: Int?
    var expirationsInStock: [String]
}

nonisolated struct PlannedReminder: Equatable {
    var id: String
    var day: String
    var title: String
    var body: String
}

nonisolated enum ReminderPlanner {
    static let expirationLeadDays = 14
    static let maxReminders = 30

    static func plan(_ inputs: [ReminderInput], today: String) -> [PlannedReminder] {
        let tomorrow = Day.offset(today, by: 1)
        var reminders: [PlannedReminder] = []
        for input in inputs {
            if let soonest = input.expirationsInStock.filter({ $0 > today }).min() {
                reminders.append(PlannedReminder(
                    id: "expire-\(input.id)",
                    day: max(Day.offset(soonest, by: -expirationLeadDays), tomorrow),
                    title: "Expiring soon",
                    body: "\(input.name) expires on \(Format.longDate(soonest))."
                ))
            }
            if !input.needsReorder, let days = input.daysUntilReorder, days > 0 {
                reminders.append(PlannedReminder(
                    id: "low-\(input.id)",
                    day: Day.offset(today, by: days),
                    title: "Running low",
                    body: "\(input.name) is probably running low. Check the shelf."
                ))
            }
        }
        return Array(reminders.sorted { ($0.day, $0.id) < ($1.day, $1.id) }.prefix(maxReminders))
    }
}
