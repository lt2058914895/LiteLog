import Foundation
import SwiftUI
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let weightUnit = "weightUnit"
        static let heightUnit = "heightUnit"
        static let healthKitEnabled = "healthKitEnabled"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationTime = "notificationTime"
        static let reminderTime = "reminderTime"
        static let language = "language"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isLoggedIn = "isLoggedIn"
        static let userId = "userId"
    }

    @Published var weightUnit: WeightUnit {
        didSet {
            defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit)
        }
    }

    @Published var heightUnit: HeightUnit {
        didSet {
            defaults.set(heightUnit.rawValue, forKey: Keys.heightUnit)
        }
    }

    @Published var healthKitEnabled: Bool {
        didSet {
            defaults.set(healthKitEnabled, forKey: Keys.healthKitEnabled)
        }
    }

    @Published var iCloudSyncEnabled: Bool {
        didSet {
            defaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSyncEnabled)
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
    
    @AppStorage(Keys.isLoggedIn) var isLoggedIn: Bool = false
    
    @AppStorage(Keys.userId) var userId: String = ""

    private init() {
        let savedUnit = defaults.string(forKey: Keys.weightUnit) ?? WeightUnit.kg.rawValue
        self.weightUnit = WeightUnit(rawValue: savedUnit) ?? .kg

        let savedHeightUnit = defaults.string(forKey: Keys.heightUnit) ?? HeightUnit.cm.rawValue
        self.heightUnit = HeightUnit(rawValue: savedHeightUnit) ?? .cm

        self.healthKitEnabled = defaults.bool(forKey: Keys.healthKitEnabled)
        self.iCloudSyncEnabled = defaults.bool(forKey: Keys.iCloudSyncEnabled)
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
        healthKitEnabled = false
        iCloudSyncEnabled = true
        notificationsEnabled = false
        notificationTime = Self.defaultNotificationTime()
    }
    
    func login(userId: String) {
        self.userId = userId
        self.isLoggedIn = true
    }
    
    func logout() {
        self.userId = ""
        self.isLoggedIn = false
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
