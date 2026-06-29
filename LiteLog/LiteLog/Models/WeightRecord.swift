import Foundation
import CoreData
import UIKit

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
    @NSManaged var bodyFatPercentage: Double
    @NSManaged var waistCircumference: Double
    @NSManaged var hipCircumference: Double
    @NSManaged var chestCircumference: Double
    @NSManaged var thighCircumference: Double
    @NSManaged var note: String?
    @NSManaged var imageUrl: String?
    @NSManaged var measurementTimePeriod: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var syncStatus: Int16
    @NSManaged var selectedImage: UIImage?

    @objc(SyncStatus)
    enum SyncStatus: Int16 {
        case pending
        case synced
        case failed
    }

    static func fetchRequest() -> NSFetchRequest<WeightRecord> {
        NSFetchRequest<WeightRecord>(entityName: "WeightRecord")
    }

    var bodyFatPercentageValue: Double? {
        bodyFatPercentage == 0 ? nil : bodyFatPercentage
    }

    var waistCircumferenceValue: Double? {
        waistCircumference == 0 ? nil : waistCircumference
    }

    var hipCircumferenceValue: Double? {
        hipCircumference == 0 ? nil : hipCircumference
    }

    var chestCircumferenceValue: Double? {
        chestCircumference == 0 ? nil : chestCircumference
    }

    var thighCircumferenceValue: Double? {
        thighCircumference == 0 ? nil : thighCircumference
    }

    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
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
    static func create(in context: NSManagedObjectContext, weight: Double) -> WeightRecord {
        let record = WeightRecord(context: context)
        record.id = UUID()
        record.date = Date()
        record.weight = weight
        record.bodyFatPercentage = 0
        record.waistCircumference = 0
        record.hipCircumference = 0
        record.chestCircumference = 0
        record.thighCircumference = 0
        record.note = nil
        record.imageUrl = nil
        record.measurementTimePeriod = nil
        record.createdAt = Date()
        record.updatedAt = Date()
        record.syncStatus = SyncStatus.pending.rawValue
        return record
    }

    static var sampleData: WeightRecord {
        let context = PersistenceController.shared.viewContext
        let record = WeightRecord.create(in: context, weight: 70.0)
        record.bodyFatPercentage = 20.0
        return record
    }

    static var sampleDataArray: [WeightRecord] {
        let calendar = Calendar.current
        let context = PersistenceController.shared.viewContext
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let record = WeightRecord.create(in: context, weight: 70.0 + Double(dayOffset) * 0.2)
            record.date = date
            record.bodyFatPercentage = 20.0 + Double(dayOffset) * 0.5
            return record
        }
    }
}