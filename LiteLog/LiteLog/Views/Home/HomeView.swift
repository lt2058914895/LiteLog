import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var healthKitManager = HealthKitManager.shared

    @Query(sort: \WeightRecord.date, order: .reverse) private var allRecords: [WeightRecord]
    @Query private var userProfile: [UserProfile]

    @State private var weightInput = ""
    @State private var showingAddSheet = false

    @State private var trendType: WeightChartView.TrendType = .week
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    private var latestWeight: Double? {
        allRecords.first?.weight
    }

    private var todayRecord: WeightRecord? {
        let today = Date().startOfDay
        return allRecords.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var latestBodyFatRecord: WeightRecord? {
        allRecords.first { $0.bodyFatPercentage != nil }
    }

    private var latestBodyFat: Double? {
        latestBodyFatRecord?.bodyFatPercentage
    }

    private var latestWaistRecord: WeightRecord? {
        allRecords.first { $0.waistCircumference != nil }
    }

    private var latestWaist: Double? {
        latestWaistRecord?.waistCircumference
    }

    private var bodyFatProgress: Double {
        guard let current = latestBodyFat else { return 0 }
        return min(current / 50.0 * 100, 100)
    }

    private var chartStartDate: Date {
        let calendar = Calendar.current
        switch trendType {
        case .week:
            return (calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()).startOfDay
        case .month:
            return (calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()).startOfDay
        case .quarter:
            return (calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()).startOfDay
        }
    }

    private var chartData: [WeightChartView.ChartDataPoint] {
        let filtered = allRecords.filter { $0.date >= chartStartDate }
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }

        return grouped.compactMap { $0.value.max(by: { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
            .map { WeightChartView.ChartDataPoint(date: $0.date.startOfDay, weight: $0.weight) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    todayWeightCard

                    if let latest = latestWeight, let profile = profile {
                        BMIProgressView(
                            currentWeight: latest,
                            goalWeight: profile.goalWeight,
                            height: profile.height,
                            unit: unit
                        )
                    }

                    HStack(spacing: 16) {
                        bodyFatCard
                            .frame(maxWidth: .infinity)
                        waistCard
                            .frame(maxWidth: .infinity)
                    }

                    WeightChartView(data: chartData, unit: unit, trendType: $trendType, startDate: chartStartDate)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("tab.home", comment: ""))
            .adaptiveSheet(isPresented: $showingAddSheet) {
                QuickAddWeightView(isPresented: $showingAddSheet)
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .refreshable {
                await syncFromHealthKit()
            }
        }
    }

    private var todayWeightCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("home.today", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)

                    if let latest = latestWeight {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(unit.convertFromKg(latest).weightString)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)

                            Text(unit.shortName)
                                .font(.title2)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text("-- \(unit.shortName)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                }

                Spacer()
            }

            Button(action: { showingAddSheet = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text(NSLocalizedString("home.add.weight", comment: ""))
                }
                .primaryButtonStyle()
            }
        }
        .padding()
        .cardStyle()
    }



    private var bodyFatCard: some View {
        NavigationLink(destination: BodyFatView()) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Text(NSLocalizedString("home.body.fat", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.tertiaryText)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let bodyFat = latestBodyFat {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", bodyFat))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)

                            Text("%")
                                .font(.title)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text("-- %")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var waistCard: some View {
        NavigationLink(destination: WaistCircumferenceView()) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Text(NSLocalizedString("home.waist.circumference", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.tertiaryText)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let waist = latestWaist {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", waist))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)

                            Text("cm")
                                .font(.title)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text("-- cm")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func syncFromHealthKit() async {
        guard settingsManager.healthKitEnabled else { return }

        do {
            try await healthKitManager.requestAuthorization()
            let startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            let healthData = try await healthKitManager.fetchWeightData(from: startDate)

            for dataPoint in healthData {
                let existingRecord = allRecords.first { record in
                    Calendar.current.isDate(record.date, inSameDayAs: dataPoint.date)
                }

                if existingRecord == nil {
                    let newRecord = WeightRecord(
                        date: dataPoint.date,
                        weight: dataPoint.weightInKg
                    )
                    modelContext.insert(newRecord)
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct QuickAddWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    @Binding var isPresented: Bool

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var weightInput = ""
    @FocusState private var isKeyboardFocused: Bool
    @State private var showingDuplicateAlert = false

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var isValidWeight: Bool {
        guard let value = Double(weightInput) else { return false }
        return value > 0 && value < 500
    }

    private var todayHasRecord: Bool {
        let today = Date().startOfDay
        return records.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                displayView

                NumericKeyboardView(value: $weightInput, unit: unit) {
                    saveWeight()
                }

                Spacer()

                saveButton
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("home.add.weight", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        isPresented = false
                    }
                }
            }
            .alert(NSLocalizedString("record.duplicate.title", comment: ""), isPresented: $showingDuplicateAlert) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.confirm", comment: "")) {
                    confirmSaveWeight()
                }
            } message: {
                Text(NSLocalizedString("record.duplicate.message", comment: ""))
            }
        }
    }

    private var displayView: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("home.weight", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(weightInput.isEmpty ? "0" : weightInput)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(unit.shortName)
                    .font(.title)
                    .foregroundColor(.secondaryText)
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveWeight) {
            Text(NSLocalizedString("action.save", comment: ""))
                .primaryButtonStyle()
        }
        .disabled(!isValidWeight)
        .opacity(isValidWeight ? 1.0 : 0.5)
    }

    private func saveWeight() {
        guard Double(weightInput) != nil else { return }

        if todayHasRecord {
            showingDuplicateAlert = true
            return
        }

        confirmSaveWeight()
    }

    private func confirmSaveWeight() {
        guard let weightValue = Double(weightInput) else { return }

        let weightInKg = unit.convertToKg(weightValue)

        if todayHasRecord {
            deleteTodayRecords()
        }

        let record = WeightRecord(date: Date(), weight: weightInKg)

        modelContext.insert(record)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save weight: \(error)")
            return
        }

        if settingsManager.healthKitEnabled {
            Task {
                try? await HealthKitManager.shared.saveWeight(weightInKg: weightInKg, date: Date())
            }
        }

        isPresented = false
    }

    private func deleteTodayRecords() {
        let today = Date().startOfDay
        let todayRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        for record in todayRecords {
            modelContext.delete(record)
        }
    }
}
