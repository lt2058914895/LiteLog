import Foundation
import UserNotifications
import Combine
import CoreData
import os

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "NotificationManager")
    
    @Published var isAuthorized = false
    @Published var streakDays: Int = 0

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

    func scheduleWeightLossCelebrationNotification(lossAmount: Double, currentWeight: Double) async throws {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.weight.loss.title", comment: "")
        content.body = String(format: NSLocalizedString("notification.weight.loss.body", comment: ""), lossAmount, currentWeight)
        content.sound = .default
        content.categoryIdentifier = "celebration"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "weight_loss_celebration_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func scheduleMilestoneNotification(milestone: String) async throws {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.milestone.title", comment: "")
        content.body = String(format: NSLocalizedString("notification.milestone.body", comment: ""), milestone)
        content.sound = .default
        content.categoryIdentifier = "milestone"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "milestone_\(milestone.lowercased())_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func calculateStreakDays(context: NSManagedObjectContext) -> Int {
        let request = WeightRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]
        request.fetchLimit = 30

        do {
            let records = try context.fetch(request)
            
            var streak = 0
            let calendar = Calendar.current
            var currentDate = Date()
            
            for record in records {
                let daysBetween = calendar.dateComponents([.day], from: record.date, to: currentDate).day ?? 0
                
                if daysBetween == 1 {
                    streak += 1
                    currentDate = record.date
                } else if daysBetween == 0 {
                    currentDate = record.date
                } else {
                    break
                }
            }
            
            if !records.isEmpty {
                streak += 1
            }
            
            DispatchQueue.main.async {
                self.streakDays = streak
            }
            
            return streak
        } catch {
            Self.logger.error("Error calculating streak: \(error.localizedDescription)")
            return 0
        }
    }

    func scheduleStreakNotification(streak: Int) async throws {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.streak.title", comment: "")
        content.body = String(format: NSLocalizedString("notification.streak.body", comment: ""), streak)
        content.sound = .default
        content.categoryIdentifier = "streak"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "streak_\(streak)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func suggestOptimalReminderTime(context: NSManagedObjectContext) -> Date? {
        let request = WeightRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]
        request.fetchLimit = 20

        do {
            let records = try context.fetch(request)
            
            if records.isEmpty {
                let calendar = Calendar.current
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
            }

            var hourCounts: [Int: Int] = [:]
            let calendar = Calendar.current

            for record in records {
                let hour = calendar.component(.hour, from: record.date)
                hourCounts[hour, default: 0] += 1
            }

            if let mostFrequentHour = hourCounts.max(by: { $0.value < $1.value })?.key {
                return calendar.date(bySettingHour: mostFrequentHour, minute: 0, second: 0, of: Date())
            }

            return nil
        } catch {
            Self.logger.error("Error suggesting reminder time: \(error.localizedDescription)")
            return nil
        }
    }
}
