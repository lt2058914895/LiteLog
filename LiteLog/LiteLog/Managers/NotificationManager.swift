import Foundation
import UserNotifications
import Combine

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private init() {}

    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        await MainActor.run {
            self.isAuthorized = granted
        }
    }

    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    func scheduleDailyReminder(at time: Date) async throws {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: ["daily_weight_reminder"])

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.title", comment: "")
        content.body = NSLocalizedString("notification.body", comment: "")
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily_weight_reminder",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancelDailyReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_weight_reminder"])
    }

    func scheduleWeightReminderNotification(weight: Double, date: Date) async throws {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.weight.recorded.title", comment: "")
        content.body = String(format: NSLocalizedString("notification.weight.recorded.body", comment: ""), weight)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "weight_recorded_\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }
}
