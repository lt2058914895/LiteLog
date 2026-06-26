import SwiftUI
import CoreData

struct WaistCircumferenceView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>

    @State private var showingAddSheet = false
    @State private var recordToEditData: RecordFormData?
    @State private var showingEditSheet = false

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var chartData: [(Date, Double)] {
        let filtered = records.filter { $0.waistCircumferenceValue != nil }
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }

        return grouped.compactMap { key, values in
            if let record = values.max(by: { $0.date < $1.date }), let waist = record.waistCircumferenceValue {
                return (key, waist)
            }
            return nil
        }
        .sorted { $0.0 < $1.0 }
    }

    private var waistRecords: [WeightRecord] {
        records.filter { $0.waistCircumferenceValue != nil }
    }

    private var groupedRecords: [Date: [WeightRecord]] {
        Dictionary(grouping: waistRecords) { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return Calendar.current.date(from: components) ?? record.date
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ModernTrendChartView(data: chartData, color: .primaryBlue, unit: "cm", title: NSLocalizedString("home.trend", comment: ""))

                    historySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
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
            .fullScreenCover(isPresented: $showingAddSheet) {
                RecordFormView(isPresented: $showingAddSheet)
            }
            .fullScreenCover(isPresented: $showingEditSheet) {
                if let data = recordToEditData {
                    RecordFormView(recordData: data, isPresented: $showingEditSheet)
                        .id(data.id)
                }
            }
            .onChange(of: recordToEditData) { newValue in
                if newValue != nil {
                    showingEditSheet = true
                }
            }
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
