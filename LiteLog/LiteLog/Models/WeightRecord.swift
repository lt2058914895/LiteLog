import Foundation
import SwiftData

@Model
final class WeightRecord {
    var id: UUID
    var date: Date
    var weight: Double
    var bodyFatPercentage: Double?
    var waistCircumference: Double?
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus

    enum SyncStatus: Int, Codable {
        case pending
        case synced
        case failed
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weight: Double,
        bodyFatPercentage: Double? = nil,
        waistCircumference: Double? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.waistCircumference = waistCircumference
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
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
