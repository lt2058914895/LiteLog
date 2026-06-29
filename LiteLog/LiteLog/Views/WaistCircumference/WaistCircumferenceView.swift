import SwiftUI
import CoreData

struct WaistCircumferenceView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>

    @State private var showingAddSheet = false
    @State private var recordToEditData: RecordFormData?
    @State private var showingEditSheet = false
    @State private var cachedChartData: [(Date, Double)] = []
    @State private var cachedGroupedRecords: [Date: [(record: WeightRecord, weightChange: Double?)]] = [:]

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var chartData: [(Date, Double)] {
        cachedChartData
    }

    private var waistRecords: [WeightRecord] {
        records.filter { $0.waistCircumferenceValue != nil }
    }

    private var groupedRecords: [Date: [(record: WeightRecord, weightChange: Double?)]] {
        cachedGroupedRecords
    }
    
    private func computeCachedData() {
        let filtered = records.filter { $0.waistCircumferenceValue != nil }
        let calendar = Calendar.current

        let chartGrouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }
        cachedChartData = chartGrouped.compactMap { key, values in
            if let record = values.max(by: { $0.date < $1.date }), let waist = record.waistCircumferenceValue {
                return (key, waist)
            }
            return nil
        }
        .sorted { $0.0 < $1.0 }
        
        let rawGrouped = Dictionary(grouping: waistRecords) { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return Calendar.current.date(from: components) ?? record.date
        }
        
        cachedGroupedRecords = rawGrouped.mapValues { records in
            records.enumerated().map { index, record in
                let weightChange = index < records.count - 1 ?
                    record.weight - records[index + 1].weight : nil
                return (record: record, weightChange: weightChange)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        ModernTrendChartView(data: chartData, color: .primaryBlue, unit: "cm", title: NSLocalizedString("home.trend", comment: ""))

                        historySection
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                
                linksView
            }
            .navigationTitle(NSLocalizedString("home.waist.circumference", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .onChange(of: recordToEditData) { newValue in
                if newValue != nil {
                    showingEditSheet = true
                }
            }
            .onAppear {
                computeCachedData()
            }
            .onChange(of: records.count) { _ in
                computeCachedData()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var linksView: some View {
        Group {
            NavigationLink(isActive: $showingAddSheet) {
                RecordFormView(isPresented: $showingAddSheet)
            } label: { EmptyView() }
            
            NavigationLink(isActive: $showingEditSheet) {
                if let data = recordToEditData {
                    RecordFormView(recordData: data, isPresented: $showingEditSheet)
                        .id(data.id)
                } else {
                    EmptyView()
                }
            } label: { EmptyView() }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("home.history", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)

            if waistRecords.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: NSLocalizedString("home.no.records", comment: ""),
                    message: NSLocalizedString("home.start.record", comment: ""),
                    actionTitle: NSLocalizedString("record.add", comment: ""),
                    action: { showingAddSheet = true }
                )
            } else {
                LazyVStack(spacing: 12) {
                    let sortedDates = groupedRecords.keys.sorted(by: >)
                    
                    ForEach(sortedDates, id: \.self) { date in
                        let monthRecords = groupedRecords[date] ?? []
                        Section {
                            ForEach(monthRecords, id: \.record.objectID) { item in
                                RecordRowView(record: item.record, unit: unit, weightChange: item.weightChange)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        recordToEditData = RecordFormData(
                                            id: item.record.id.uuidString,
                                            date: item.record.date,
                                            weightString: unit.convertFromKg(item.record.weight).smartFormatted,
                                            bodyFatString: item.record.bodyFatPercentageValue?.smartFormatted ?? "",
                                            waistString: item.record.waistCircumferenceValue?.smartFormatted ?? "",
                                            hipString: item.record.hipCircumferenceValue?.smartFormatted ?? "",
                                            chestString: item.record.chestCircumferenceValue?.smartFormatted ?? "",
                                            thighString: item.record.thighCircumferenceValue?.smartFormatted ?? "",
                                            note: item.record.note ?? "",
                                            imageUrl: item.record.imageUrl,
                                            measurementTimePeriod: item.record.measurementTimePeriod.flatMap { MeasurementTimePeriod(rawValue: $0) } ?? .random
                                        )
                                    }
                            }
                        } header: {
                            monthHeaderView(date, count: monthRecords.count)
                        }
                    }
                }
            }
        }
    }

    private func monthHeaderView(_ date: Date, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundColor(.primaryBlue)
            
            Text(date.monthYearString)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Spacer()
            
            Text("\(count) 条记录")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.primaryBlue.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
