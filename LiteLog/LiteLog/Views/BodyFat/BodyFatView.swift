import SwiftUI
import SwiftData

struct BodyFatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var showingAddSheet = false
    @State private var selectedRecord: WeightRecord?

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
            .sheet(isPresented: $showingAddSheet) {
                let today = Date().startOfDay
                let todayRecord = records.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
                RecordFormView(record: todayRecord, isPresented: $showingAddSheet)
            }
            .sheet(item: $selectedRecord) { record in
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
                LazyVStack(spacing: 12) {
                    ForEach(bodyFatRecords, id: \.id) { record in
                        BodyFatRowView(record: record)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecord = record
                            }
                    }
                }
            }
        }
    }
}

struct BodyFatRowView: View {
    let record: WeightRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.date.formatted(date: .omitted, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                if let bodyFat = record.bodyFatPercentage {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", bodyFat))
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)

                        Text("%")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                } else {
                    Text("-- %")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundColor(.tertiaryText)
        }
        .padding()
        .cardStyle()
    }
}
