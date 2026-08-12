import Foundation
import SwiftUI
import os

final class ExportManager {
    static let shared = ExportManager()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "ExportManager")
    private init() {}

    enum ExportFormat {
        case csv
        case json
    }

    func exportToCSV(records: [WeightRecord], unit: WeightUnit) -> URL? {
        var csvContent = "Date,Weight (\(unit.shortName)),Body Fat (%),Note\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for record in records.sorted(by: { $0.date > $1.date }) {
            let dateString = dateFormatter.string(from: record.date)
            let weight = unit.convertFromKg(record.weight)
            let bodyFat = record.bodyFatPercentageValue.map { String(format: "%.1f", $0) } ?? ""
            let note = record.note?.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ") ?? ""

            csvContent += "\(dateString),\(String(format: "%.1f", weight)),\(bodyFat),\"\(note)\"\n"
        }

        let fileName = "LiteLog_Export_\(dateFormatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            Self.logger.error("Error writing CSV: \(error.localizedDescription)")
            return nil
        }
    }

    func exportSummary(records: [WeightRecord], profile: UserProfile?, unit: WeightUnit) -> String {
        guard !records.isEmpty else { return NSLocalizedString("common.no.data", comment: "") }

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
            summary += "\nGoal Weight: \(profile.goalWeightValue.map { String(format: "%.1f", unit.convertFromKg($0)) } ?? "--") \(unit.shortName)"
        }

        return summary
    }

    func exportToJSON(records: [WeightRecord], unit: WeightUnit) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let exportData = records.sorted(by: { $0.date > $1.date }).map { record in
            [
                "id": record.id.uuidString,
                "date": dateFormatter.string(from: record.date),
                "weight": String(format: "%.1f", unit.convertFromKg(record.weight)),
                "weightUnit": unit.shortName,
                "bodyFatPercentage": record.bodyFatPercentageValue.map { String(format: "%.1f", $0) },
                "waistCircumference": record.waistCircumferenceValue.map { String(format: "%.1f", $0) },
                "hipCircumference": record.hipCircumferenceValue.map { String(format: "%.1f", $0) },
                "chestCircumference": record.chestCircumferenceValue.map { String(format: "%.1f", $0) },
                "thighCircumference": record.thighCircumferenceValue.map { String(format: "%.1f", $0) },
                "note": record.note,
                "measurementTimePeriod": record.measurementTimePeriod
            ] as [String: Any?]
        }

        let jsonObject: [String: Any] = [
            "exportDate": dateFormatter.string(from: Date()),
            "totalRecords": records.count,
            "unit": unit.shortName,
            "records": exportData
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            
            let fileName = "LiteLog_Export_\(dateFormatter.string(from: Date())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            Self.logger.error("Error writing JSON: \(error.localizedDescription)")
            return nil
        }
    }

    func export(records: [WeightRecord], unit: WeightUnit, format: ExportFormat) -> URL? {
        switch format {
        case .csv:
            return exportToCSV(records: records, unit: unit)
        case .json:
            return exportToJSON(records: records, unit: unit)
        }
    }
}
