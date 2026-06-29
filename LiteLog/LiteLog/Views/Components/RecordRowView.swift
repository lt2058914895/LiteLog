import SwiftUI

private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter
}()

private let monthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "M月"
    return formatter
}()

private let weekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter
}()

struct RecordRowView: View {
    let record: WeightRecord
    let unit: WeightUnit
    let showDate: Bool
    let weightChange: Double?
    
    private var dayString: String { dayFormatter.string(from: record.date) }
    private var monthDayString: String { monthFormatter.string(from: record.date) }
    private var weekdayString: String { weekdayFormatter.string(from: record.date) }
    private var weightString: String { unit.convertFromKg(record.weight).smartFormatted }
    private var bodyFatString: String? { record.bodyFatPercentageValue?.smartFormatted }
    private var waistString: String? { record.waistCircumferenceValue?.smartFormatted }
    private var hipString: String? { record.hipCircumferenceValue?.smartFormatted }
    private var chestString: String? { record.chestCircumferenceValue?.smartFormatted }
    private var thighString: String? { record.thighCircumferenceValue?.smartFormatted }
    private var hasSecondaryInfo: Bool {
        record.waistCircumferenceValue != nil ||
        record.hipCircumferenceValue != nil ||
        record.chestCircumferenceValue != nil ||
        record.thighCircumferenceValue != nil
    }
    
    init(record: WeightRecord, unit: WeightUnit, showDate: Bool = true, weightChange: Double? = nil) {
        self.record = record
        self.unit = unit
        self.showDate = showDate
        self.weightChange = weightChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                if showDate {
                    dateBadgeView
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    weightView
                    
                    if let bodyFat = bodyFatString {
                        bodyFatView(bodyFat)
                    }
                }
                
                Spacer()
                
                if let timePeriod = record.measurementTimePeriod,
                   let period = MeasurementTimePeriod(rawValue: timePeriod) {
                    timePeriodView(period)
                }
            }
            
            if hasSecondaryInfo {
                secondaryInfoView
            }
            
            if let note = record.note, !note.isEmpty {
                noteView(note)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(1)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: UUID())
    }
    
    private var dateBadgeView: some View {
        VStack(spacing: 2) {
            Text(weekdayString)
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
            
            Text(dayString)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(.secondaryLabel))
            
            Text(monthDayString)
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .frame(width: 44)
        .padding(.vertical, 6)
    }
    
    private var weightView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(weightString)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primaryText)
            
            Text(unit.shortName)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondaryText)
        }
    }
    
    private func bodyFatView(_ bodyFat: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "percent")
                .font(.caption)
                .foregroundColor(.primaryBlue)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(NSLocalizedString("record.body.fat", comment: ""))
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(bodyFat)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primaryBlue.opacity(0.06))
        .cornerRadius(8)
    }
    
    private var secondaryInfoView: some View {
        HStack {
            if showDate {
                Spacer().frame(width: 56)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 75))], spacing: 12) {
                if let waist = waistString {
                    measurementCardView(value: waist, unit: "cm", title: NSLocalizedString("record.waist.circumference", comment: ""))
                }
                
                if let hip = hipString {
                    measurementCardView(value: hip, unit: "cm", title: NSLocalizedString("record.hip.circumference", comment: ""))
                }
                
                if let chest = chestString {
                    measurementCardView(value: chest, unit: "cm", title: NSLocalizedString("record.chest.circumference", comment: ""))
                }
                
                if let thigh = thighString {
                    measurementCardView(value: thigh, unit: "cm", title: NSLocalizedString("record.thigh.circumference", comment: ""))
                }
            }
        }
    }
    
    private func measurementCardView(value: String, unit: String, title: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func noteView(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if showDate {
                Spacer().frame(width: 56)
            }
            
            Image(systemName: "note.text")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .padding(.top, 2)
            
            Text(note)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .lineLimit(2)
        }
    }
    
    private func timePeriodView(_ period: MeasurementTimePeriod) -> some View {
        Text(period.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.primaryBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.primaryBlue.opacity(0.1))
            .cornerRadius(8)
    }
}

struct RecordListView: View {
    let records: [WeightRecord]
    let unit: WeightUnit
    let onEdit: (WeightRecord) -> Void
    let onDelete: (WeightRecord) -> Void
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(records.indices, id: \.self) { index in
                let record = records[index]
                let weightChange = index < records.count - 1 ?
                    record.weight - records[index + 1].weight : nil
                
                RecordRowView(record: record, unit: unit, weightChange: weightChange)
                    .contextMenu {
                        Button(action: { onEdit(record) }) {
                            Label(NSLocalizedString("action.edit", comment: ""), systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: { onDelete(record) }) {
                            Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        onEdit(record)
                    }
            }
        }
    }
}
