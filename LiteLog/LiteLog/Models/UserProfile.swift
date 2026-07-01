import Foundation
import SwiftUI
import CoreData

enum UserProfileSyncStatus: Int, Codable {
    case pending = 0
    case synced = 1
}

@objc(UserProfile)
final class UserProfile: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var height: Double
    @NSManaged var gender: Int16
    @NSManaged var age: Int16
    @NSManaged var goalWeight: Double
    @NSManaged var goalBodyFat: Double
    @NSManaged var goalWaistCircumference: Double
    @NSManaged var goalHipCircumference: Double
    @NSManaged var goalChestCircumference: Double
    @NSManaged var goalThighCircumference: Double
    @NSManaged var weightUnit: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var syncStatus: Int16

    @objc(Gender)
    enum Gender: Int16, CaseIterable {
        case male = 0
        case female = 1

        var displayName: String {
            switch self {
            case .male: return NSLocalizedString("settings.male", comment: "")
            case .female: return NSLocalizedString("settings.female", comment: "")
            }
        }
    }

    @objc(SyncStatus)
    enum SyncStatus: Int16 {
        case pending = 0
        case synced = 1
    }

    static func fetchRequest() -> NSFetchRequest<UserProfile> {
        NSFetchRequest<UserProfile>(entityName: "UserProfile")
    }

    var goalBodyFatPercentage: Double? {
        goalBodyFat == 0 ? nil : goalBodyFat
    }

    var goalWaistCircumferenceValue: Double? {
        goalWaistCircumference == 0 ? nil : goalWaistCircumference
    }

    var goalHipCircumferenceValue: Double? {
        goalHipCircumference == 0 ? nil : goalHipCircumference
    }

    var goalChestCircumferenceValue: Double? {
        goalChestCircumference == 0 ? nil : goalChestCircumference
    }

    var goalThighCircumferenceValue: Double? {
        goalThighCircumference == 0 ? nil : goalThighCircumference
    }
    
    var hasGoalMeasurements: Bool {
        goalWaistCircumference > 0 || goalHipCircumference > 0 || 
        goalChestCircumference > 0 || goalThighCircumference > 0
    }

    var genderEnum: Gender {
        get { Gender(rawValue: gender) ?? .male }
        set { gender = newValue.rawValue }
    }

    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    func calculateBMI(weight: Double) -> Double {
        let heightInMeters = height / 100.0
        guard heightInMeters > 0 else {
            return 0
        }
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
        
        static func from(bmi: Double) -> BMICategory {
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
    static func create(in context: NSManagedObjectContext) -> UserProfile {
        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.height = 170.0
        profile.gender = Gender.male.rawValue
        profile.age = 30
        profile.goalWeight = 65.0
        profile.goalBodyFat = 0
        profile.goalWaistCircumference = 0
        profile.goalHipCircumference = 0
        profile.goalChestCircumference = 0
        profile.goalThighCircumference = 0
        profile.weightUnit = "kg"
        profile.createdAt = Date()
        profile.updatedAt = Date()
        profile.syncStatus = SyncStatus.pending.rawValue
        return profile
    }

    static var defaultProfile: UserProfile {
        let context = PersistenceController.shared.viewContext
        return UserProfile.create(in: context)
    }
}

