import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func reschedulePaydayNotifications(for payday: Date, enabled: Bool, calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["payday.tomorrow", "payday.today"])
        guard enabled else { return }

        await schedule(
            id: "payday.today",
            title: String(localized: "Payday is here"),
            body: String(localized: "Start your next pay cycle when you’re ready."),
            date: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: payday) ?? payday,
            calendar: calendar
        )
        if let dayBefore = calendar.date(byAdding: .day, value: -1, to: payday) {
            await schedule(
                id: "payday.tomorrow",
                title: String(localized: "Payday is tomorrow"),
                body: String(localized: "Your current pay cycle is almost done."),
                date: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayBefore) ?? dayBefore,
                calendar: calendar
            )
        }
    }

    private func schedule(id: String, title: String, body: String, date: Date, calendar: Calendar) async {
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }
}
