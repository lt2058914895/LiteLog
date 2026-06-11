import Foundation
import SwiftData
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

@Model
final class WeightRecord {
    var id: UUID
    var date: Date
    var weight: Double
    var bodyFatPercentage: Double?
    var waistCircumference: Double?
    var hipCircumference: Double?
    var chestCircumference: Double?
    var thighCircumference: Double?
    var note: String?
    var imageUrl: String?
    var measurementTimePeriod: String?
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: WeightRecordSyncStatus
    
    @Transient
    var selectedImage: UIImage?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weight: Double,
        bodyFatPercentage: Double? = nil,
        waistCircumference: Double? = nil,
        hipCircumference: Double? = nil,
        chestCircumference: Double? = nil,
        thighCircumference: Double? = nil,
        note: String? = nil,
        imageUrl: String? = nil,
        measurementTimePeriod: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: WeightRecordSyncStatus = .pending
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
        self.imageUrl = imageUrl
        self.measurementTimePeriod = measurementTimePeriod
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.selectedImage = nil
    }
}

extension WeightRecord {
    static var sampleData: WeightRecord {
        WeightRecord(
            date: Date(),
            weight: 70.0,
            bodyFatPercentage: 20.0,
            note: "Sample record"
        )
    }

    static var sampleDataArray: [WeightRecord] {
        let calendar = Calendar.current
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            return WeightRecord(
                date: date,
                weight: 70.0 + Double(dayOffset) * 0.2,
                bodyFatPercentage: 20.0 + Double(dayOffset) * 0.5
            )
        }
    }
}
