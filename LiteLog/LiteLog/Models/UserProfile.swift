import Foundation
import SwiftUI
import CoreData

enum BMIStandard {
    case china
    case who

    static var current: BMIStandard {
        let region = Locale.current.region?.identifier
        let language = Locale.current.language.languageCode?.identifier
        return region == "CN" || language == "zh" ? .china : .who
    }

    var overweightThreshold: Double {
        switch self {
        case .china: return 24
        case .who: return 25
        }
    }

    var obesityThreshold: Double {
        switch self {
        case .china: return 28
        case .who: return 30
        }
    }

    var normalUpperBound: Double {
        overweightThreshold - 0.1
    }

    var noteKey: String {
        switch self {
        case .china: return "bmi.info.bmi.note.china"
        case .who: return "bmi.info.bmi.note.who"
        }
    }

    var titleKey: String {
        switch self {
        case .china: return "bmi.info.standard.bmi.china"
        case .who: return "bmi.info.standard.bmi.who"
        }
    }

    var citationKey: String {
        switch self {
        case .china: return "bmi.info.citation.bmi.source"
        case .who: return "bmi.info.citation.bmi.who"
        }
    }

    var citationURL: URL {
        switch self {
        case .china: return URL(string: "https://www.chinacdc.cn")!
        case .who: return URL(string: "https://www.who.int")!
        }
    }
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

    func calculateBMI(weight: Double) -> Double {
        let heightInMeters = height / 100.0
        guard heightInMeters > 0 else {
            return 0
        }
        return weight / (heightInMeters * heightInMeters)
    }

    func bmiCategory(bmi: Double) -> BMICategory {
        BMICategory.from(bmi: bmi, standard: .current)
    }

    enum BMICategory: String {
        case underweight
        case normal
        case overweight
        case obese
        
        static func from(bmi: Double, standard: BMIStandard = .current) -> BMICategory {
            switch bmi {
            case ..<18.5:
                return .underweight
            case 18.5..<standard.overweightThreshold:
                return .normal
            case standard.overweightThreshold..<standard.obesityThreshold:
                return .overweight
            default:
                return .obese
            }
        }

        var localizedKey: String {
            switch self {
            case .underweight: return "bmi.underweight"
            case .normal: return "bmi.normal"
            case .overweight: return "bmi.category.overweight"
            case .obese: return "bmi.obese"
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
        profile.height = 0
        profile.gender = Gender.male.rawValue
        profile.age = 0
        profile.goalWeightValue = nil
        profile.goalBodyFatPercentage = nil
        profile.goalWaistCircumferenceValue = nil
        profile.goalHipCircumferenceValue = nil
        profile.goalChestCircumferenceValue = nil
        profile.goalThighCircumferenceValue = nil
        profile.weightUnit = "kg"
        profile.createdAt = Date()
        profile.updatedAt = Date()
        return profile
    }
}

