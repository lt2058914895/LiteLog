import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var height: Double
    var gender: Gender
    var age: Int
    var goalWeight: Double
    var createdAt: Date
    var updatedAt: Date

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
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.height = height
        self.gender = gender
        self.age = age
        self.goalWeight = goalWeight
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
    }
}

extension UserProfile {
    static var defaultProfile: UserProfile {
        UserProfile()
    }
}
