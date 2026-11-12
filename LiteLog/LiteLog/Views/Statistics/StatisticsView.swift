import SwiftUI
import CoreData

struct StatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: true)])
    private var records: FetchedResults<WeightRecord>

    @State private var selectedPeriod: Period = .sevenDays
    @State private var selectedMetric: Metric = .weight
    @State private var selectedScope: MeasurementScope = .all
    @State private var showingProfileEditor = false

    private let filterOptionSpacing: CGFloat = 8
    private let filterOptionHorizontalPadding: CGFloat = 12
    private let filterOptionVerticalPadding: CGFloat = 6
    private let filterOptionCornerRadius: CGFloat = 8

    enum Period: Hashable {
        case sevenDays
        case weeks(Int)

        static let allOptions: [Period] = [.sevenDays] + (2...52).map(Period.weeks)

        var weekCount: Int {
            switch self {
            case .sevenDays:
                return 1
            case .weeks(let count):
                return count
            }
        }

        var localizedLabel: String {
            switch self {
            case .sevenDays:
                return NSLocalizedString("stats.7days", comment: "")
            case .weeks(let count):
                return String(
                    format: NSLocalizedString("stats.weeks.format", comment: ""),
                    count
                )
            }
        }
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
        let dayCount = selectedPeriod.weekCount * 7
        return calendar.date(byAdding: .day, value: -(dayCount - 1), to: rangeEndDate) ?? rangeEndDate
    }

    private var rangeEndDate: Date {
        Date().startOfDay
    }

    private var scopedRangeEntries: [TrendEntry] {
        scopedDailyEntries.filter {
            let day = $0.date.startOfDay
            return day >= rangeStartDate && day <= rangeEndDate
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
        }
    }

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: filterOptionSpacing) {
                ForEach(Period.allOptions, id: \.self) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        periodSegmentLabel(
                            title: period.localizedLabel,
                            isSelected: selectedPeriod == period
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func periodSegmentLabel(title: String, isSelected: Bool) -> some View {
        filterChipStyle(
            Text(title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false),
            isSelected: isSelected,
            accentColor: .primaryBlue
        )
    }

    private var metricPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("stats.metric", comment: ""))
                .font(.caption)
                .foregroundColor(.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: filterOptionSpacing) {
                    ForEach(Metric.allCases) { metric in
                        Button(action: { selectedMetric = metric }) {
                            filterChipStyle(
                                Text(NSLocalizedString(metric.localizedKey, comment: "")),
                                isSelected: selectedMetric == metric,
                                accentColor: metric.color
                            )
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
                HStack(spacing: filterOptionSpacing) {
                    ForEach(MeasurementScope.allCases) { scope in
                        Button(action: { selectedScope = scope }) {
                            filterChipStyle(
                                Text(NSLocalizedString(scope.localizedKey, comment: "")),
                                isSelected: selectedScope == scope,
                                accentColor: .primaryBlue
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        }
    }

    private func filterChipStyle<Content: View>(
        _ content: Content,
        isSelected: Bool,
        accentColor: Color
    ) -> some View {
        content
            .font(.caption.weight(isSelected ? .semibold : .medium))
            .padding(.horizontal, filterOptionHorizontalPadding)
            .padding(.vertical, filterOptionVerticalPadding)
            .background(isSelected ? accentColor.opacity(0.18) : chipBackground)
            .foregroundColor(isSelected ? accentColor : .secondaryText)
            .cornerRadius(filterOptionCornerRadius)
            .contentShape(Rectangle())
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
