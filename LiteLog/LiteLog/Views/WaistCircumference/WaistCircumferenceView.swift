import SwiftUI
import SwiftData

struct WaistCircumferenceView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var showingAddSheet = false
    @State private var selectedRecord: WeightRecord?

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var chartData: [WaistCircumferenceChartView.ChartDataPoint] {
        let filtered = records.filter { $0.waistCircumference != nil }
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }

        return grouped.compactMap { key, values in
            if let record = values.max(by: { $0.date < $1.date }), let waist = record.waistCircumference {
                return WaistCircumferenceChartView.ChartDataPoint(date: key, waist: waist)
            }
            return nil
        }
        .sorted { $0.date < $1.date }
    }

    private var waistRecords: [WeightRecord] {
        records.filter { $0.waistCircumference != nil }
    }

    private var groupedRecords: [Date: [WeightRecord]] {
        Dictionary(grouping: waistRecords) { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return Calendar.current.date(from: components) ?? record.date
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WaistCircumferenceChartView(data: chartData)

                    historySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("home.waist.circumference", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .adaptiveSheet(isPresented: $showingAddSheet) {
                RecordFormView(isPresented: $showingAddSheet)
            }
            .adaptiveSheet(item: $selectedRecord) { record in
                RecordFormView(record: record, isPresented: .constant(false))
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
                            ForEach(groupedRecords[date] ?? [], id: \.id) { record in
                                RecordRowView(record: record, unit: unit)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecord = record
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
