import Combine
import CoreData
import Foundation
import os

@MainActor
final class ICloudBackupManager: ObservableObject {
    static let shared = ICloudBackupManager()
    static let containerIdentifier = "iCloud.lt.LiteLog"

    private static let backupFileName = "LiteLog-AutoBackup.json"
    private static let lastBackupKey = "pro.icloud.lastBackupDate"
    private static let minimumInterval: TimeInterval = 15 * 60
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app",
        category: "ICloudBackupManager"
    )

    @Published private(set) var isAvailable = false
    @Published private(set) var lastBackupDate: Date?
    @Published private(set) var isBackingUp = false

    private let fileManager = FileManager.default

    private init() {
        lastBackupDate = UserDefaults.standard.object(forKey: Self.lastBackupKey) as? Date
        refreshAvailability()
    }

    var containerURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: Self.containerIdentifier)
    }

    var backupURL: URL? {
        containerURL?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(Self.backupFileName)
    }

    func refreshAvailability() {
        isAvailable = containerURL != nil
    }

    func backup(
        context: NSManagedObjectContext,
        settings: SettingsManager,
        force: Bool = false
    ) throws {
        guard ProEntitlementStore.shared.isPro else {
            throw ICloudBackupError.proRequired
        }
        guard !isBackingUp else { return }

        refreshAvailability()
        guard isAvailable, let backupURL else {
            throw ICloudBackupError.unavailable
        }

        if !force,
           let lastBackupDate,
           Date().timeIntervalSince(lastBackupDate) < Self.minimumInterval {
            return
        }

        isBackingUp = true
        defer { isBackingUp = false }

        let records = try context.fetch(WeightRecord.fetchRequest())
        let profiles = try context.fetch(UserProfile.fetchRequest())
        let data = try LocalBackupManager.shared.exportBackupData(
            records: records,
            profile: profiles.first,
            settings: settings
        )

        try write(data, to: backupURL)
        let now = Date()
        lastBackupDate = now
        UserDefaults.standard.set(now, forKey: Self.lastBackupKey)
    }

    func restore(
        context: NSManagedObjectContext,
        settings: SettingsManager
    ) throws -> Int {
        guard ProEntitlementStore.shared.isPro else {
            throw ICloudBackupError.proRequired
        }

        refreshAvailability()
        guard isAvailable, let backupURL else {
            throw ICloudBackupError.unavailable
        }
        guard fileManager.fileExists(atPath: backupURL.path) || fileManager.isUbiquitousItem(at: backupURL) else {
            throw ICloudBackupError.noBackup
        }

        let data = try read(from: backupURL)
        return try LocalBackupManager.shared.restoreBackup(
            from: data,
            context: context,
            settings: settings
        )
    }

    private func read(from url: URL) throws -> Data {
        if fileManager.isUbiquitousItem(at: url) {
            try? fileManager.startDownloadingUbiquitousItem(at: url)
        }

        var coordinationError: NSError?
        var readError: Error?
        var data: Data?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                data = try Data(contentsOf: coordinatedURL)
            } catch {
                readError = error
            }
        }

        if let coordinationError {
            Self.logger.error("iCloud backup coordination failed: \(coordinationError.localizedDescription)")
            throw coordinationError
        }
        if let readError {
            Self.logger.error("iCloud backup read failed: \(readError.localizedDescription)")
            let cocoaError = readError as NSError
            if cocoaError.domain == NSCocoaErrorDomain,
               cocoaError.code == NSFileReadNoSuchFileError {
                throw ICloudBackupError.noBackup
            }
            throw readError
        }
        guard let data else {
            throw ICloudBackupError.noBackup
        }
        return data
    }

    private func write(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(
            writingItemAt: url,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try fileManager.createDirectory(
                    at: coordinatedURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(
                    to: coordinatedURL,
                    options: [.atomic, .completeFileProtection]
                )
            } catch {
                writeError = error
            }
        }

        if let coordinationError {
            Self.logger.error("iCloud backup coordination failed: \(coordinationError.localizedDescription)")
            throw coordinationError
        }
        if let writeError {
            Self.logger.error("iCloud backup write failed: \(writeError.localizedDescription)")
            throw writeError
        }
    }
}

enum ICloudBackupError: LocalizedError {
    case proRequired
    case unavailable
    case noBackup

    var errorDescription: String? {
        switch self {
        case .proRequired:
            return NSLocalizedString("pro.error.required", comment: "")
        case .unavailable:
            return NSLocalizedString("pro.icloud.unavailable.message", comment: "")
        case .noBackup:
            return NSLocalizedString("pro.icloud.no.backup", comment: "")
        }
    }
}
