import Foundation

struct TrendEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double
    let bodyFatPercentage: Double?
    let waistCircumference: Double?
    let hipCircumference: Double?
    let chestCircumference: Double?
    let thighCircumference: Double?
    let measurementTimePeriod: MeasurementTimePeriod?
    let createdAt: Date

    init(record: WeightRecord) {
        id = record.id
        date = record.date
        weight = record.weight
        bodyFatPercentage = record.bodyFatPercentageValue
        waistCircumference = record.waistCircumferenceValue
        hipCircumference = record.hipCircumferenceValue
        chestCircumference = record.chestCircumferenceValue
        thighCircumference = record.thighCircumferenceValue
        measurementTimePeriod = record.measurementTimePeriod.flatMap(MeasurementTimePeriod.init(rawValue:))
        createdAt = record.createdAt
    }
}

enum MeasurementScope: String, CaseIterable, Identifiable {
    case all
    case morningFasting
    case afterExercise
    case beforeBed

    var id: String { rawValue }

    var localizedKey: String {
        switch self {
        case .all:
            return "stats.scope.all"
        case .morningFasting:
            return "period.morning_fasting"
        case .afterExercise:
            return "period.after_exercise"
        case .beforeBed:
            return "period.before_bed"
        }
    }

    var preferredPeriod: MeasurementTimePeriod? {
        switch self {
        case .all:
            return nil
        case .morningFasting:
            return .morningFasting
        case .afterExercise:
            return .afterExercise
        case .beforeBed:
            return .beforeBed
        }
    }
}

struct WeightGoalEstimate {
    enum Status {
        case reached
        case insufficientData
        case diverging
        case available
    }

    let status: Status
    let observedDays: Int
    let observedPoints: Int
    let estimatedDays: ClosedRange<Int>?

    var summaryText: String {
        switch status {
        case .reached:
            return NSLocalizedString("home.goal.achieved", comment: "")
        case .insufficientData:
            return String(
                format: NSLocalizedString("goal.forecast.insufficient", comment: ""),
                observedDays,
                observedPoints
            )
        case .diverging:
            return NSLocalizedString("goal.forecast.diverging", comment: "")
        case .available:
            guard let days = estimatedDays else {
                return NSLocalizedString("goal.forecast.diverging", comment: "")
            }
            let lowerWeeks = max(Double(days.lowerBound) / 7.0, 1)
            let upperWeeks = max(Double(days.upperBound) / 7.0, lowerWeeks + 1)
            return String(
                format: NSLocalizedString("goal.forecast.available", comment: ""),
                lowerWeeks.smartFormatted,
                upperWeeks.smartFormatted
            )
        }
    }
}

enum GoalDirection: Equatable {
    case decrease
    case increase

    private static let tolerance = 0.005

    static func infer(
        target: Double,
        baseline: Double?,
        current: Double
    ) -> GoalDirection {
        let reference = baseline ?? current
        if target < reference - tolerance {
            return .decrease
        }
        if target > reference + tolerance {
            return .increase
        }
        return current < target ? .decrease : .increase
    }

    func isAchieved(current: Double, target: Double) -> Bool {
        switch self {
        case .decrease:
            return current <= target + Self.tolerance
        case .increase:
            return current >= target - Self.tolerance
        }
    }

    func remaining(current: Double, target: Double) -> Double {
        switch self {
        case .decrease:
            return max(current - target, 0)
        case .increase:
            return max(target - current, 0)
        }
    }
}

enum TrendAnalytics {
    @MainActor
    static func entries(from records: [WeightRecord]) -> [TrendEntry] {
        var result: [TrendEntry] = []
        result.reserveCapacity(records.count)
        for record in records {
            result.append(TrendEntry(record: record))
        }
        return result
    }

    static func dailyEntries(
        from entries: [TrendEntry],
        scope: MeasurementScope,
        calendar: Calendar = .current
    ) -> [TrendEntry] {
        let grouped = Dictionary(grouping: entries) {
            calendar.startOfDay(for: $0.date)
        }

        return grouped.compactMap { _, dayEntries in
            switch scope {
            case .all:
                return latest(from: dayEntries)
            default:
                guard let preferredPeriod = scope.preferredPeriod else {
                    return latest(from: dayEntries)
                }
                return latest(from: dayEntries.filter {
                    $0.measurementTimePeriod == preferredPeriod
                })
            }
        }
        .sorted { $0.date < $1.date }
    }

    static func entries(
        from dailyEntries: [TrendEntry],
        lastDays days: Int,
        endingAt endDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [TrendEntry] {
        guard days > 0 else { return [] }
        let endDay = calendar.startOfDay(for: endDate)
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) ?? endDay
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDate.endOfDay

        return dailyEntries.filter {
            $0.date >= startDay && $0.date < endExclusive
        }
    }

    static func estimateWeightGoal(
        from dailyEntries: [TrendEntry],
        targetWeight: Double,
        minimumDays: Int = 14,
        minimumPoints: Int = 7,
        analysisDays: Int = 28,
        calendar: Calendar = .current
    ) -> WeightGoalEstimate {
        guard let latestEntry = dailyEntries.last else {
            return WeightGoalEstimate(
                status: .insufficientData,
                observedDays: 0,
                observedPoints: 0,
                estimatedDays: nil
            )
        }

        let window = entries(
            from: dailyEntries,
            lastDays: analysisDays,
            endingAt: latestEntry.date,
            calendar: calendar
        )
        guard let firstEntry = window.first else {
            return WeightGoalEstimate(
                status: .insufficientData,
                observedDays: 0,
                observedPoints: 0,
                estimatedDays: nil
            )
        }

        let observedDays = max(
            (calendar.dateComponents([.day], from: firstEntry.date, to: latestEntry.date).day ?? 0) + 1,
            1
        )
        let observedPoints = window.count
        let remaining = targetWeight - latestEntry.weight

        if abs(remaining) <= 0.05 {
            return WeightGoalEstimate(
                status: .reached,
                observedDays: observedDays,
                observedPoints: observedPoints,
                estimatedDays: nil
            )
        }

        guard observedDays >= minimumDays, observedPoints >= minimumPoints else {
            return WeightGoalEstimate(
                status: .insufficientData,
                observedDays: observedDays,
                observedPoints: observedPoints,
                estimatedDays: nil
            )
        }

        let regression = linearRegression(
            entries: window,
            calendar: calendar
        )
        guard abs(regression.slope) >= 0.001,
              regression.slope * remaining > 0 else {
            return WeightGoalEstimate(
                status: .diverging,
                observedDays: observedDays,
                observedPoints: observedPoints,
                estimatedDays: nil
            )
        }

        let rawDays = remaining / regression.slope
        guard rawDays.isFinite, rawDays > 0 else {
            return WeightGoalEstimate(
                status: .diverging,
                observedDays: observedDays,
                observedPoints: observedPoints,
                estimatedDays: nil
            )
        }

        let lowerDays = max(Int((rawDays * 0.8).rounded()), 1)
        let upperDays = max(Int((rawDays * 1.2).rounded()), lowerDays + 1)

        return WeightGoalEstimate(
            status: .available,
            observedDays: observedDays,
            observedPoints: observedPoints,
            estimatedDays: lowerDays...upperDays
        )
    }

    private static func latest(from entries: [TrendEntry]) -> TrendEntry? {
        entries.max {
            if $0.date != $1.date {
                return $0.date < $1.date
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private static func linearRegression(
        entries: [TrendEntry],
        calendar: Calendar
    ) -> (slope: Double, intercept: Double) {
        guard let firstDate = entries.first?.date else {
            return (0, 0)
        }

        let points = entries.map { entry -> (Double, Double) in
            let x = Double(calendar.dateComponents([.day], from: firstDate, to: entry.date).day ?? 0)
            return (x, entry.weight)
        }
        let count = Double(points.count)
        let meanX = points.reduce(0) { $0 + $1.0 } / count
        let meanY = points.reduce(0) { $0 + $1.1 } / count
        let numerator = points.reduce(0) { partial, point in
            partial + (point.0 - meanX) * (point.1 - meanY)
        }
        let denominator = points.reduce(0) { partial, point in
            partial + pow(point.0 - meanX, 2)
        }
        guard denominator > 0 else { return (0, meanY) }

        let slope = numerator / denominator
        return (slope, meanY - slope * meanX)
    }
}
