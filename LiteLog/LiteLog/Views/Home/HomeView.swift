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
    @State private var selectedRecord: WeightRecord?
    @State private var showingEditSheet = false
    @State private var trendType: WeightChartView.TrendType = .week
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    private var todayRecords: [WeightRecord] {
        let today = Date().startOfDay
        return allRecords.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var latestWeight: Double? {
        allRecords.first?.weight
    }

    private var chartData: [WeightChartView.ChartDataPoint] {
        let calendar = Calendar.current
        let startDate: Date

        switch trendType {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .week:
            startDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .month:
            startDate = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        }

        return allRecords
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
            .map { WeightChartView.ChartDataPoint(date: $0.date, weight: $0.weight) }
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

                    WeightChartView(data: chartData, unit: unit, trendType: $trendType)

                    historySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("tab.home", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                QuickAddWeightView(isPresented: $showingAddSheet)
            }
            .sheet(isPresented: $showingEditSheet) {
                if let record = selectedRecord {
                    EditRecordView(record: record, isPresented: $showingEditSheet)
                }
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

                if !todayRecords.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(todayRecords.count) \(NSLocalizedString("home.today", comment: ""))")
                            .font(.caption)
                            .foregroundColor(.secondaryText)

                        if todayRecords.count > 1 {
                            let change = todayRecords.first!.weight - todayRecords.last!.weight
                            HStack(spacing: 2) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                Text("\(abs(unit.convertFromKg(change)).weightString)")
                                    .font(.caption)
                            }
                            .foregroundColor(change >= 0 ? .red : .green)
                        }
                    }
                }
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

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("home.history", comment: ""))
                    .font(.headline)
                    .foregroundColor(.primaryText)

                Spacer()

                NavigationLink(destination: RecordHistoryView()) {
                    Text(NSLocalizedString("action.done", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.primaryBlue)
                }
            }

            if allRecords.isEmpty {
                EmptyStateView(
                    icon: "scalemass",
                    title: NSLocalizedString("home.no.records", comment: ""),
                    message: NSLocalizedString("home.start.record", comment: "")
                )
            } else {
                RecordListView(
                    records: Array(allRecords.prefix(5)),
                    unit: unit,
                    onEdit: { record in
                        selectedRecord = record
                        showingEditSheet = true
                    },
                    onDelete: { record in
                        deleteRecord(record)
                    }
                )
            }
        }
    }

    private func deleteRecord(_ record: WeightRecord) {
        withAnimation {
            modelContext.delete(record)
        }
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
        guard let weightValue = Double(weightInput) else { return }

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

struct RecordHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    private var unit: WeightUnit { settingsManager.weightUnit }

    var body: some View {
        List {
            ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { date in
                Section(header: Text(date.mediumDateString)) {
                    ForEach(groupedRecords[date] ?? [], id: \.id) { record in
                        RecordRowView(record: record, unit: unit)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        deleteRecords(at: indexSet, for: date)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("home.history", comment: ""))
    }

    private var groupedRecords: [Date: [WeightRecord]] {
        Dictionary(grouping: records) { record in
            Calendar.current.startOfDay(for: record.date)
        }
    }

    private func deleteRecords(at offsets: IndexSet, for date: Date) {
        guard let recordsForDate = groupedRecords[date] else { return }
        for index in offsets {
            let record = recordsForDate[index]
            modelContext.delete(record)
        }
    }
}
