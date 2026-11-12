import SwiftUI

struct CalendarView: View {
    let records: [WeightRecord]
    let unit: WeightUnit
    @Binding var selectedDate: Date?
    let onDateSelected: (Date) -> Void

    @State private var currentMonth = Date()

    private let calendar: Calendar = Calendar.current
    private let recordsByDate: [Date: WeightRecord]
    private let trendByDate: [Date: WeightTrend]

    private enum WeightTrend {
        case increase
        case decrease
        case unchanged
        case first

        var accessibilityKey: String {
            switch self {
            case .increase:
                return "calendar.trend.up"
            case .decrease:
                return "calendar.trend.down"
            case .unchanged:
                return "calendar.trend.unchanged"
            case .first:
                return "calendar.trend.first"
            }
        }
    }

    init(records: [WeightRecord], unit: WeightUnit, selectedDate: Binding<Date?>, onDateSelected: @escaping (Date) -> Void) {
        self.records = records
        self.unit = unit
        self._selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        
        let cal = Calendar.current
        let dailyRecords = records.reduce(into: [Date: WeightRecord]()) { dict, record in
            let key = cal.startOfDay(for: record.date)
            if let existing = dict[key] {
                if record.date > existing.date ||
                    (record.date == existing.date && record.createdAt > existing.createdAt) {
                    dict[key] = record
                }
            } else {
                dict[key] = record
            }
        }
        self.recordsByDate = dailyRecords

        var trends: [Date: WeightTrend] = [:]
        var previousWeight: Double?
        for day in dailyRecords.keys.sorted() {
            guard let weight = dailyRecords[day]?.weight else { continue }
            if let previousWeight {
                let change = weight - previousWeight
                if abs(change) < 0.05 {
                    trends[day] = .unchanged
                } else {
                    trends[day] = change > 0 ? .increase : .decrease
                }
            } else {
                trends[day] = .first
            }
            previousWeight = weight
        }
        self.trendByDate = trends
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else { return [] }
        let firstDayOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: currentMonth)
        ) ?? currentMonth.startOfDay

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth)
        }
    }

    private var firstWeekdayOfMonth: Int {
        let firstDayOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: currentMonth)
        ) ?? currentMonth.startOfDay
        return (calendar.component(.weekday, from: firstDayOfMonth) - calendar.firstWeekday + 7) % 7
    }

    var body: some View {
        VStack(spacing: 16) {
            headerView

            weekdayHeaderView

            daysGridView

            Divider()

            monthlySummarySection

            trendLegend
        }
        .padding()
        .cardStyle()
    }

    private var headerView: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.primaryBlue)
            }

            Spacer()

            Text(monthYearString)
                .font(.headline)
                .foregroundColor(.primaryText)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.primaryBlue)
            }
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: currentMonth)
    }

    private var monthlyRecords: [(date: Date, record: WeightRecord)] {
        daysInMonth.compactMap { date in
            let day = calendar.startOfDay(for: date)
            guard let record = recordsByDate[day] else {
                return nil
            }
            return (day, record)
        }
    }

    private var monthlySummarySection: some View {
        let monthRecords = monthlyRecords
        let weights = monthRecords.map { unit.convertFromKg($0.record.weight) }
        let change: Double? = {
            guard weights.count >= 2,
                  let first = weights.first,
                  let last = weights.last else {
                return nil
            }
            return last - first
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("calendar.month.summary", comment: ""))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primaryText)

            HStack(spacing: 12) {
                monthlyPrimaryMetric(
                    title: NSLocalizedString("stats.average", comment: ""),
                    value: weights.average?.smartFormatted ?? "--",
                    unit: unit.shortName,
                    color: .primaryBlue
                )

                Divider()
                    .frame(height: 44)

                monthlyPrimaryMetric(
                    title: NSLocalizedString("stats.change", comment: ""),
                    value: formattedMonthlyChange(change),
                    unit: unit.shortName,
                    color: changeColor(change)
                )
            }

            HStack(spacing: 8) {
                monthlySecondaryMetric(
                    title: NSLocalizedString("stats.min", comment: ""),
                    value: weights.min().map { $0.smartFormatted } ?? "--",
                    unit: unit.shortName
                )

                monthlySecondaryMetric(
                    title: NSLocalizedString("stats.max", comment: ""),
                    value: weights.max().map { $0.smartFormatted } ?? "--",
                    unit: unit.shortName
                )

                monthlySecondaryMetric(
                    title: NSLocalizedString("stats.records", comment: ""),
                    value: localizedRecordCount(monthRecords.count),
                    unit: ""
                )
            }
        }
        .padding(12)
        .background(Color.primaryBlue.opacity(0.06))
        .cornerRadius(12)
    }

    private func monthlyPrimaryMetric(
        title: String,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthlySecondaryMetric(
        title: String,
        value: String,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.primaryBlue.opacity(0.07))
        .cornerRadius(9)
    }

    private func formattedMonthlyChange(_ change: Double?) -> String {
        guard let change else { return "--" }
        return (change > 0 ? "+" : "") + change.smartFormatted
    }

    private func changeColor(_ change: Double?) -> Color {
        guard let change, abs(change) >= 0.005 else {
            return .secondaryText
        }
        return change > 0 ? .red : .green
    }

    private var weekdayHeaderView: some View {
        HStack(spacing: 0) {
            ForEach(Array(localizedWeekdaySymbols.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var localizedWeekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else {
            return Calendar.current.veryShortStandaloneWeekdaySymbols
        }
        let firstIndex = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(firstIndex + $0) % 7] }
    }

    private var daysGridView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let emptyDays = Array(repeating: 0, count: firstWeekdayOfMonth)
        let allItems = emptyDays + Array(1...daysInMonth.count)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(allItems, id: \.self) { item in
                if item == 0 {
                    Color.clear
                        .frame(height: 40)
                } else {
                    let index = item - 1
                    if index < daysInMonth.count {
                        let date = daysInMonth[index]
                        dayCellView(date)
                    }
                }
            }
        }
    }

    private var trendLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("calendar.legend.title", comment: ""))
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondaryText)

            legendRow(
                color: .green,
                text: NSLocalizedString("calendar.legend.down", comment: "")
            )
            legendRow(
                color: .orange,
                text: NSLocalizedString("calendar.legend.up", comment: "")
            )
            legendRow(
                color: .secondaryText,
                text: neutralLegendText
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(
        color: Color,
        text: String
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
    }

    private var neutralLegendText: String {
        String(
            format: NSLocalizedString("calendar.legend.neutral.format", comment: ""),
            unit.convertFromKg(0.05).smartFormatted,
            unit.shortName
        )
    }

    private func dayCellView(_ date: Date) -> some View {
        let isSelected = selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)
        let day = calendar.startOfDay(for: date)
        let record = recordsByDate[day]
        let trend = trendByDate[day] ?? .first

        return Button(action: { selectDate(date) }) {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(textColor(isToday: isToday, isSelected: isSelected))

                if let record = record {
                    Text(unit.convertFromKg(record.weight).smartFormatted)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(weightColor(trend: trend, isSelected: isSelected))
                }
            }
            .frame(width: 44, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.primaryBlue : Color.primaryBlue.opacity(0.15))
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(date: date, record: record, trend: trend))
    }

    private func weightColor(trend: WeightTrend, isSelected: Bool) -> Color {
        if isSelected {
            return .white
        }
        switch trend {
        case .increase:
            return .orange
        case .decrease:
            return .green
        case .unchanged, .first:
            return .secondaryText
        }
    }

    private func accessibilityLabel(
        date: Date,
        record: WeightRecord?,
        trend: WeightTrend
    ) -> String {
        guard let record else {
            return date.mediumDateString
        }
        return String(
            format: NSLocalizedString("calendar.accessibility.format", comment: ""),
            date.mediumDateString,
            unit.convertFromKg(record.weight).smartFormatted,
            unit.shortName,
            NSLocalizedString(trend.accessibilityKey, comment: "")
        )
    }

    private func textColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return .white
        } else if isToday {
            return .primaryBlue
        } else {
            return .primaryText
        }
    }

    private func selectDate(_ date: Date) {
        if let selectedDate,
           calendar.isDate(selectedDate, inSameDayAs: date) {
            self.selectedDate = nil
            return
        }

        selectedDate = date
        onDateSelected(date)
    }

    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}
