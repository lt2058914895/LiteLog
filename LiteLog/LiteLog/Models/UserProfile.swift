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
    @NSManaged var goalWeight: NSNumber?
    @NSManaged var goalBodyFat: NSNumber?
    @NSManaged var goalWaistCircumference: NSNumber?
    @NSManaged var goalHipCircumference: NSNumber?
    @NSManaged var goalChestCircumference: NSNumber?
    @NSManaged var goalThighCircumference: NSNumber?
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

    // Double? 桥接计算属性（CoreData @NSManaged 不支持 Double?，需用 NSNumber? 存储）
    var goalWeightValue: Double? {
        get { goalWeight?.doubleValue }
        set { goalWeight = newValue.map { NSNumber(value: $0) } }
    }

    var goalBodyFatPercentage: Double? {
        get { goalBodyFat?.doubleValue }
        set { goalBodyFat = newValue.map { NSNumber(value: $0) } }
    }

    var goalWaistCircumferenceValue: Double? {
        get { goalWaistCircumference?.doubleValue }
        set { goalWaistCircumference = newValue.map { NSNumber(value: $0) } }
    }

    var goalHipCircumferenceValue: Double? {
        get { goalHipCircumference?.doubleValue }
        set { goalHipCircumference = newValue.map { NSNumber(value: $0) } }
    }

    var goalChestCircumferenceValue: Double? {
        get { goalChestCircumference?.doubleValue }
        set { goalChestCircumference = newValue.map { NSNumber(value: $0) } }
    }

    var goalThighCircumferenceValue: Double? {
        get { goalThighCircumference?.doubleValue }
        set { goalThighCircumference = newValue.map { NSNumber(value: $0) } }
    }
    
    var hasGoalMeasurements: Bool {
        goalWaistCircumference != nil || goalHipCircumference != nil || 
        goalChestCircumference != nil || goalThighCircumference != nil
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
        profile.goalWeightValue = 65.0
        profile.goalBodyFatPercentage = nil
        profile.goalWaistCircumferenceValue = nil
        profile.goalHipCircumferenceValue = nil
        profile.goalChestCircumferenceValue = nil
        profile.goalThighCircumferenceValue = nil
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

