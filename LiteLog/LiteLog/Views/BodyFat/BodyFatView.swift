import SwiftUI
import CoreData

struct BodyFatView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>

    @State private var showingAddSheet = false
    @State private var recordToEditData: RecordFormData?
    @State private var showingEditSheet = false
    @State private var cachedChartData: [(Date, Double)] = []
    @State private var cachedGroupedRecords: [Date: [WeightRecord]] = [:]

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var chartData: [(Date, Double)] {
        cachedChartData
    }

    private var bodyFatRecords: [WeightRecord] {
        records.filter { $0.bodyFatPercentageValue != nil }
    }

    private var groupedRecords: [Date: [WeightRecord]] {
        cachedGroupedRecords
    }
    
    private func computeCachedData() {
        let filtered = records.filter { $0.bodyFatPercentageValue != nil }
        let calendar = Calendar.current

        let chartGrouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }
        cachedChartData = chartGrouped.compactMap { key, values in
            if let record = values.max(by: { $0.date < $1.date }), let bodyFat = record.bodyFatPercentageValue {
                return (key, bodyFat)
            }
            return nil
        }
        .sorted { $0.0 < $1.0 }
        
        cachedGroupedRecords = Dictionary(grouping: bodyFatRecords) { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return Calendar.current.date(from: components) ?? record.date
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        ModernTrendChartView(data: chartData, color: .primaryBlue, unit: "%", title: NSLocalizedString("home.trend", comment: ""))

                        historySection
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                
                linksView
            }
            .navigationTitle(NSLocalizedString("home.body.fat", comment: ""))
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

            if bodyFatRecords.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: NSLocalizedString("home.no.records", comment: ""),
                    message: NSLocalizedString("home.start.record", comment: ""),
                    actionTitle: NSLocalizedString("record.add", comment: ""),
                    action: { showingAddSheet = true }
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { date in
                        Section {
                            ForEach(groupedRecords[date] ?? [], id: \.objectID) { record in
                                RecordRowView(record: record, unit: unit)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        recordToEditData = RecordFormData(
                                            id: record.id.uuidString,
                                            date: record.date,
                                            weightString: unit.convertFromKg(record.weight).smartFormatted,
                                            bodyFatString: record.bodyFatPercentageValue?.smartFormatted ?? "",
                                            waistString: record.waistCircumferenceValue?.smartFormatted ?? "",
                                            hipString: record.hipCircumferenceValue?.smartFormatted ?? "",
                                            chestString: record.chestCircumferenceValue?.smartFormatted ?? "",
                                            thighString: record.thighCircumferenceValue?.smartFormatted ?? "",
                                            note: record.note ?? "",
                                            imageUrl: record.imageUrl,
                                            measurementTimePeriod: record.measurementTimePeriod.flatMap { MeasurementTimePeriod(rawValue: $0) } ?? .random
                                        )
                                    }
                            }
                        } header: {
                            Text(date.monthYearString)
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                        }
                    }
                }
            }
        }
    }
}

