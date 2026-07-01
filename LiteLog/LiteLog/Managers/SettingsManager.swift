import Foundation
import SwiftUI
import Combine
import CoreData

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    
    weak var context: NSManagedObjectContext?
    
    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }

    private enum Keys {
        static let weightUnit = "weightUnit"
        static let heightUnit = "heightUnit"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationTime = "notificationTime"
        static let reminderTime = "reminderTime"
        static let language = "language"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let nickname = "nickname"
        static let avatarUrl = "avatarUrl"
        static let avatarData = "avatarData"
        static let avatarUrlHash = "avatarUrlHash"
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
                    profile.syncStatus = UserProfile.SyncStatus.pending.rawValue
                    try context.save()
                    
                    DataSyncManager.shared.triggerProfileSync(context: context)
                } else {
                    let newProfile = UserProfile.create(in: context)
                    newProfile.weightUnit = weightUnit.rawValue
                    try context.save()
                }
            } catch {
                print("Failed to update weight unit in database: \(error)")
            }
        }
    }

    @Published var heightUnit: HeightUnit {
        didSet {
            defaults.set(heightUnit.rawValue, forKey: Keys.heightUnit)
        }
    }

    @Published var iCloudSyncEnabled: Bool {
        didSet {
            defaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSyncEnabled)
            if iCloudSyncEnabled && !oldValue {
                Task { @MainActor in
                    await handleCloudSyncEnabled()
                }
            }
        }
    }
    
    private func handleCloudSyncEnabled() async {
        guard let context = context else { return }
        
        let maybeOldDeviceId = UserIdentifierManager.shared.checkForSyncedDeviceId()
        if let oldDeviceId = maybeOldDeviceId,
           oldDeviceId != UserIdentifierManager.shared.deviceId {
            
            do {
                let response = try await APIService.shared.fetchAllData()
                
                if let syncContext = PersistenceController.shared.container.viewContext as? NSManagedObjectContext {
                    if let profile = response.profile {
                        try await DataSyncManager.shared.mergeProfileFromCloud(profile, context: syncContext)
                    }
                    if let records = response.records {
                        try await DataSyncManager.shared.mergeRecordsFromCloud(records, context: syncContext)
                    }
                }
                
                UserIdentifierManager.shared.switchToDeviceId(oldDeviceId)
                
                await DataSyncManager.shared.syncLocalDataToCloud(context: context)
                
            } catch {
                print("Failed to merge data from synced device: \(error)")
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
    
    @AppStorage(Keys.avatarUrl) var avatarUrl: String = ""
    
    @Published var avatarCacheUpdated = false
    
    var cachedAvatarImage: UIImage? {
        if let data = defaults.data(forKey: Keys.avatarData),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }
    
    func updateCachedAvatar(with image: UIImage) {
        let scaledImage = image.scaledToSize(CGSize(width: 120, height: 120))
        if let data = scaledImage.pngData() {
            defaults.set(data, forKey: Keys.avatarData)
            defaults.set(avatarUrl.hashValue, forKey: Keys.avatarUrlHash)
            avatarCacheUpdated.toggle()
        }
    }
    
    func clearCachedAvatar() {
        defaults.removeObject(forKey: Keys.avatarData)
        defaults.removeObject(forKey: Keys.avatarUrlHash)
    }
    
    var isAvatarCached: Bool {
        let cachedHash = defaults.integer(forKey: Keys.avatarUrlHash)
        if cachedHash == avatarUrl.hashValue {
            return cachedAvatarImage != nil
        }
        return false
    }

    private init() {
        let savedUnit = defaults.string(forKey: Keys.weightUnit) ?? WeightUnit.kg.rawValue
        self.weightUnit = WeightUnit(rawValue: savedUnit) ?? .kg

        let savedHeightUnit = defaults.string(forKey: Keys.heightUnit) ?? HeightUnit.cm.rawValue
        self.heightUnit = HeightUnit(rawValue: savedHeightUnit) ?? .cm

        self.iCloudSyncEnabled = defaults.bool(forKey: Keys.iCloudSyncEnabled) || defaults.object(forKey: Keys.iCloudSyncEnabled) == nil
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
        heightUnit = .cm
        iCloudSyncEnabled = true
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

enum HeightUnit: String, Codable, CaseIterable {
    case cm
    case inch

    var displayName: String {
        switch self {
        case .cm:
            return NSLocalizedString("unit.cm", comment: "")
        case .inch:
            return NSLocalizedString("unit.inch", comment: "")
        }
    }

    func convert(_ value: Double, to unit: HeightUnit) -> Double {
        if self == unit { return value }
        switch (self, unit) {
        case (.cm, .inch):
            return value / 2.54
        case (.inch, .cm):
            return value * 2.54
        default:
            return value
        }
    }

    func convertToCm(_ value: Double) -> Double {
        switch self {
        case .cm: return value
        case .inch: return value * 2.54
        }
    }

    func convertFromCm(_ valueInCm: Double) -> Double {
        switch self {
        case .cm: return valueInCm
        case .inch: return valueInCm / 2.54
        }
    }
}