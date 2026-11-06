import Foundation
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

    func export(
        records: [WeightRecord],
        profile: UserProfile?,
        settings: SettingsManager,
        unit: WeightUnit,
        format: ExportFormat
    ) -> URL? {
        switch format {
        case .csv:
            return exportToCSV(records: records, unit: unit)
        case .json:
            do {
                return try LocalBackupManager.shared.exportBackup(
                    records: records,
                    profile: profile,
                    settings: settings
                )
            } catch {
                Self.logger.error("Error writing backup: \(error.localizedDescription)")
                return nil
            }
        }
    }
}
