import Foundation

enum WeightUnit: String, Codable, CaseIterable {
    case kg
    case lb

    var displayName: String {
        switch self {
        case .kg:
            return NSLocalizedString("unit.kg", comment: "")
        case .lb:
            return NSLocalizedString("unit.lb", comment: "")
        }
    }

    var shortName: String {
        switch self {
        case .kg:
            return NSLocalizedString("home.kg", comment: "")
        case .lb:
            return NSLocalizedString("home.lb", comment: "")
        }
    }

    func convert(_ value: Double, to unit: WeightUnit) -> Double {
        if self == unit { return value }
        switch (self, unit) {
        case (.kg, .lb):
            return value * 2.20462
        case (.lb, .kg):
            return value / 2.20462
        default:
            return value
        }
    }

    func convertToKg(_ value: Double) -> Double {
        switch self {
        case .kg: return value
        case .lb: return value / 2.20462
        }
    }

    func convertFromKg(_ valueInKg: Double) -> Double {
        switch self {
        case .kg: return valueInKg
        case .lb: return valueInKg * 2.20462
        }
    }
}
