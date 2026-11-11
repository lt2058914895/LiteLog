import SwiftUI
import CoreData

struct StatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: true)])
    private var records: FetchedResults<WeightRecord>

    @State private var selectedPeriod: Period = .week
    @State private var selectedMetric: Metric = .weight
    @State private var selectedScope: MeasurementScope = .all
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showYearPicker = false
    @State private var showingProfileEditor = false

    private let minYear = 2000
    private let maxYear = Calendar.current.component(.year, from: Date())

    enum Period: String, CaseIterable {
        case week = "stats.week"
        case month = "stats.month"
        case quarter = "stats.quarter"
        case year = "stats.year"

        var localizedKey: String { rawValue }
    }

    enum Metric: String, CaseIterable, Identifiable {
        case weight = "measure.weight"
        case bodyFat = "measure.body.fat"
        case waist = "measure.waist"
        case hip = "measure.hip"
        case chest = "measure.chest"
        case thigh = "measure.thigh"

        var id: String { rawValue }
        var localizedKey: String { rawValue }

        func unit(weightUnit: WeightUnit) -> String {
            switch self {
            case .weight:
                return weightUnit.shortName
            case .bodyFat:
                return "%"
            case .waist, .hip, .chest, .thigh:
                return "cm"
            }
        }

        var color: Color {
            switch self {
            case .weight: return .primaryBlue
            case .bodyFat: return .purple
            case .waist: return .orange
            case .hip: return .green
            case .chest: return .pink
            case .thigh: return .cyan
            }
        }

        func value(in entry: TrendEntry, weightUnit: WeightUnit) -> Double? {
            let value: Double?
            switch self {
            case .weight:
                value = weightUnit.convertFromKg(entry.weight)
            case .bodyFat:
                value = entry.bodyFatPercentage
            case .waist:
                value = entry.waistCircumference
            case .hip:
                value = entry.hipCircumference
            case .chest:
                value = entry.chestCircumference
            case .thigh:
                value = entry.thighCircumference
            }
            return value.flatMap { $0 > 0 ? $0 : nil }
        }
    }

    private var allEntries: [TrendEntry] {
        TrendAnalytics.entries(from: Array(records))
    }

    private var scopedDailyEntries: [TrendEntry] {
        TrendAnalytics.dailyEntries(from: allEntries, scope: selectedScope)
    }

    private var rangeStartDate: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .week:
            return calendar.date(byAdding: .day, value: -6, to: Date().startOfDay) ?? Date().startOfDay
        case .month:
            return calendar.date(byAdding: .day, value: -29, to: Date().startOfDay) ?? Date().startOfDay
        case .quarter:
            return calendar.date(byAdding: .day, value: -89, to: Date().startOfDay) ?? Date().startOfDay
        case .year:
            var components = DateComponents()
            components.year = selectedYear
            components.month = 1
            components.day = 1
            return calendar.date(from: components) ?? Date()
        }
    }

    private var rangeEndDate: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .week, .month, .quarter:
            return Date().endOfDay
        case .year:
            var components = DateComponents()
            components.year = selectedYear
            components.month = 12
            components.day = 31
            return calendar.date(from: components)?.endOfDay ?? Date()
        }
    }

    private var scopedRangeEntries: [TrendEntry] {
        scopedDailyEntries.filter {
            $0.date >= rangeStartDate && $0.date <= rangeEndDate
        }
    }

    private var originalMetricData: [(Date, Double)] {
        metricData(for: selectedMetric, in: scopedRangeEntries)
    }

    private var currentMetricAverage: Double? {
        originalMetricData.map(\.1).average
    }

    private var currentMetricChange: Double? {
        guard originalMetricData.count >= 2,
              let first = originalMetricData.first?.1,
              let last = originalMetricData.last?.1 else {
            return nil
        }
        return last - first
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    periodPicker
                        .padding()

                    ScrollView {
                        VStack(spacing: 20) {
                            metricPicker
                            scopePicker

                            if records.isEmpty {
                                EmptyStateView(
                                    icon: "chart.bar",
                                    title: NSLocalizedString("common.no.data", comment: ""),
                                    message: NSLocalizedString("home.start.record", comment: "")
                                )
                            } else {
                                metricSummarySection
                                metricChart
                            }
                        }
                        .padding()
                        .frame(width: geometry.size.width)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ProfileToolbarChip {
                        showingProfileEditor = true
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingProfileEditor) {
                UserInfoEditorView()
            }
            .onChange(of: selectedPeriod) { newValue in
                if newValue != .year {
                    selectedYear = maxYear
                }
            }
            .sheet(isPresented: $showYearPicker) {
                yearPickerSheet
            }
        }
    }

    private var periodPicker: some View {
        VStack(spacing: 12) {
            Picker(NSLocalizedString("stats.period", comment: ""), selection: $selectedPeriod) {
                ForEach(Period.allCases, id: \.self) { period in
                    Text(NSLocalizedString(period.localizedKey, comment: ""))
                        .tag(period)
                }
            }
            .pickerStyle(.segmented)

            if selectedPeriod == .year {
                yearPicker
            }
        }
    }

    private var yearPicker: some View {
        HStack(spacing: 12) {
            Button(action: { selectedYear -= 1 }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(selectedYear <= minYear ? .gray : .primaryBlue)
                    .frame(width: 32, height: 32)
                    .background(selectedYear <= minYear ? Color.gray.opacity(0.1) : Color.primaryBlue.opacity(0.1))
                    .cornerRadius(8)
            }
            .disabled(selectedYear <= minYear)

            Button(action: { showYearPicker = true }) {
                Text("\(selectedYear)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity)
            }

            Button(action: { selectedYear += 1 }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(selectedYear >= maxYear ? .gray : .primaryBlue)
                    .frame(width: 32, height: 32)
                    .background(selectedYear >= maxYear ? Color.gray.opacity(0.1) : Color.primaryBlue.opacity(0.1))
                    .cornerRadius(8)
            }
            .disabled(selectedYear >= maxYear)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        .cornerRadius(12)
    }

    private var yearPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(NSLocalizedString("stats.year", comment: ""), selection: $selectedYear) {
                    ForEach(minYear...maxYear, id: \.self) { year in
                        Text("\(year)").tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .padding()

                Button(NSLocalizedString("action.done", comment: "")) {
                    showYearPicker = false
                }
                .primaryButtonStyle()
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("stats.year", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        showYearPicker = false
                    }
                }
            }
        }
    }

    private var metricPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("stats.metric", comment: ""))
                .font(.caption)
                .foregroundColor(.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Metric.allCases) { metric in
                        Button(action: { selectedMetric = metric }) {
                            Text(NSLocalizedString(metric.localizedKey, comment: ""))
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedMetric == metric ? selectedMetric.color.opacity(0.2) : chipBackground)
                                .foregroundColor(selectedMetric == metric ? selectedMetric.color : .secondaryText)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("stats.scope", comment: ""))
                .font(.caption)
                .foregroundColor(.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MeasurementScope.allCases) { scope in
                        Button(action: { selectedScope = scope }) {
                            Text(NSLocalizedString(scope.localizedKey, comment: ""))
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedScope == scope ? Color.primaryBlue.opacity(0.18) : chipBackground)
                                .foregroundColor(selectedScope == scope ? .primaryBlue : .secondaryText)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        }
    }

    private var chipBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var metricSummarySection: some View {
        let values = originalMetricData.map(\.1)
        let metricUnit = selectedMetric.unit(weightUnit: settingsManager.weightUnit)

        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                summaryPrimaryMetric(
                    title: NSLocalizedString("stats.average", comment: ""),
                    value: currentMetricAverage?.smartFormatted ?? "--",
                    unit: metricUnit,
                    color: selectedMetric.color
                )

                Divider()
                    .frame(height: 54)

                summaryPrimaryMetric(
                    title: NSLocalizedString("stats.change", comment: ""),
                    value: formattedChange(currentMetricChange),
                    unit: metricUnit,
                    color: changeColor(currentMetricChange)
                )
            }

            HStack(spacing: 8) {
                summarySecondaryMetric(
                    title: NSLocalizedString("stats.min", comment: ""),
                    value: values.min()?.smartFormatted ?? "--",
                    unit: metricUnit
                )

                summarySecondaryMetric(
                    title: NSLocalizedString("stats.max", comment: ""),
                    value: values.max()?.smartFormatted ?? "--",
                    unit: metricUnit
                )

                summarySecondaryMetric(
                    title: NSLocalizedString("stats.records", comment: ""),
                    value: localizedRecordCount(originalMetricData.count),
                    unit: ""
                )
            }
        }
        .padding()
        .cardStyle()
    }

    private func summaryPrimaryMetric(
        title: String,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summarySecondaryMetric(
        title: String,
        value: String,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(selectedMetric.color.opacity(0.07))
        .cornerRadius(10)
    }

    private var metricChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("home.trend", comment: ""))
                    .font(.headline)
                    .foregroundColor(.primaryText)

                Text(NSLocalizedString(selectedMetric.localizedKey, comment: ""))
                    .font(.subheadline)
                    .foregroundColor(selectedMetric.color)

                Text(selectedMetric.unit(weightUnit: settingsManager.weightUnit))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primaryText.opacity(0.82))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedMetric.color.opacity(0.12))
                    .cornerRadius(8)

                Spacer()
            }

            if originalMetricData.isEmpty {
                Text(NSLocalizedString("common.no.data", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .cardStyle()
            } else {
                ModernTrendChartView(
                    data: originalMetricData,
                    color: selectedMetric.color,
                    unit: selectedMetric.unit(weightUnit: settingsManager.weightUnit),
                    title: "",
                    period: selectedPeriod,
                    chartRange: rangeStartDate...rangeEndDate,
                    showsUnitInHeader: false
                )
            }
        }
    }

    private func metricData(for metric: Metric, in entries: [TrendEntry]) -> [(Date, Double)] {
        entries.compactMap { entry in
            metric.value(in: entry, weightUnit: settingsManager.weightUnit).map {
                (entry.date.startOfDay, $0)
            }
        }
    }

    private func formattedChange(_ change: Double?) -> String {
        formattedSigned(change ?? 0, emptyWhenNil: change == nil)
    }

    private func formattedSigned(_ value: Double, emptyWhenNil: Bool = false) -> String {
        if emptyWhenNil {
            return "--"
        }
        return (value >= 0 ? "+" : "") + value.smartFormatted
    }

    private func changeColor(_ change: Double?) -> Color {
        guard let change, abs(change) >= 0.005 else {
            return .secondaryText
        }
        return change > 0 ? .red : .green
    }
}
