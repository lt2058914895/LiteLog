import SwiftUI

struct RecordRowView: View {
    let record: WeightRecord
    let unit: WeightUnit
    let showDate: Bool

    init(record: WeightRecord, unit: WeightUnit, showDate: Bool = true) {
        self.record = record
        self.unit = unit
        self.showDate = showDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 主要信息：日期 + 体重 + 体脂率
            HStack(spacing: 16) {
                if showDate {
                    dateView
                }

                weightView

                Spacer()

                // 体脂率
                if let bodyFat = record.bodyFatPercentage {
                    bodyFatView(bodyFat)
                }
            }

            // 次要信息：腰围、臀围、胸围、大腿围（有值才显示）
            if hasSecondaryInfo {
                HStack {
                    if showDate {
                        Spacer().frame(width: 50)
                    }
                    
                    // 使用自适应网格布局，支持自动换行
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                        if let waist = record.waistCircumference {
                            waistView(waist)
                        }

                        if let hip = record.hipCircumference {
                            hipView(hip)
                        }

                        if let chest = record.chestCircumference {
                            chestView(chest)
                        }

                        if let thigh = record.thighCircumference {
                            thighView(thigh)
                        }
                    }
                    
                    Spacer()
                }
            }

            // 备注
            if let note = record.note, !note.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    if showDate {
                        Spacer().frame(width: 50)
                    }

                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondaryText)

                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            // 测量时段
            if let timePeriod = record.measurementTimePeriod,
               let period = MeasurementTimePeriod(rawValue: timePeriod) {
                HStack {
                    Spacer()
                    timePeriodView(period)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private var hasSecondaryInfo: Bool {
        record.waistCircumference != nil ||
        record.hipCircumference != nil ||
        record.chestCircumference != nil ||
        record.thighCircumference != nil
    }

    private var dateView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dayString)
                .font(.headline)
                .foregroundColor(.primaryText)

            Text(monthDayString)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(width: 50)
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: record.date)
    }

    private var monthDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: record.date)
    }

    private var weightView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(unit.convertFromKg(record.weight).smartFormatted)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)

            Text(unit.shortName)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }

    private func bodyFatView(_ bodyFat: Double) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(NSLocalizedString("record.body.fat", comment: ""))
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
                Text("\(bodyFat.smartFormatted)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                Text("%")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
    }

    private func waistView(_ waist: Double) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(waist.smartFormatted)")
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                Text("cm")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
            
            Text(NSLocalizedString("record.waist.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func hipView(_ hip: Double) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(hip.smartFormatted)")
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                Text("cm")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }

            Text(NSLocalizedString("record.hip.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func thighView(_ thigh: Double) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(thigh.smartFormatted)")
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                Text("cm")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
            
            Text(NSLocalizedString("record.thigh.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func chestView(_ chest: Double) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(chest.smartFormatted)")
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                Text("cm")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }

            Text(NSLocalizedString("record.chest.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func timePeriodView(_ period: MeasurementTimePeriod) -> some View {
        Text(period.displayName)
            .font(.caption)
            .foregroundColor(.primaryBlue)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.primaryBlue.opacity(0.1))
            .cornerRadius(4)
    }
}

struct RecordListView: View {
    let records: [WeightRecord]
    let unit: WeightUnit
    let onEdit: (WeightRecord) -> Void
    let onDelete: (WeightRecord) -> Void

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(records, id: \.id) { record in
                RecordRowView(record: record, unit: unit)
                    .contextMenu {
                        Button(action: { onEdit(record) }) {
                            Label(NSLocalizedString("action.edit", comment: ""), systemImage: "pencil")
                        }

                        Button(role: .destructive, action: { onDelete(record) }) {
                            Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                        }
                    }
            }
        }
    }
}
