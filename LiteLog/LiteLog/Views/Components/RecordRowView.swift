import SwiftUI
import CoreData

private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("d")
    return formatter
}()

private let weekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter
}()

struct RecordRowView: View, Equatable {
    let record: WeightRecord
    let unit: WeightUnit
    let showDate: Bool
    let weightChange: Double?
    
    static func == (lhs: RecordRowView, rhs: RecordRowView) -> Bool {
        lhs.record.objectID == rhs.record.objectID &&
        lhs.record.weight == rhs.record.weight &&
        lhs.record.bodyFatPercentageValue == rhs.record.bodyFatPercentageValue &&
        lhs.record.waistCircumferenceValue == rhs.record.waistCircumferenceValue &&
        lhs.record.hipCircumferenceValue == rhs.record.hipCircumferenceValue &&
        lhs.record.chestCircumferenceValue == rhs.record.chestCircumferenceValue &&
        lhs.record.thighCircumferenceValue == rhs.record.thighCircumferenceValue &&
        lhs.record.date == rhs.record.date &&
        lhs.record.measurementTimePeriod == rhs.record.measurementTimePeriod &&
        lhs.record.note == rhs.record.note &&
        lhs.unit == rhs.unit &&
        lhs.showDate == rhs.showDate &&
        lhs.weightChange == rhs.weightChange
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var dayString: String { dayFormatter.string(from: record.date) }
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
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let timePeriod = record.measurementTimePeriod,
                       let period = MeasurementTimePeriod(rawValue: timePeriod) {
                        timePeriodView(period)
                    }

                    if record.date != record.date.startOfDay {
                        Text(record.date.timeString)
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
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
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
    }
    
    private var dateBadgeView: some View {
        VStack(spacing: 2) {
            Text(dayString)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(.secondaryLabel))

            Text(weekdayString)
                .font(.system(size: 9))
                .foregroundColor(Color(.tertiaryLabel))

        }
        .frame(width: 44)
        .padding(.vertical, 6)
    }
    
    private var weightView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(weightString)
                .font(.system(size: 20, weight: .bold, design: .rounded))
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
                Text(NSLocalizedString("measure.body.fat", comment: ""))
                    .font(.system(size: 9))
                    .foregroundColor(.secondaryText)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(bodyFat)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primaryText)
                    
                    Text("%")
                        .font(.system(size: 10))
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
            
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 68, maximum: 96), spacing: 8)
                ],
                spacing: 8
            ) {
                if let waist = waistString {
                    measurementCardView(value: waist, unit: "cm", title: NSLocalizedString("measure.waist", comment: ""))
                }
                
                if let hip = hipString {
                    measurementCardView(value: hip, unit: "cm", title: NSLocalizedString("measure.hip", comment: ""))
                }
                
                if let chest = chestString {
                    measurementCardView(value: chest, unit: "cm", title: NSLocalizedString("measure.chest", comment: ""))
                }
                
                if let thigh = thighString {
                    measurementCardView(value: thigh, unit: "cm", title: NSLocalizedString("measure.thigh", comment: ""))
                }
            }
        }
    }
    
    private func measurementCardView(value: String, unit: String, title: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground))
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
            ForEach(records.computeWeightChanges(), id: \.record.objectID) { item in
                EquatableView(content: RecordRowView(record: item.record, unit: unit, weightChange: item.weightChange))
                    .contextMenu {
                        Button(action: { onEdit(item.record) }) {
                            Label(NSLocalizedString("action.edit", comment: ""), systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: { onDelete(item.record) }) {
                            Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        onEdit(item.record)
                    }
            }
        }
    }
}
