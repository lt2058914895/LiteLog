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
        var csvContent = "\u{FEFF}" + [
            "Date",
            "Time",
            "Period",
            "Weight (\(unit.shortName))",
            "Body Fat (%)",
            "Waist (cm)",
            "Hip (cm)",
            "Chest (cm)",
            "Thigh (cm)",
            "Note"
        ].joined(separator: ",") + "\n"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = .autoupdatingCurrent
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.calendar = Calendar(identifier: .gregorian)
        timeFormatter.timeZone = .autoupdatingCurrent
        timeFormatter.dateFormat = "HH:mm"

        for record in records.sorted(by: { $0.date > $1.date }) {
            let period = record.measurementTimePeriod
                .flatMap(MeasurementTimePeriod.init(rawValue:))?.displayName
                ?? record.measurementTimePeriod
                ?? ""
            let fields = [
                dateFormatter.string(from: record.date),
                timeFormatter.string(from: record.date),
                csvField(period),
                csvNumber(unit.convertFromKg(record.weight)),
                csvNumber(record.bodyFatPercentageValue),
                csvNumber(record.waistCircumferenceValue),
                csvNumber(record.hipCircumferenceValue),
                csvNumber(record.chestCircumferenceValue),
                csvNumber(record.thighCircumferenceValue),
                csvField(record.note ?? "")
            ]
            csvContent += fields.joined(separator: ",") + "\n"
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

    private func csvNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        let formatted = String(format: "%.2f", value)
        return formatted
            .trimmingTrailingDecimalZeros
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
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
