import CoreData
import Foundation
import UIKit

@MainActor
final class LocalBackupManager {
    static let shared = LocalBackupManager()

    private let schemaVersion = 1
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func exportBackup(
        records: [WeightRecord],
        profile: UserProfile?,
        settings: SettingsManager
    ) throws -> URL {
        guard !records.isEmpty ||
                profile != nil ||
                settings.avatarImage != nil ||
                !settings.nickname.isEmpty else {
            throw BackupError.emptyBackup
        }

        let backup = BackupDocument(
            schemaVersion: schemaVersion,
            exportedAt: Date(),
            profile: profile.map(BackupProfile.init),
            settings: BackupSettings(
                nickname: settings.nickname,
                avatarPNG: settings.avatarImage?.pngData()
            ),
            records: records.map(BackupRecord.init)
        )

        let data = try encoder.encode(backup)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteLog_Backup_\(formatter.string(from: Date())).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    func restoreBackup(
        from url: URL,
        context: NSManagedObjectContext,
        settings: SettingsManager
    ) throws -> Int {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize <= 25 * 1024 * 1024 else {
            throw BackupError.fileTooLarge
        }

        let data = try Data(contentsOf: url)
        let decoded = try decodeBackup(from: data)
        let backup = decoded.document

        guard backup.schemaVersion == schemaVersion else {
            throw BackupError.unsupportedVersion
        }
        guard !backup.records.isEmpty || backup.profile != nil else {
            throw BackupError.emptyBackup
        }
        try validate(backup)

        let avatarImage: UIImage?
        if let avatarPNG = backup.settings?.avatarPNG {
            guard let image = UIImage(data: avatarPNG) else {
                throw BackupError.invalidAvatar
            }
            avatarImage = image
        } else {
            avatarImage = nil
        }

        do {
            try deleteCurrentData(in: context, includeProfile: !decoded.isLegacy)
            try insertBackup(backup, into: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        if !decoded.isLegacy {
            settings.nickname = backup.settings?.nickname ?? ""
            if let avatarImage {
                _ = settings.saveAvatar(avatarImage)
            } else {
                _ = settings.removeAvatar()
            }
        }
        if let weightUnit = backup.profile?.weightUnit,
           let unit = WeightUnit(rawValue: weightUnit) {
            settings.weightUnit = unit
        }

        return backup.records.count
    }

    private func decodeBackup(from data: Data) throws -> DecodedBackup {
        do {
            return DecodedBackup(
                document: try decoder.decode(BackupDocument.self, from: data),
                isLegacy: false
            )
        } catch {
            return DecodedBackup(
                document: try decoder.decode(LegacyBackupDocument.self, from: data).converted(),
                isLegacy: true
            )
        }
    }

    private func validate(_ backup: BackupDocument) throws {
        guard Set(backup.records.map(\.id)).count == backup.records.count else {
            throw BackupError.invalidRecord
        }

        if let profile = backup.profile {
            guard profile.height.isFinite, profile.height > 0,
                  (0...120).contains(profile.age),
                  UserProfile.Gender(rawValue: profile.gender) != nil,
                  profile.goalWeight.isFinite, profile.goalWeight > 0,
                  WeightUnit(rawValue: profile.weightUnit) != nil else {
                throw BackupError.invalidProfile
            }
        }

        for record in backup.records {
            guard record.weight.isFinite, record.weight > 0,
                  record.date.timeIntervalSince1970.isFinite,
                  record.createdAt.timeIntervalSince1970.isFinite,
                  record.updatedAt.timeIntervalSince1970.isFinite else {
                throw BackupError.invalidRecord
            }
        }
    }

    private func deleteCurrentData(in context: NSManagedObjectContext, includeProfile: Bool) throws {
        let entityNames = includeProfile ? ["WeightRecord", "UserProfile"] : ["WeightRecord"]
        for entityName in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            for object in try context.fetch(request) {
                context.delete(object)
            }
        }
    }

    private func insertBackup(_ backup: BackupDocument, into context: NSManagedObjectContext) throws {
        if let profile = backup.profile {
            let newProfile = UserProfile.create(in: context)
            newProfile.height = profile.height
            newProfile.gender = profile.gender
            newProfile.age = profile.age
            newProfile.goalWeightValue = profile.goalWeight
            newProfile.goalBodyFatPercentage = profile.goalBodyFat
            newProfile.goalWaistCircumferenceValue = profile.goalWaistCircumference
            newProfile.goalHipCircumferenceValue = profile.goalHipCircumference
            newProfile.goalChestCircumferenceValue = profile.goalChestCircumference
            newProfile.goalThighCircumferenceValue = profile.goalThighCircumference
            newProfile.weightUnit = profile.weightUnit
            newProfile.createdAt = profile.createdAt
            newProfile.updatedAt = profile.updatedAt
        }

        for record in backup.records {
            let newRecord = WeightRecord.create(in: context, weight: record.weight)
            newRecord.id = record.id
            newRecord.date = record.date
            newRecord.bodyFatPercentageValue = record.bodyFatPercentage
            newRecord.waistCircumferenceValue = record.waistCircumference
            newRecord.hipCircumferenceValue = record.hipCircumference
            newRecord.chestCircumferenceValue = record.chestCircumference
            newRecord.thighCircumferenceValue = record.thighCircumference
            newRecord.note = record.note
            newRecord.measurementTimePeriod = record.measurementTimePeriod
            newRecord.createdAt = record.createdAt
            newRecord.updatedAt = record.updatedAt
        }
    }
}

private struct DecodedBackup {
    let document: BackupDocument
    let isLegacy: Bool
}

private struct BackupDocument: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let profile: BackupProfile?
    let settings: BackupSettings?
    let records: [BackupRecord]
}

private struct BackupSettings: Codable {
    let nickname: String
    let avatarPNG: Data?
}

private struct BackupProfile: Codable {
    let height: Double
    let gender: Int16
    let age: Int16
    let goalWeight: Double
    let goalBodyFat: Double?
    let goalWaistCircumference: Double?
    let goalHipCircumference: Double?
    let goalChestCircumference: Double?
    let goalThighCircumference: Double?
    let weightUnit: String
    let createdAt: Date
    let updatedAt: Date

    init(_ profile: UserProfile) {
        height = profile.height
        gender = profile.gender
        age = profile.age
        goalWeight = profile.goalWeightValue ?? 0
        goalBodyFat = profile.goalBodyFatPercentage
        goalWaistCircumference = profile.goalWaistCircumferenceValue
        goalHipCircumference = profile.goalHipCircumferenceValue
        goalChestCircumference = profile.goalChestCircumferenceValue
        goalThighCircumference = profile.goalThighCircumferenceValue
        weightUnit = profile.weightUnit
        createdAt = profile.createdAt
        updatedAt = profile.updatedAt
    }
}

private struct BackupRecord: Codable {
    let id: UUID
    let date: Date
    let weight: Double
    let bodyFatPercentage: Double?
    let waistCircumference: Double?
    let hipCircumference: Double?
    let chestCircumference: Double?
    let thighCircumference: Double?
    let note: String?
    let measurementTimePeriod: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        date: Date,
        weight: Double,
        bodyFatPercentage: Double?,
        waistCircumference: Double?,
        hipCircumference: Double?,
        chestCircumference: Double?,
        thighCircumference: Double?,
        note: String?,
        measurementTimePeriod: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.waistCircumference = waistCircumference
        self.hipCircumference = hipCircumference
        self.chestCircumference = chestCircumference
        self.thighCircumference = thighCircumference
        self.note = note
        self.measurementTimePeriod = measurementTimePeriod
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(_ record: WeightRecord) {
        id = record.id
        date = record.date
        weight = record.weight
        bodyFatPercentage = record.bodyFatPercentageValue
        waistCircumference = record.waistCircumferenceValue
        hipCircumference = record.hipCircumferenceValue
        chestCircumference = record.chestCircumferenceValue
        thighCircumference = record.thighCircumferenceValue
        note = record.note
        measurementTimePeriod = record.measurementTimePeriod
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }
}

private struct LegacyBackupDocument: Decodable {
    let records: [LegacyBackupRecord]

    func converted() throws -> BackupDocument {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let convertedRecords = try records.map { record -> BackupRecord in
            guard let id = UUID(uuidString: record.id),
                  let date = formatter.date(from: record.date),
                  let weight = Double(record.weight) else {
                throw BackupError.invalidRecord
            }
            return BackupRecord(
                id: id,
                date: date,
                weight: weight,
                bodyFatPercentage: record.bodyFatPercentage.flatMap { Double($0) },
                waistCircumference: record.waistCircumference.flatMap { Double($0) },
                hipCircumference: record.hipCircumference.flatMap { Double($0) },
                chestCircumference: record.chestCircumference.flatMap { Double($0) },
                thighCircumference: record.thighCircumference.flatMap { Double($0) },
                note: record.note,
                measurementTimePeriod: record.measurementTimePeriod,
                createdAt: date,
                updatedAt: date
            )
        }

        return BackupDocument(
            schemaVersion: 1,
            exportedAt: Date(),
            profile: nil,
            settings: nil,
            records: convertedRecords
        )
    }
}

private struct LegacyBackupRecord: Decodable {
    let id: String
    let date: String
    let weight: String
    let bodyFatPercentage: String?
    let waistCircumference: String?
    let hipCircumference: String?
    let chestCircumference: String?
    let thighCircumference: String?
    let note: String?
    let measurementTimePeriod: String?
}

private enum BackupError: LocalizedError {
    case unsupportedVersion
    case emptyBackup
    case invalidProfile
    case invalidRecord
    case invalidAvatar
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return NSLocalizedString("backup.error.version", comment: "")
        case .emptyBackup:
            return NSLocalizedString("backup.error.empty", comment: "")
        case .invalidProfile:
            return NSLocalizedString("backup.error.profile", comment: "")
        case .invalidRecord:
            return NSLocalizedString("backup.error.record", comment: "")
        case .invalidAvatar:
            return NSLocalizedString("backup.error.avatar", comment: "")
        case .fileTooLarge:
            return NSLocalizedString("backup.error.size", comment: "")
        }
    }
}
