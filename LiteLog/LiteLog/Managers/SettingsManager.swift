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

    @AppStorage(Keys.nickname) var nickname: String = ""
    
    @Published private(set) var avatarUpdatedToken = UUID()
    
    private var avatarDirectoryURL: URL {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return supportDirectory.appendingPathComponent("LiteLog", isDirectory: true)
    }

    private var avatarFileURL: URL {
        avatarDirectoryURL.appendingPathComponent("avatar.png")
    }

    private var legacyAvatarFileURL: URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return documentsDirectory.appendingPathComponent("cached_avatar.png")
    }
    
    var avatarImage: UIImage? {
        if let data = try? Data(contentsOf: avatarFileURL) {
            return UIImage(data: data)
        }
        if let data = try? Data(contentsOf: legacyAvatarFileURL) {
            return UIImage(data: data)
        }
        return nil
    }
    
    @discardableResult
    func saveAvatar(_ image: UIImage) -> Bool {
        let scaledImage = image.scaledToSize(CGSize(width: 120, height: 120))
        guard let data = scaledImage.pngData() else {
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: avatarDirectoryURL,
                withIntermediateDirectories: true
            )
            try data.write(to: avatarFileURL, options: [.atomic, .completeFileProtection])
            try? FileManager.default.removeItem(at: legacyAvatarFileURL)
            avatarUpdatedToken = UUID()
            return true
        } catch {
            Self.logger.error("Failed to save local avatar: \(error.localizedDescription)")
            return false
        }
    }
    
    @discardableResult
    func removeAvatar() -> Bool {
        let files = [avatarFileURL, legacyAvatarFileURL]
        guard files.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            avatarUpdatedToken = UUID()
            return true
        }

        do {
            for file in files where FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.removeItem(at: file)
            }
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
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        defaults.removeObject(forKey: "language")

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

    func performStartupMaintenance() {
        guard !FileManager.default.fileExists(atPath: avatarFileURL.path),
              let image = UIImage(contentsOfFile: legacyAvatarFileURL.path) else {
            return
        }
        _ = saveAvatar(image)
    }
    
    var displayName: String {
        guard !nickname.isEmpty else {
            return NSLocalizedString("common.user", comment: "")
        }
        return nickname
    }
}
