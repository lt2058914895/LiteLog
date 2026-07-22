import Foundation
import CoreData

enum WeightRecordSyncStatus: Int, Codable {
    case pending
    case synced
    case failed
}

enum MeasurementTimePeriod: String, Codable, CaseIterable {
    case morningFasting = "morning_fasting"
    case afterExercise = "after_exercise"
    case beforeBed = "before_bed"
    case random = "random"
    
    var displayName: String {
        switch self {
        case .morningFasting:
            return NSLocalizedString("period.morning_fasting", comment: "")
        case .afterExercise:
            return NSLocalizedString("period.after_exercise", comment: "")
        case .beforeBed:
            return NSLocalizedString("period.before_bed", comment: "")
        case .random:
            return NSLocalizedString("period.random", comment: "")
        }
    }
}

@objc(WeightRecord)
final class WeightRecord: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var date: Date
    @NSManaged var weight: Double
    @NSManaged var bodyFatPercentage: NSNumber?
    @NSManaged var waistCircumference: NSNumber?
    @NSManaged var hipCircumference: NSNumber?
    @NSManaged var chestCircumference: NSNumber?
    @NSManaged var thighCircumference: NSNumber?
    @NSManaged var note: String?
    @NSManaged var imageUrl: String?
    @NSManaged var measurementTimePeriod: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var syncStatus: Int16
    @NSManaged var deleteImage: Bool

    @objc(SyncStatus)
    enum SyncStatus: Int16 {
        case pending
        case synced
        case failed
    }

    static func fetchRequest() -> NSFetchRequest<WeightRecord> {
        NSFetchRequest<WeightRecord>(entityName: "WeightRecord")
    }

    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
    
    var hasImage: Bool {
        imageUrl != nil
    }

    // Double? 桥接计算属性（CoreData @NSManaged 不支持 Double?，需用 NSNumber? 存储）
    var bodyFatPercentageValue: Double? {
        get { bodyFatPercentage?.doubleValue }
        set { bodyFatPercentage = newValue.map { NSNumber(value: $0) } }
    }

    var waistCircumferenceValue: Double? {
        get { waistCircumference?.doubleValue }
        set { waistCircumference = newValue.map { NSNumber(value: $0) } }
    }

    var hipCircumferenceValue: Double? {
        get { hipCircumference?.doubleValue }
        set { hipCircumference = newValue.map { NSNumber(value: $0) } }
    }

    var chestCircumferenceValue: Double? {
        get { chestCircumference?.doubleValue }
        set { chestCircumference = newValue.map { NSNumber(value: $0) } }
    }

    var thighCircumferenceValue: Double? {
        get { thighCircumference?.doubleValue }
        set { thighCircumference = newValue.map { NSNumber(value: $0) } }
    }
}

struct WeightChangeRecord {
    let record: WeightRecord
    let weightChange: Double?
}

extension Array where Element == WeightRecord {
    func computeWeightChanges() -> [WeightChangeRecord] {
        return enumerated().map { index, record in
            let weightChange = index < count - 1 ? record.weight - self[index + 1].weight : nil
            return WeightChangeRecord(record: record, weightChange: weightChange)
        }
    }
    
    func groupedByMonth() -> [Date: [WeightRecord]] {
        let calendar = Calendar.current
        return Dictionary(grouping: self) { record in
            let components = calendar.dateComponents([.year, .month], from: record.date)
            return calendar.date(from: components) ?? record.date
        }
    }
    
    func groupedByMonthWithWeightChanges() -> [Date: [WeightChangeRecord]] {
        let grouped = groupedByMonth()
        return grouped.mapValues { $0.computeWeightChanges() }
    }
}

extension WeightRecord {
    /// 将WeightRecord转换为WeightRecordRequest用于同步
    func toRequest(imageUrl: String? = nil, imageFileName: String? = nil, deleteImage: Bool? = nil) -> WeightRecordRequest {
        WeightRecordRequest(
            recordId: id.uuidString,
            weight: weight,
            bodyFatPercentage: bodyFatPercentageValue,
            waistCircumference: waistCircumferenceValue,
            hipCircumference: hipCircumferenceValue,
            chestCircumference: chestCircumferenceValue,
            thighCircumference: thighCircumferenceValue,
            note: note,
            date: date.timeIntervalSince1970,
            createdAt: createdAt.timeIntervalSince1970,
            updatedAt: updatedAt.timeIntervalSince1970,
            deleted: false,
            imageUrl: imageUrl,
            imageFileName: imageFileName,
            measurementTimePeriod: measurementTimePeriod,
            deleteImage: deleteImage
        )
    }

    static func create(in context: NSManagedObjectContext, weight: Double) -> WeightRecord {
        let record = WeightRecord(context: context)
        record.id = UUID()
        record.date = Date()
        record.weight = weight
        record.bodyFatPercentageValue = nil
        record.waistCircumferenceValue = nil
        record.hipCircumferenceValue = nil
        record.chestCircumferenceValue = nil
        record.thighCircumferenceValue = nil
        record.note = nil
        record.imageUrl = nil
        record.measurementTimePeriod = nil
        record.createdAt = Date()
        record.updatedAt = Date()
        record.syncStatus = SyncStatus.pending.rawValue
        record.deleteImage = false
        return record
    }

    static var sampleData: WeightRecord {
        let context = PersistenceController.shared.viewContext
        let record = WeightRecord.create(in: context, weight: 70.0)
        record.bodyFatPercentageValue = 20.0
        return record
    }

    static var sampleDataArray: [WeightRecord] {
        let calendar = Calendar.current
        let context = PersistenceController.shared.viewContext
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let record = WeightRecord.create(in: context, weight: 70.0 + Double(dayOffset) * 0.2)
            record.date = date
            record.bodyFatPercentageValue = 20.0 + Double(dayOffset) * 0.5
            return record
        }
    }
}