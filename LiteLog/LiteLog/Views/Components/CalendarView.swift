import SwiftUI

struct CalendarView: View {
    let records: [WeightRecord]
    let unit: WeightUnit
    @Binding var selectedDate: Date?
    let onDateSelected: (Date) -> Void

    @State private var currentMonth = Date()

    private var calendar: Calendar { Calendar.current }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else { return [] }
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth)
        }
    }

    private var recordDates: Set<Date> {
        Set(records.map { calendar.startOfDay(for: $0.date) })
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

        return LazyVGrid(columns: columns, spacing: 8) {
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
        let hasRecord = recordDates.contains(calendar.startOfDay(for: date))
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)

        return Button(action: { selectDate(date) }) {
            VStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundColor(textColor(isToday: isToday, isSelected: isSelected))

                if hasRecord {
                    Circle()
                        .fill(Color.primaryBlue)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.primaryBlue.opacity(0.2) : Color.clear)
            )
        }
    }

    private func textColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return .primaryBlue
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
