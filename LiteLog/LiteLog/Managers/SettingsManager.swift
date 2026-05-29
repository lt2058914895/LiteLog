import Foundation
import SwiftUI
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let weightUnit = "weightUnit"
        static let heightUnit = "heightUnit"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationTime = "notificationTime"
        static let reminderTime = "reminderTime"
        static let language = "language"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isLoggedIn = "isLoggedIn"
        static let userId = "userId"
        static let userPhone = "userPhone"
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
    
    @AppStorage(Keys.userPhone) var userPhone: String = ""

    private init() {
        let savedUnit = defaults.string(forKey: Keys.weightUnit) ?? WeightUnit.kg.rawValue
        self.weightUnit = WeightUnit(rawValue: savedUnit) ?? .kg

        let savedHeightUnit = defaults.string(forKey: Keys.heightUnit) ?? HeightUnit.cm.rawValue
        self.heightUnit = HeightUnit(rawValue: savedHeightUnit) ?? .cm

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
        iCloudSyncEnabled = true
        notificationsEnabled = false
        notificationTime = Self.defaultNotificationTime()
    }
    
    func login(userId: String, phone: String? = nil) {
        self.userId = userId
        if let phone = phone {
            self.userPhone = phone
        }
        self.isLoggedIn = true
    }
    
    func logout() {
        self.userId = ""
        self.userPhone = ""
        self.isLoggedIn = false
    }
    
    var displayName: String {
        let profile = UserProfile.defaultProfile
        if !profile.nickname.isEmpty {
            return profile.nickname
        }
        return generateRandomNickname()
    }
    
    private func generateRandomNickname() -> String {
        let words = ["Ace", "Brave", "Champ", "Dash", "Echo", "Flash", "Glow", "Hero", "Iggy", "Jazz", "Kai", "Luna", "Max", "Nova", "Onyx", "Pulse", "Quest", "Rush", "Sky", "Tiger", "Ultra", "Vibe", "Wave", "Xen", "Yolo", "Zest"]
        let word = words.randomElement() ?? "User"
        let suffix = String(Int.random(in: 100...999))
        return "\(word)\(suffix)"
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
