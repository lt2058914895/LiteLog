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
        VStack(alignment: .leading, spacing: 12) {
            // 主要信息：日期 + 体重
            HStack(spacing: 16) {
                if showDate {
                    dateView
                }

                weightView

                Spacer()

                // 测量时段（如果有值）
                if let timePeriod = record.measurementTimePeriod, 
                   let period = MeasurementTimePeriod(rawValue: timePeriod) {
                    timePeriodView(period)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }

            // 次要信息：体脂率、腰围、臀围、胸围、大腿围（有值才显示）
            if hasSecondaryInfo {
                HStack(spacing: 16) {
                    if showDate {
                        Spacer().frame(width: 50)
                    }

                    if let bodyFat = record.bodyFatPercentage {
                        bodyFatView(bodyFat)
                    }

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

                    Spacer()
                }
            }

            // 备注（如果有值）
            if let note = record.note, !note.isEmpty {
                HStack(spacing: 8) {
                    if showDate {
                        Spacer().frame(width: 50)
                    }

                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondaryText)

                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondaryText)

                    Spacer()
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private var hasSecondaryInfo: Bool {
        record.bodyFatPercentage != nil ||
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
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(bodyFat.smartFormatted)%")
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Text(NSLocalizedString("record.body.fat", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
    }

    private func waistView(_ waist: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(waist.smartFormatted)cm")
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Text(NSLocalizedString("record.waist.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
    }

    private func hipView(_ hip: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(hip.smartFormatted)cm")
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Text(NSLocalizedString("record.hip.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
    }

    private func thighView(_ thigh: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(thigh.smartFormatted)cm")
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Text(NSLocalizedString("record.thigh.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
    }

    private func chestView(_ chest: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(chest.smartFormatted)cm")
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Text(NSLocalizedString("record.chest.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
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
