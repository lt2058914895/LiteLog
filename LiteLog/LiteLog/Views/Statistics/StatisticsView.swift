import SwiftUI
import CoreData

struct WeightData: Identifiable {
    let id: UUID
    let date: Date
    let weight: Double
    let bodyFatPercentage: Double?
    let waistCircumference: Double?
    let hipCircumference: Double?
    let chestCircumference: Double?
    let thighCircumference: Double?
}

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: true)]) private var records: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.id, ascending: true)]) private var userProfile: FetchedResults<UserProfile>

    @State private var selectedPeriod: Period = .week
    @State private var selectedMetric: Metric = .weight
    @State private var cachedFilteredRecords: [WeightData] = []
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showYearPicker: Bool = false
    @State private var showingProfileEditor = false
    
    private let minYear = 2000
    private let maxYear = Calendar.current.component(.year, from: Date())

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }
    private var displayName: String {
        !settingsManager.nickname.isEmpty ? settingsManager.nickname : NSLocalizedString("tab.statistics", comment: "")
    }

    enum Period: String, CaseIterable {
        case week = "stats.week"
        case month = "stats.month"
        case quarter = "stats.quarter"
        case year = "stats.year"

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
        case .year:
            var components = DateComponents()
            components.year = selectedYear
            components.month = 1
            components.day = 1
            return calendar.date(from: components) ?? Date()
        }
    }

    private var endDate: Date {
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

    private var filteredRecords: [WeightData] {
        cachedFilteredRecords
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
    
    private func computeFilteredRecords() {
        let filtered = records.filter { $0.date >= startDate && $0.date <= endDate }
        let calendar = Calendar.current
        
        if selectedPeriod == .year {
            let grouped = Dictionary(grouping: filtered) { record in
                record.date.startOfWeek
            }
            
            cachedFilteredRecords = grouped.compactMap { weekStart, weekRecords in
                let avgWeight = weekRecords.reduce(0) { $0 + $1.weight } / Double(weekRecords.count)
                let representativeRecord = weekRecords.max(by: { $0.date < $1.date })!
                return WeightData(
                    id: representativeRecord.id,
                    date: weekStart,
                    weight: avgWeight,
                    bodyFatPercentage: weekRecords.compactMap { $0.bodyFatPercentage }.average ?? 0,
                    waistCircumference: weekRecords.compactMap { $0.waistCircumference }.average ?? 0,
                    hipCircumference: weekRecords.compactMap { $0.hipCircumference }.average ?? 0,
                    chestCircumference: weekRecords.compactMap { $0.chestCircumference }.average ?? 0,
                    thighCircumference: weekRecords.compactMap { $0.thighCircumference }.average ?? 0
                )
            }
            .sorted { $0.date < $1.date }
        } else {
            let grouped = Dictionary(grouping: filtered) { record in
                calendar.startOfDay(for: record.date)
            }
            
            cachedFilteredRecords = grouped.compactMap { $0.value.max(by: { $0.date < $1.date }) }
                .map { record in
                    WeightData(
                        id: record.id,
                        date: record.date,
                        weight: record.weight,
                        bodyFatPercentage: record.bodyFatPercentage,
                        waistCircumference: record.waistCircumference,
                        hipCircumference: record.hipCircumference,
                        chestCircumference: record.chestCircumference,
                        thighCircumference: record.thighCircumference
                    )
                }
                .sorted { $0.date < $1.date }
        }
    }
    
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
            if let value = value, value > 0 {
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
        NavigationStack {
            VStack(spacing: 0) {
                // 固定在顶部的周月季度选择器
                periodPicker
                    .padding()
                
                // 可滚动的内容区域（包含指标选择器）
                ScrollView {
                    VStack(spacing: 20) {
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
            }
            .background(Color(.systemGroupedBackground))
            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 900 : 800, alignment: .center)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingProfileEditor = true
                    }) {
                        HStack(spacing: 12) {
                            avatarImageView
                            Text(displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingProfileEditor) {
                UserInfoEditorView()
            }
            .onAppear {
                computeFilteredRecords()
            }
            .onChange(of: selectedPeriod) { newValue in
                if newValue != .year {
                    selectedYear = maxYear
                }
                computeFilteredRecords()
            }
            .onChange(of: selectedYear) { _ in
                computeFilteredRecords()
            }
            .onChange(of: records.count) { _ in
                computeFilteredRecords()
            }
            .sheet(isPresented: $showYearPicker) {
                yearPickerSheet
            }
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
        VStack(spacing: 12) {
            Picker("Period", selection: $selectedPeriod) {
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
            Button(action: {
                selectedYear -= 1
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(selectedYear <= minYear ? .gray : .primaryBlue)
                    .frame(width: 32, height: 32)
                    .background(selectedYear <= minYear ? Color.gray.opacity(0.1) : Color.primaryBlue.opacity(0.1))
                    .cornerRadius(8)
            }
            .disabled(selectedYear <= minYear)
            
            Button(action: {
                showYearPicker = true
            }) {
                Text("\(selectedYear)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity)
            }
            
            Button(action: {
                selectedYear += 1
            }) {
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
            
            LazyHStack(spacing: 8) {
                ForEach(Metric.allCases) { metric in
                    Button(action: { selectedMetric = metric }) {
                        Text(NSLocalizedString(metric.localizedKey, comment: ""))
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedMetric == metric ? selectedMetric.color.opacity(0.2) : (colorScheme == .dark ? Color(.secondarySystemBackground) : .white))
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
                ModernTrendChartView(
                    data: currentMetricData,
                    color: selectedMetric.color,
                    unit: selectedMetric.unit,
                    title: "",
                    period: selectedPeriod
                )
            }
        }
    }

    private var bmiChartSection: some View {
        Group {
            if let profile = profile {
                if filteredRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("stats.bmi.trend", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Text(NSLocalizedString("stats.no.data", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .cardStyle()
                } else {
                    let bmiData = filteredRecords.compactMap { record -> (Date, Double)? in
                        guard profile.height > 0 else {
                            return nil
                        }
                        return (record.date.startOfDay, profile.calculateBMI(weight: record.weight))
                    }
                    
                    if bmiData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("stats.bmi.trend", comment: ""))
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            Text(NSLocalizedString("stats.bmi.no.data", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .cardStyle()
                    } else {
                        BMITrendChartView(data: bmiData)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("stats.bmi.trend", comment: ""))
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
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
                .padding()
                .cardStyle()
            }
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
