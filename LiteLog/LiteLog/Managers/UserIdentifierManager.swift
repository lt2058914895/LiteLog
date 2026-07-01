import Foundation
import Security

final class UserIdentifierManager {
    static let shared = UserIdentifierManager()
    
    private let keychainService = "com.litelog.identifier"
    private let deviceIdKey = "device_id"
    
    private var cachedDeviceId: String?
    
    private init() {}
    
    var deviceId: String {
        if let cached = cachedDeviceId {
            return cached
        }
        if let existingId = getStringFromKeychain(deviceIdKey) {
            cachedDeviceId = existingId
            return existingId
        }
        let newId = UUID().uuidString
        saveStringToKeychain(newId, forKey: deviceIdKey)
        cachedDeviceId = newId
        return newId
    }
    
    func checkForSyncedDeviceId() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService as CFString,
            kSecAttrAccount: deviceIdKey as CFString,
            kSecAttrSynchronizable: kCFBooleanTrue!,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var data: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &data)
        
        if status == errSecSuccess, let data = data as? Data, let syncedId = String(data: data, encoding: .utf8) {
            if syncedId != cachedDeviceId {
                return syncedId
            }
        }
        return nil
    }
    
    func switchToDeviceId(_ newId: String) {
        cachedDeviceId = newId
        saveStringToKeychain(newId, forKey: deviceIdKey)
    }
    
    var identifierType: IdentifierType {
        return .device
    }
    
    var primaryIdentifier: String {
        return deviceId
    }
    
    func getIdentifierHeader() -> [String: String] {
        return [
            "X-User-Id": primaryIdentifier,
            "X-Id-Type": identifierType.rawValue
        ]
    }
    
    private func getStringFromKeychain(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService as CFString,
            kSecAttrAccount: key as CFString,
            kSecAttrSynchronizable: kCFBooleanTrue!,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var data: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &data)
        
        if status == errSecSuccess, let data = data as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func saveStringToKeychain(_ value: String, forKey key: String) {
        let data = value.data(using: .utf8)!
        
        deleteFromKeychain(key)
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService as CFString,
            kSecAttrAccount: key as CFString,
            kSecAttrSynchronizable: kCFBooleanTrue!,
            kSecValueData: data
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func deleteFromKeychain(_ key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService as CFString,
            kSecAttrAccount: key as CFString,
            kSecAttrSynchronizable: kCFBooleanTrue!
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    func clearAll() {
        cachedDeviceId = nil
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService as CFString,
            kSecAttrSynchronizable: kCFBooleanTrue!
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    func waitForICloudSync(completion: @escaping () -> Void) {
        let maxRetries = 5
        var retryCount = 0
        
        var checkSync: () -> Void = {}
        checkSync = {
            if self.checkForSyncedDeviceId() != nil {
                completion()
            } else if retryCount < maxRetries {
                retryCount += 1
                DispatchQueue.global().asyncAfter(deadline: .now() + Double(retryCount) * 0.5) {
                    checkSync()
                }
            } else {
                completion()
            }
        }
        
        checkSync()
    }
}

enum IdentifierType: String {
    case device = "device"
}