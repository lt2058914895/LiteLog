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
    private static let metadataTimeout: TimeInterval = 15
    private static let downloadTimeout: TimeInterval = 30
    private static let downloadPollInterval: UInt64 = 300_000_000
    private static let availabilityRetryDelays: [UInt64] = [
        0,
        300_000_000,
        700_000_000,
        1_500_000_000,
    ]
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app",
        category: "ICloudBackupManager"
    )

    @Published private(set) var isAvailable = false
    @Published private(set) var lastBackupDate: Date?
    @Published private(set) var isBackingUp = false
    @Published private(set) var isRestoring = false

    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    private var isCheckingAvailability = false

    private init() {
        lastBackupDate = UserDefaults.standard.object(forKey: Self.lastBackupKey) as? Date
        refreshAvailability()
        observeUbiquityIdentityChanges()
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
        updateAvailability()
    }

    func refreshAvailabilityWithRetry() async {
        guard !isCheckingAvailability else { return }
        isCheckingAvailability = true
        defer { isCheckingAvailability = false }

        for (index, delay) in Self.availabilityRetryDelays.enumerated() {
            if index > 0 {
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    return
                }
            }

            updateAvailability()
            if isAvailable {
                return
            }
        }

        let isSignedIn = fileManager.ubiquityIdentityToken != nil
        Self.logger.notice(
            "iCloud container unavailable after retry; ubiquity identity present: \(isSignedIn, privacy: .public)"
        )
    }

    private func updateAvailability() {
        let available = containerURL != nil
        guard available != isAvailable else { return }

        isAvailable = available
        Self.logger.notice("iCloud container availability changed: \(available, privacy: .public)")
    }

    private func observeUbiquityIdentityChanges() {
        NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshAvailabilityWithRetry()
                }
            }
            .store(in: &cancellables)
    }

    func backup(
        context: NSManagedObjectContext,
        settings: SettingsManager,
        force: Bool = false
    ) async throws {
        guard !isBackingUp else {
            throw ICloudBackupError.busy
        }
        guard !isRestoring else {
            throw ICloudBackupError.busy
        }

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

        do {
            try await Task.detached(priority: .utility) {
                try Self.writeData(data, to: backupURL)
            }.value
        } catch {
            Self.logger.error("iCloud backup write failed: \(error.localizedDescription)")
            throw error
        }

        let now = Date()
        lastBackupDate = now
        UserDefaults.standard.set(now, forKey: Self.lastBackupKey)
    }

    func restore(
        context: NSManagedObjectContext,
        settings: SettingsManager
    ) async throws -> Int {
        guard !isRestoring else {
            throw ICloudBackupError.busy
        }
        guard !isBackingUp else {
            throw ICloudBackupError.busy
        }

        refreshAvailability()
        guard isAvailable, let backupURL else {
            throw ICloudBackupError.unavailable
        }

        isRestoring = true
        defer { isRestoring = false }

        try await prepareBackupForReading(at: backupURL)

        let data: Data
        do {
            data = try await Task.detached(priority: .userInitiated) {
                try Self.readData(from: backupURL)
            }.value
        } catch {
            Self.logger.error("iCloud backup read failed: \(error.localizedDescription)")
            throw error
        }

        let recordCount = try LocalBackupManager.shared.restoreBackup(
            from: data,
            context: context,
            settings: settings
        )

        if let values = try? backupURL.resourceValues(forKeys: [.contentModificationDateKey]),
           let modifiedAt = values.contentModificationDate {
            lastBackupDate = modifiedAt
            UserDefaults.standard.set(modifiedAt, forKey: Self.lastBackupKey)
        }

        return recordCount
    }

    private func prepareBackupForReading(at url: URL) async throws {
        try await waitForMetadataIfNeeded(at: url)
        guard fileManager.isUbiquitousItem(at: url) else { return }

        if let status = try? url.resourceValues(
            forKeys: [.ubiquitousItemDownloadingStatusKey]
        ).ubiquitousItemDownloadingStatus,
           status == .current || status == .downloaded {
            return
        }

        try? fileManager.startDownloadingUbiquitousItem(at: url)
        let deadline = Date().addingTimeInterval(Self.downloadTimeout)

        while Date() < deadline {
            if let status = try? url.resourceValues(
                forKeys: [.ubiquitousItemDownloadingStatusKey]
            ).ubiquitousItemDownloadingStatus,
               status == .current || status == .downloaded {
                return
            }
            try await Task.sleep(nanoseconds: Self.downloadPollInterval)
        }

        throw ICloudBackupError.downloadTimeout
    }

    private func waitForMetadataIfNeeded(at url: URL) async throws {
        let deadline = Date().addingTimeInterval(Self.metadataTimeout)
        var discovered = fileManager.fileExists(atPath: url.path) || fileManager.isUbiquitousItem(at: url)

        while !discovered, Date() < deadline {
            try? fileManager.startDownloadingUbiquitousItem(at: url)
            try await Task.sleep(nanoseconds: Self.downloadPollInterval)
            discovered = fileManager.fileExists(atPath: url.path) || fileManager.isUbiquitousItem(at: url)
        }

        guard discovered else {
            throw ICloudBackupError.noBackup
        }
    }

    private nonisolated static func readData(from url: URL) throws -> Data {
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
            throw coordinationError
        }
        if let readError {
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

    private nonisolated static func writeData(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(
            writingItemAt: url,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try FileManager.default.createDirectory(
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
            throw coordinationError
        }
        if let writeError {
            throw writeError
        }
    }
}

enum ICloudBackupError: LocalizedError {
    case unavailable
    case noBackup
    case downloadTimeout
    case busy

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return NSLocalizedString("pro.icloud.unavailable.message", comment: "")
        case .noBackup:
            return NSLocalizedString("pro.icloud.no.backup", comment: "")
        case .downloadTimeout:
            return NSLocalizedString("pro.icloud.download.timeout", comment: "")
        case .busy:
            return NSLocalizedString("pro.icloud.busy", comment: "")
        }
    }
}
