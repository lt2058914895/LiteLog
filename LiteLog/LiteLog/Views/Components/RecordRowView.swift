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
        HStack(spacing: 16) {
            if showDate {
                dateView
            }

            weightView

            Spacer()

            if let bodyFat = record.bodyFatPercentage {
                bodyFatView(bodyFat)
            }

            if let waist = record.waistCircumference {
                waistView(waist)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.tertiaryText)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.cardBackground)
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
            Text(unit.convertFromKg(record.weight).weightString)
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
            Text("\(bodyFat.weightString)%")
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Text(NSLocalizedString("record.body.fat", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
    }

    private func waistView(_ waist: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(waist.weightString)cm")
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Text(NSLocalizedString("record.waist.circumference", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
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
