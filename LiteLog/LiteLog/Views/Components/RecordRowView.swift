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

struct RecordRowView: View {
    let record: WeightRecord
    let unit: WeightUnit
    let showDate: Bool
    
    private let dayString: String
    private let monthDayString: String
    private let weightString: String
    private let bodyFatString: String?
    private let waistString: String?
    private let hipString: String?
    private let chestString: String?
    private let thighString: String?
    private let hasSecondaryInfo: Bool
    
    init(record: WeightRecord, unit: WeightUnit, showDate: Bool = true) {
        self.record = record
        self.unit = unit
        self.showDate = showDate
        self.dayString = dayFormatter.string(from: record.date)
        self.monthDayString = monthFormatter.string(from: record.date)
        self.weightString = unit.convertFromKg(record.weight).smartFormatted
        self.bodyFatString = record.bodyFatPercentageValue?.smartFormatted
        self.waistString = record.waistCircumferenceValue?.smartFormatted
        self.hipString = record.hipCircumferenceValue?.smartFormatted
        self.chestString = record.chestCircumferenceValue?.smartFormatted
        self.thighString = record.thighCircumferenceValue?.smartFormatted
        self.hasSecondaryInfo = record.waistCircumferenceValue != nil ||
                               record.hipCircumferenceValue != nil ||
                               record.chestCircumferenceValue != nil ||
                               record.thighCircumferenceValue != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                if showDate {
                    dateView
                }
                
                weightView
                
                Spacer()
                
                if let bodyFat = bodyFatString {
                    bodyFatView(bodyFat)
                }
            }
            
            if hasSecondaryInfo {
                HStack {
                    if showDate {
                        Spacer().frame(width: 50)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                        if let waist = waistString {
                            waistView(waist)
                        }
                        
                        if let hip = hipString {
                            hipView(hip)
                        }
                        
                        if let chest = chestString {
                            chestView(chest)
                        }
                        
                        if let thigh = thighString {
                            thighView(thigh)
                        }
                    }
                    
                    Spacer()
                }
            }
            
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
        .adaptiveCardBackground()
        .cornerRadius(12)
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
    
    private var weightView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(weightString)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Text(unit.shortName)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
    
    private func bodyFatView(_ bodyFat: String) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(NSLocalizedString("record.body.fat", comment: ""))
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
                Text(bodyFat)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                Text("%")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
    }
    
    private func waistView(_ waist: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(waist)
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
    
    private func hipView(_ hip: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(hip)
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
    
    private func thighView(_ thigh: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(thigh)
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
    
    private func chestView(_ chest: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(chest)
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
            ForEach(records, id: \.objectID) { record in
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
