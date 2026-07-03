import SwiftUI
import CoreData

struct BodyFatView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager

    @State private var isPresentingAddSheet = false
    @State private var recordToEditData: RecordFormData?
    @State private var isPresentingEditSheet = false
    
    @StateObject private var viewModel: RecordViewModel

    private var unit: WeightUnit { viewModel.unit }
    
    private var chartData: [(Date, Double)] {
        let filtered = viewModel.records.filter { $0.bodyFatPercentageValue != nil }
        let calendar = Calendar.current
        
        let chartGrouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }
        
        return chartGrouped.compactMap { key, values in
            if let record = values.max(by: { $0.date < $1.date }), let bodyFat = record.bodyFatPercentageValue {
                return (key, bodyFat)
            }
            return nil
        }
        .sorted { $0.0 < $1.0 }
    }
    
    private var bodyFatRecords: [WeightRecord] {
        viewModel.records.filter { $0.bodyFatPercentageValue != nil }
    }
    
    init() {
        self._viewModel = StateObject(wrappedValue: RecordViewModel(
            context: PersistenceController.shared.viewContext,
            settingsManager: SettingsManager.shared
        ))
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
                    Button(action: { isPresentingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .onChange(of: recordToEditData) { newValue in
                if newValue != nil {
                    isPresentingEditSheet = true
                }
            }
            .onAppear {
                viewModel.refresh()
            }
        }
        .adaptiveNavigationViewStyle()
        
    }
    
    private var linksView: some View {
        Group {
            NavigationLink(isActive: $isPresentingAddSheet) {
                RecordFormView(isPresented: $isPresentingAddSheet)
            } label: { EmptyView() }
            
            NavigationLink(isActive: $isPresentingEditSheet) {
                if let data = recordToEditData {
                    RecordFormView(recordData: data, isPresented: $isPresentingEditSheet)
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
                    action: { isPresentingAddSheet = true }
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sortedFilteredBodyFatRecords, id: \.0) { date, monthRecords in
                        Section {
                            ForEach(monthRecords, id: \.record.objectID) { item in
                                EquatableView(content: RecordRowView(record: item.record, unit: unit, weightChange: item.weightChange))
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

