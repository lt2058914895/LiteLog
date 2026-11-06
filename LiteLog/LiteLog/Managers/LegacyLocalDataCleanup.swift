import Foundation
import Security

enum LegacyLocalDataCleanup {
    private static let completionKey = "com.litelog.localOnlyCleanupCompleted"
    private static let legacyKeychainService = "com.litelog.identifier"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: completionKey) else {
            return
        }

        let imagesRemoved = removeLegacyRecordImages()
        let identifierRemoved = removeLegacyDeviceIdentifier()
        if imagesRemoved && identifierRemoved {
            defaults.set(true, forKey: completionKey)
        }
    }

    private static func removeLegacyRecordImages() -> Bool {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }

        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        guard FileManager.default.fileExists(atPath: imagesDirectory.path) else {
            return true
        }

        do {
            try FileManager.default.removeItem(at: imagesDirectory)
            return true
        } catch {
            return false
        }
    }

    private static func removeLegacyDeviceIdentifier() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: legacyKeychainService,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
