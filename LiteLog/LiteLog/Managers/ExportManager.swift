import Foundation
import SwiftUI

final class ExportManager {
    static let shared = ExportManager()

    private init() {}

    func exportToCSV(records: [WeightRecord], unit: WeightUnit) -> URL? {
        var csvContent = "Date,Weight (\(unit.shortName)),Body Fat (%),Note\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for record in records.sorted(by: { $0.date > $1.date }) {
            let dateString = dateFormatter.string(from: record.date)
            let weight = unit.convertFromKg(record.weight)
            let bodyFat = record.bodyFatPercentage.map { String(format: "%.1f", $0) } ?? ""
            let note = record.note?.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ") ?? ""

            csvContent += "\(dateString),\(String(format: "%.1f", weight)),\(bodyFat),\"\(note)\"\n"
        }

        let fileName = "LiteLog_Export_\(dateFormatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }

    func exportSummary(records: [WeightRecord], profile: UserProfile?, unit: WeightUnit) -> String {
        guard !records.isEmpty else { return NSLocalizedString("stats.no.data", comment: "") }

        let sortedRecords = records.sorted { $0.date < $1.date }
        let weightsInUnit = sortedRecords.map { unit.convertFromKg($0.weight) }
        let averageWeight = weightsInUnit.reduce(0, +) / Double(weightsInUnit.count)

        let startWeight = weightsInUnit.first ?? 0
        let endWeight = weightsInUnit.last ?? 0
        let totalChange = endWeight - startWeight

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDate = dateFormatter.string(from: sortedRecords.first?.date ?? Date())
        let endDate = dateFormatter.string(from: sortedRecords.last?.date ?? Date())

        var summary = """
        ====================
        LiteLog Export Summary
        ====================

        Export Date: \(dateFormatter.string(from: Date()))
        Period: \(startDate) to \(endDate)
        Total Records: \(records.count)

        Average Weight: \(String(format: "%.1f", averageWeight)) \(unit.shortName)

        Starting Weight: \(String(format: "%.1f", startWeight)) \(unit.shortName)
        Ending Weight: \(String(format: "%.1f", endWeight)) \(unit.shortName)
        Total Change: \(totalChange >= 0 ? "+" : "")\(String(format: "%.1f", totalChange)) \(unit.shortName)
        """

        if let profile = profile {
            let latestBMI = profile.calculateBMI(weight: sortedRecords.last?.weight ?? 0)
            summary += "\n\nLatest BMI: \(String(format: "%.1f", latestBMI))"
            summary += "\nBMI Category: \(profile.bmiCategory(bmi: latestBMI).displayName)"
            summary += "\nGoal Weight: \(String(format: "%.1f", unit.convertFromKg(profile.goalWeight))) \(unit.shortName)"
        }

        return summary
    }
}
