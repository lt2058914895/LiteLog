import SwiftUI
import SwiftData

struct BodyFatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var showingAddSheet = false
    @State private var selectedRecord: WeightRecord?

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var chartData: [BodyFatChartView.ChartDataPoint] {
        let filtered = records.filter { $0.bodyFatPercentage != nil }
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }

        return grouped.compactMap { key, values in
            if let record = values.max(by: { $0.date < $1.date }), let bodyFat = record.bodyFatPercentage {
                return BodyFatChartView.ChartDataPoint(date: key, bodyFat: bodyFat)
            }
            return nil
        }
        .sorted { $0.date < $1.date }
    }

    private var bodyFatRecords: [WeightRecord] {
        records.filter { $0.bodyFatPercentage != nil }
    }

    private var groupedRecords: [Date: [WeightRecord]] {
        Dictionary(grouping: bodyFatRecords) { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return Calendar.current.date(from: components) ?? record.date
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BodyFatChartView(data: chartData)

                    historySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("home.body.fat", comment: ""))
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

