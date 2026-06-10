import Foundation

enum WeightUnit: String, Codable {
    case kg

    var displayName: String {
        return NSLocalizedString("unit.kg", comment: "")
    }

    var shortName: String {
        return NSLocalizedString("home.kg", comment: "")
    }

    func convert(_ value: Double, to unit: WeightUnit) -> Double {
        return value
    }

    func convertToKg(_ value: Double) -> Double {
        return value
    }

    func convertFromKg(_ valueInKg: Double) -> Double {
        return valueInKg
    }
}