import Foundation

enum WeightUnit: String, Codable {
    case kg

    var shortName: String {
        NSLocalizedString("unit.kg", comment: "")
    }

    func convertToKg(_ value: Double) -> Double {
        value
    }

    func convertFromKg(_ valueInKg: Double) -> Double {
        valueInKg
    }
}
