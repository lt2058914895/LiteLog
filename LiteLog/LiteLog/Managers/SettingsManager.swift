import Foundation
import SwiftUI
import Combine
import SwiftData

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    
    weak var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
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
        static let isLoggedIn = "isLoggedIn"
        static let userId = "userId"
        static let token = "token"
        static let tokenType = "tokenType"
        static let tokenExpiration = "tokenExpiration"
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
        guard let context = modelContext else { return }
        
        Task { @MainActor in
            do {
                let profiles = try context.fetch(FetchDescriptor<UserProfile>())
                if let profile = profiles.first {
                    // 只更新单位，目标体重保持不变（始终以 kg 存储）
                    // 显示时会根据单位自动转换
                    // 例如：70kg 在 kg 单位下显示 70kg，在 lb 单位下显示 154.32lb
                    profile.weightUnit = weightUnit.rawValue
                    profile.updatedAt = Date()
                    profile.syncStatus = .pending
                    try context.save()
                    
                    // 触发同步到云数据库
                    await DataSyncManager.shared.triggerProfileSync(modelContext: context)
                } else {
                    // 如果没有个人资料，创建一个新的
                    let newProfile = UserProfile(
                        weightUnit: weightUnit.rawValue,
                        syncStatus: .pending
                    )
                    context.insert(newProfile)
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
        // 将图片缩放到合适的尺寸，避免缓存过大和显示问题
        let scaledImage = image.scaledToSize(CGSize(width: 120, height: 120))
        if let data = scaledImage.pngData() {
            defaults.set(data, forKey: Keys.avatarData)
            defaults.set(avatarUrl.hashValue, forKey: Keys.avatarUrlHash)
            // 触发视图更新
            avatarCacheUpdated.toggle()
        }
    }
    
    func clearCachedAvatar() {
        defaults.removeObject(forKey: Keys.avatarData)
        defaults.removeObject(forKey: Keys.avatarUrlHash)
    }
    
    var isAvatarCached: Bool {
        if let cachedHash = defaults.integer(forKey: Keys.avatarUrlHash) as? Int,
           cachedHash == avatarUrl.hashValue {
            return cachedAvatarImage != nil
        }
        return false
    }
    
    var token: String? {
        defaults.string(forKey: Keys.token)
    }

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
    
    func login(userId: String, nickname: String?, avatarUrl: String?) {
        self.userId = userId
        self.nickname = nickname ?? ""
        self.avatarUrl = avatarUrl ?? ""
        self.isLoggedIn = true
    }
    
    func login(with userInfo: UserInfo) {
        self.userId = userInfo.userId
        self.nickname = userInfo.nickname ?? ""
        self.avatarUrl = userInfo.avatarUrl ?? ""
        saveToken(userInfo.token, tokenType: userInfo.tokenType, expiresIn: userInfo.expiresIn)
        self.isLoggedIn = true
        
        // 下载并缓存头像
        downloadAndCacheAvatar()
        
        if let context = self.modelContext {
            Task {
                await DataSyncManager.shared.syncLocalDataToCloud(modelContext: context)
            }
        }
    }
    
    private func downloadAndCacheAvatar() {
        guard !avatarUrl.isEmpty else { return }
        
        Task {
            if let url = URL(string: avatarUrl), 
               let data = try? Data(contentsOf: url), 
               let image = UIImage(data: data) {
                updateCachedAvatar(with: image)
            }
        }
    }
    
    private func saveToken(_ token: String, tokenType: String?, expiresIn: TimeInterval?) {
        defaults.set(token, forKey: Keys.token)
        if let tokenType = tokenType {
            defaults.set(tokenType, forKey: Keys.tokenType)
        }
        if let expiresIn = expiresIn {
            let expirationDate = Date().addingTimeInterval(expiresIn)
            defaults.set(expirationDate, forKey: Keys.tokenExpiration)
        }
    }
    
    func logout() {
        Task {
            await logoutAsync()
        }
    }
    
    func logoutAsync() async {
        let currentToken = self.token
        
        self.userId = ""
        self.nickname = ""
        self.avatarUrl = ""
        self.isLoggedIn = false
        defaults.removeObject(forKey: Keys.token)
        defaults.removeObject(forKey: Keys.tokenType)
        defaults.removeObject(forKey: Keys.tokenExpiration)
        clearCachedAvatar()
        
        if let token = currentToken {
            try? await APIService.shared.logout(token: token)
        }
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