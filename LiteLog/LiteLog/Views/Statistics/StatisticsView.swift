import SwiftUI
import CoreData

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: true)]) private var records: FetchedResults<WeightRecord>
    @FetchRequest private var userProfile: FetchedResults<UserProfile>
    
    init() {
        _userProfile = FetchRequest(fetchRequest: UserProfile.fetchRequest())
    }

    @State private var selectedPeriod: Period = .week
    @State private var selectedMetric: Metric = .weight

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    enum Period: String, CaseIterable {
        case week = "stats.week"
        case month = "stats.month"
        case quarter = "stats.quarter"

        var localizedKey: String { rawValue }
    }

    enum Metric: String, CaseIterable, Identifiable {
        case weight = "stats.metric.weight"
        case bodyFat = "stats.metric.body.fat"
        case waist = "stats.metric.waist"
        case hip = "stats.metric.hip"
        case chest = "stats.metric.chest"
        case thigh = "stats.metric.thigh"

        var id: String { rawValue }
        var localizedKey: String { rawValue }
        var unit: String {
            switch self {
            case .weight: return "kg"
            case .bodyFat: return "%"
            case .waist, .hip, .chest, .thigh: return "cm"
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
    }

    private var startDate: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .week:
            return (calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()).startOfDay
        case .month:
            return (calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()).startOfDay
        case .quarter:
            return (calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()).startOfDay
        }
    }

    private var filteredRecords: [WeightRecord] {
        let filtered = records.filter { $0.date >= startDate }
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }
        
        return grouped.compactMap { $0.value.max(by: { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }

    private var averageWeight: Double {
        guard !filteredRecords.isEmpty else { return 0 }
        let sum = filteredRecords.reduce(0) { $0 + $1.weight }
        return sum / Double(filteredRecords.count)
    }

    private var weightChange: Double {
        guard filteredRecords.count >= 2 else { return 0 }
        let first = filteredRecords.first!.weight
        let last = filteredRecords.last!.weight
        return last - first
    }

    private var weightChangeRate: Double {
        guard filteredRecords.count >= 2, let firstRecord = filteredRecords.first else { return 0 }
        let daysDiff = max(Calendar.current.dateComponents([.day], from: firstRecord.date, to: Date()).day ?? 1, 1)
        let weeks = Double(daysDiff) / 7.0
        guard weeks > 0 else { return 0 }
        return weightChange / weeks
    }

    private var minWeight: Double {
        filteredRecords.map { $0.weight }.min() ?? 0
    }

    private var maxWeight: Double {
        filteredRecords.map { $0.weight }.max() ?? 0
    }

    // MARK: - Metric Data
    
    private func metricData(for metric: Metric) -> [(Date, Double)] {
        filteredRecords.compactMap { record in
            let value: Double?
            switch metric {
            case .weight:
                value = record.weight
            case .bodyFat:
                value = record.bodyFatPercentage
            case .waist:
                value = record.waistCircumference
            case .hip:
                value = record.hipCircumference
            case .chest:
                value = record.chestCircumference
            case .thigh:
                value = record.thighCircumference
            }
            if let value = value {
                return (record.date.startOfDay, value)
            }
            return nil
        }
    }

    private var currentMetricData: [(Date, Double)] {
        metricData(for: selectedMetric)
    }

    private var currentMetricAverage: Double {
        guard !currentMetricData.isEmpty else { return 0 }
        let sum = currentMetricData.reduce(0) { $0 + $1.1 }
        return sum / Double(currentMetricData.count)
    }

    private var currentMetricChange: Double {
        guard currentMetricData.count >= 2 else { return 0 }
        let first = currentMetricData.first!.1
        let last = currentMetricData.last!.1
        return last - first
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    
                    metricPicker

                    if records.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar",
                            title: NSLocalizedString("stats.no.data", comment: ""),
                            message: NSLocalizedString("home.start.record", comment: "")
                        )
                    } else {
                        metricSummaryCards

                        metricChart

                        bmiChartSection

                        statsDetails
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        avatarImageView
                        Text(NSLocalizedString("stats.title", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private var avatarImageView: some View {
        if !settingsManager.avatarUrl.isEmpty {
            if let cachedImage = settingsManager.cachedAvatarImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .id(settingsManager.avatarCacheUpdated)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.primaryBlue)
            }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(.gray)
        }
    }
    
    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(NSLocalizedString(period.localizedKey, comment: ""))
                    .tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var metricPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("stats.metric", comment: ""))
                .font(.caption)
                .foregroundColor(.secondaryText)
            
            LazyHStack(spacing: 8) {
                ForEach(Metric.allCases) { metric in
                    Button(action: { selectedMetric = metric }) {
                        Text(NSLocalizedString(metric.localizedKey, comment: ""))
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedMetric == metric ? selectedMetric.color.opacity(0.2) : Color.cardBackground)
                            .foregroundColor(selectedMetric == metric ? selectedMetric.color : .secondaryText)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var metricSummaryCards: some View {
        HStack(spacing: 12) {
            MetricSummaryCard(
                title: NSLocalizedString("stats.average", comment: ""),
                value: currentMetricAverage.smartFormatted,
                unit: selectedMetric.unit,
                color: selectedMetric.color
            )

            MetricSummaryCard(
                title: NSLocalizedString("stats.change", comment: ""),
                value: (currentMetricChange >= 0 ? "+" : "") + currentMetricChange.smartFormatted,
                unit: selectedMetric.unit,
                color: currentMetricChange >= 0 ? .red : .green
            )
        }
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
            }

            if currentMetricData.isEmpty {
                Text(NSLocalizedString("stats.no.data", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .cardStyle()
            } else {
                TrendChartView(
                    data: currentMetricData,
                    color: selectedMetric.color,
                    unit: selectedMetric.unit,
                    title: ""
                )
            }
        }
    }

    private var bmiChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("stats.bmi.trend", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)

            if let profile = profile {
                if filteredRecords.isEmpty {
                    Text(NSLocalizedString("stats.no.data", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                } else {
                    let bmiData = filteredRecords.map { record -> (Date, Double) in
                        (record.date.startOfDay, profile.calculateBMI(weight: record.weight))
                    }

                    VStack(spacing: 12) {
                        GeometryReader { geometry in
                            ZStack {
                                if bmiData.count > 1 {
                                    let points = calculateBMIPoints(data: bmiData, in: geometry.size)
                                    
                                    Path { path in
                                        path.move(to: points[0])
                                        for i in 1..<points.count {
                                            path.addLine(to: points[i])
                                        }
                                    }
                                    .stroke(Color.green, lineWidth: 2)

                                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                                        Circle()
                                            .fill(bmiCategoryColor(bmiData[index].1))
                                            .frame(width: 6, height: 6)
                                            .position(point)
                                    }
                                } else if let point = bmiData.first {
                                    Text(String(format: "%.1f", point.1))
                                        .font(.title)
                                        .foregroundColor(bmiCategoryColor(point.1))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                        .frame(height: 150)
                        
                        bmiLegend
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("stats.bmi.no.profile", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Button(NSLocalizedString("action.edit", comment: "")) {
                        NotificationCenter.default.post(name: .showProfileEditor, object: nil)
                    }
                    .foregroundColor(.primaryBlue)
                    .font(.subheadline)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .cardStyle()
    }
    
    private func calculateBMIPoints(data: [(Date, Double)], in size: CGSize) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        let width = size.width
        let height = size.height
        let padding: CGFloat = 20
        let minBMI: Double = 15
        let maxBMI: Double = 35
        
        return data.enumerated().map { index, point in
            let x = padding + CGFloat(index) * (width - 2 * padding) / CGFloat(max(data.count - 1, 1))
            let normalizedY = (point.1 - minBMI) / (maxBMI - minBMI)
            let clampedY = max(0, min(normalizedY, 1))
            let y = height - padding - clampedY * (height - 2 * padding)
            return CGPoint(x: x, y: y)
        }
    }

    private func bmiCategoryColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<24: return .green
        case 24..<28: return .orange
        default: return .red
        }
    }

    private var bmiLegend: some View {
        HStack(spacing: 16) {
            legendItem(color: .blue, label: NSLocalizedString("bmi.category.underweight", comment: ""))
            legendItem(color: .green, label: NSLocalizedString("bmi.category.normal", comment: ""))
            legendItem(color: .orange, label: NSLocalizedString("bmi.category.overweight", comment: ""))
            legendItem(color: .red, label: NSLocalizedString("bmi.category.obese", comment: ""))
        }
        .font(.caption2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondaryText)
        }
    }

    private var statsDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("stats.loss.speed", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)

            VStack(spacing: 16) {
                HStack {
                    Text(NSLocalizedString("stats.loss.speed", comment: ""))
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Text("\(unit.convertFromKg(weightChangeRate).smartFormatted) \(NSLocalizedString("stats.per.week", comment: ""))")
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                }

                Divider()

                HStack {
                    Text("Min")
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Text("\(unit.convertFromKg(minWeight).smartFormatted) \(unit.shortName)")
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                }

                Divider()

                HStack {
                    Text("Max")
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Text("\(unit.convertFromKg(maxWeight).smartFormatted) \(unit.shortName)")
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                }

                Divider()

                HStack {
                    Text(NSLocalizedString("settings.goal.weight", comment: ""))
                        .foregroundColor(.secondaryText)

                    Spacer()

                    if let profile = profile {
                        Text("\(unit.convertFromKg(profile.goalWeight).smartFormatted) \(unit.shortName)")
                            .fontWeight(.medium)
                            .foregroundColor(.primaryText)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    var color: Color = .primaryBlue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

struct MetricSummaryCard: View {
    let title: String
    let value: String
    let unit: String
    var color: Color = .primaryBlue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}
