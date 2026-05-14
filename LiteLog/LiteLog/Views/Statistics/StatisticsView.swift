import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .forward) private var records: [WeightRecord]
    @Query private var userProfile: [UserProfile]

    @State private var selectedPeriod: Period = .week

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    enum Period: String, CaseIterable {
        case week = "stats.week"
        case month = "stats.month"
        case quarter = "stats.quarter"

        var localizedKey: String { rawValue }
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker

                    if records.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar",
                            title: NSLocalizedString("stats.no.data", comment: ""),
                            message: NSLocalizedString("home.start.record", comment: "")
                        )
                    } else {
                        summaryCards

                        weightChart

                        if let profile = profile {
                            bmiChart(for: profile)
                        }

                        statsDetails
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("stats.title", comment: ""))
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

    private var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: NSLocalizedString("stats.average", comment: ""),
                value: unit.convertFromKg(averageWeight).weightString,
                unit: unit.shortName,
                icon: "scalemass"
            )

            SummaryCard(
                title: NSLocalizedString("stats.change", comment: ""),
                value: (weightChange >= 0 ? "+" : "") + unit.convertFromKg(weightChange).weightString,
                unit: unit.shortName,
                icon: weightChange >= 0 ? "arrow.up.right" : "arrow.down.right",
                color: weightChange >= 0 ? .red : .green
            )
        }
    }

    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("home.trend", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)

            if filteredRecords.isEmpty {
                Text(NSLocalizedString("stats.no.data", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(filteredRecords) { record in
                    LineMark(
                        x: .value("Date", record.date.startOfDay),
                        y: .value("Weight", unit.convertFromKg(record.weight))
                    )
                    .foregroundStyle(Color.primaryBlue)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", record.date.startOfDay),
                        y: .value("Weight", unit.convertFromKg(record.weight))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primaryBlue.opacity(0.3), Color.primaryBlue.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", record.date.startOfDay),
                        y: .value("Weight", unit.convertFromKg(record.weight))
                    )
                    .foregroundStyle(Color.primaryBlue)
                    .symbolSize(30)
                }
                .chartXScale(domain: startDate...Date().startOfDay)
                .chartXAxis {
                    AxisMarks(values: [startDate, Date().startOfDay]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.shortDateString)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .cardStyle()
    }

    private func bmiChart(for profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("stats.bmi.trend", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)

            let bmiData = filteredRecords.map { record -> (Date, Double) in
                (record.date.startOfDay, profile.calculateBMI(weight: record.weight))
            }

            if bmiData.isEmpty {
                Text(NSLocalizedString("stats.no.data", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(bmiData, id: \.0) { item in
                    LineMark(
                        x: .value("Date", item.0),
                        y: .value("BMI", item.1)
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", item.0),
                        y: .value("BMI", item.1)
                    )
                    .foregroundStyle(bmiCategoryColor(item.1))
                    .symbolSize(30)
                }
                .chartYScale(domain: 15...35)
                .chartXScale(domain: startDate...Date().startOfDay)
                .chartXAxis {
                    AxisMarks(values: [startDate, Date().startOfDay]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.shortDateString)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 150)

                bmiLegend
            }
        }
        .padding()
        .cardStyle()
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

                    Text("\(unit.convertFromKg(weightChangeRate).weightString) \(NSLocalizedString("stats.per.week", comment: ""))")
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                }

                Divider()

                HStack {
                    Text("Min")
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Text("\(unit.convertFromKg(minWeight).weightString) \(unit.shortName)")
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                }

                Divider()

                HStack {
                    Text("Max")
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Text("\(unit.convertFromKg(maxWeight).weightString) \(unit.shortName)")
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                }

                Divider()

                HStack {
                    Text(NSLocalizedString("settings.goal.weight", comment: ""))
                        .foregroundColor(.secondaryText)

                    Spacer()

                    if let profile = profile {
                        Text("\(unit.convertFromKg(profile.goalWeight).weightString) \(unit.shortName)")
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
