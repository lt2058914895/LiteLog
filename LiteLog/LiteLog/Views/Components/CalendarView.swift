import SwiftUI

struct CalendarView: View {
    let records: [WeightRecord]
    let unit: WeightUnit
    @Binding var selectedDate: Date?
    let onDateSelected: (Date) -> Void

    @State private var currentMonth = Date()

    private let calendar: Calendar = Calendar.current
    private let recordDates: Set<Date>
    private let recordsByDate: [Date: WeightRecord]

    init(records: [WeightRecord], unit: WeightUnit, selectedDate: Binding<Date?>, onDateSelected: @escaping (Date) -> Void) {
        self.records = records
        self.unit = unit
        self._selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        
        let cal = Calendar.current
        self.recordDates = Set(records.map { cal.startOfDay(for: $0.date) })
        self.recordsByDate = records.reduce(into: [Date: WeightRecord]()) { dict, record in
            let key = cal.startOfDay(for: record.date)
            if let existing = dict[key] {
                if record.date > existing.date {
                    dict[key] = record
                }
            } else {
                dict[key] = record
            }
        }
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else { return [] }
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth)
        }
    }

    private var firstWeekdayOfMonth: Int {
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        return calendar.component(.weekday, from: firstDayOfMonth) - 1
    }

    var body: some View {
        VStack(spacing: 16) {
            headerView

            weekdayHeaderView

            daysGridView
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
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: currentMonth)
    }

    private var weekdayHeaderView: some View {
        HStack(spacing: 0) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
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

    private func dayCellView(_ date: Date) -> some View {
        let isSelected = selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        _ = recordDates.contains(calendar.startOfDay(for: date))
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)
        let record = recordsByDate[calendar.startOfDay(for: date)]

        return Button(action: { selectDate(date) }) {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(textColor(isToday: isToday, isSelected: isSelected))

                if let record = record {
                    Text(unit.convertFromKg(record.weight).smartFormatted)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white : .secondaryText)
                }
            }
            .frame(width: 44, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.primaryBlue : Color.primaryBlue.opacity(0.15))
            )
        }
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
