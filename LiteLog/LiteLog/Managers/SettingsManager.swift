import Foundation
import SwiftUI
import Combine
import CoreData
import os

final class SettingsManager: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "SettingsManager")
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    
    weak var context: NSManagedObjectContext?
    
    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }

    private enum Keys {
        static let weightUnit = "weightUnit"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationTime = "notificationTime"
        static let language = "language"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let nickname = "nickname"
    }
    
    @Published var weightUnit: WeightUnit {
        didSet {
            defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit)
            updateWeightUnitInDatabase()
        }
    }
    
    private func updateWeightUnitInDatabase() {
        guard let context = context else { return }

        Task { @MainActor in
            let request = UserProfile.fetchRequest()
            do {
                let profiles = try context.fetch(request)
                if let profile = profiles.first {
                    profile.weightUnit = weightUnit.rawValue
                    profile.updatedAt = Date()
                    try context.save()
                } else {
                    let newProfile = UserProfile.create(in: context)
                    newProfile.weightUnit = weightUnit.rawValue
                    try context.save()
                }
            } catch {
                Self.logger.error("Failed to update weight unit in database: \(error.localizedDescription)")
            }
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        }
    }

    @Published var notificationTime: Date {
        didSet {
            defaults.set(notificationTime, forKey: Keys.notificationTime)
        }
    }

    @AppStorage(Keys.language) var language: String = "system"

    @AppStorage(Keys.hasCompletedOnboarding) var hasCompletedOnboarding: Bool = false
    
    @AppStorage(Keys.nickname) var nickname: String = ""
    
    @Published private(set) var avatarUpdatedToken = UUID()
    
    private var avatarFileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("cached_avatar.png")
    }
    
    var avatarImage: UIImage? {
        guard FileManager.default.fileExists(atPath: avatarFileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: avatarFileURL) else { return nil }
        return UIImage(data: data)
    }
    
    @discardableResult
    func saveAvatar(_ image: UIImage) -> Bool {
        let scaledImage = image.scaledToSize(CGSize(width: 120, height: 120))
        guard let data = scaledImage.pngData() else {
            return false
        }

        do {
            try data.write(to: avatarFileURL, options: .atomic)
            avatarUpdatedToken = UUID()
            return true
        } catch {
            Self.logger.error("Failed to save local avatar: \(error.localizedDescription)")
            return false
        }
    }
    
    @discardableResult
    func removeAvatar() -> Bool {
        guard FileManager.default.fileExists(atPath: avatarFileURL.path) else {
            avatarUpdatedToken = UUID()
            return true
        }

        do {
            try FileManager.default.removeItem(at: avatarFileURL)
            avatarUpdatedToken = UUID()
            return true
        } catch {
            Self.logger.error("Failed to remove local avatar: \(error.localizedDescription)")
            return false
        }
    }

    private init() {
        defaults.removeObject(forKey: "avatarUrl")
        defaults.removeObject(forKey: "avatarUrlHash")
        defaults.removeObject(forKey: "iCloudSyncEnabled")
        defaults.removeObject(forKey: "appEnvironment")
        defaults.removeObject(forKey: "dev_server_url")

        let savedUnit = defaults.string(forKey: Keys.weightUnit) ?? WeightUnit.kg.rawValue
        self.weightUnit = WeightUnit(rawValue: savedUnit) ?? .kg

        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        self.notificationTime = defaults.object(forKey: Keys.notificationTime) as? Date ?? Self.defaultNotificationTime()
    }

    static func defaultNotificationTime() -> Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    func resetToDefaults() {
        weightUnit = .kg
        notificationsEnabled = false
        notificationTime = Self.defaultNotificationTime()
    }
    
    var displayName: String {
        guard !nickname.isEmpty else {
            return "User"
        }
        return nickname
    }
}
