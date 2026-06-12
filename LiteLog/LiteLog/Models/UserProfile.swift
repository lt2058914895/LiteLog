import Foundation
import SwiftUI
import SwiftData

enum UserProfileSyncStatus: Int, Codable {
    case pending = 0
    case synced = 1
}

@Model
final class UserProfile {
    var id: UUID
    var height: Double
    var gender: Gender
    var age: Int
    var goalWeight: Double
    var goalBodyFat: Double?
    var goalWaistCircumference: Double?
    var goalHipCircumference: Double?
    var goalChestCircumference: Double?
    var goalThighCircumference: Double?
    var weightUnit: String
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: UserProfileSyncStatus

    enum Gender: Int, Codable, CaseIterable {
        case male = 0
        case female = 1

        var displayName: String {
            switch self {
            case .male: return NSLocalizedString("settings.male", comment: "")
            case .female: return NSLocalizedString("settings.female", comment: "")
            }
        }
    }

    init(
        id: UUID = UUID(),
        height: Double = 170.0,
        gender: Gender = .male,
        age: Int = 30,
        goalWeight: Double = 65.0,
        goalBodyFat: Double? = nil,
        goalWaistCircumference: Double? = nil,
        goalHipCircumference: Double? = nil,
        goalChestCircumference: Double? = nil,
        goalThighCircumference: Double? = nil,
        weightUnit: String = "kg",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: UserProfileSyncStatus = .pending
    ) {
        self.id = id
        self.height = height
        self.gender = gender
        self.age = age
        self.goalWeight = goalWeight
        self.goalBodyFat = goalBodyFat
        self.goalWaistCircumference = goalWaistCircumference
        self.goalHipCircumference = goalHipCircumference
        self.goalChestCircumference = goalChestCircumference
        self.goalThighCircumference = goalThighCircumference
        self.weightUnit = weightUnit
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }

    func calculateBMI(weight: Double) -> Double {
        let heightInMeters = height / 100.0
        return weight / (heightInMeters * heightInMeters)
    }

    func bmiCategory(bmi: Double) -> BMICategory {
        switch bmi {
        case ..<18.5:
            return .underweight
        case 18.5..<24:
            return .normal
        case 24..<28:
            return .overweight
        default:
            return .obese
        }
    }

    enum BMICategory: String {
        case underweight
        case normal
        case overweight
        case obese

        var localizedKey: String {
            switch self {
            case .underweight: return "bmi.category.underweight"
            case .normal: return "bmi.category.normal"
            case .overweight: return "bmi.category.overweight"
            case .obese: return "bmi.category.obese"
            }
        }

        var displayName: String {
            NSLocalizedString(localizedKey, comment: "")
        }

        var color: Color {
            switch self {
            case .underweight: return .blue
            case .normal: return .green
            case .overweight: return .orange
            case .obese: return .red
            }
        }
    }
}

extension UserProfile {
    static var defaultProfile: UserProfile {
        UserProfile()
    }
}
