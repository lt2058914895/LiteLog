import SwiftUI
import CoreData

struct RecordView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.id, ascending: true)]) private var userProfile: FetchedResults<UserProfile>

    @State private var selectedDate: Date?
    @State private var recordToEditData: RecordFormData?
    @State private var viewMode: ViewMode = .list
    @State private var isPresentingAddSheet = false
    @State private var isPresentingEditSheet = false
    
    @StateObject private var viewModel: RecordViewModel

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { viewModel.unit }
    private var displayName: String {
        !settingsManager.nickname.isEmpty ? settingsManager.nickname : NSLocalizedString("tab.record", comment: "")
    }
    
    init() {
        self._viewModel = StateObject(wrappedValue: RecordViewModel(
            context: PersistenceController.shared.viewContext,
            settingsManager: SettingsManager.shared
        ))
    }

    enum ViewMode: String, CaseIterable {
        case list = "home.history"
        case calendar = "record.calendar"

        var localizedKey: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                viewModePicker

                switch viewMode {
                case .list:
                    listView
                case .calendar:
                    calendarView
                }
            }
            .background(Color(.systemGroupedBackground))
            .frame(maxWidth: 600, alignment: .center)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        avatarImageView
                        Text(displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .navigationDestination(isPresented: $isPresentingAddSheet) {
                RecordFormView(isPresented: $isPresentingAddSheet, onSave: {
                    viewModel.forceRefresh()
                })
            }
            .navigationDestination(isPresented: $isPresentingEditSheet) {
                if let data = recordToEditData {
                    RecordFormView(recordData: data, isPresented: $isPresentingEditSheet, onSave: {
                        viewModel.forceRefresh()
                        recordToEditData = nil
                    })
                        .id(data.id)
                } else {
                    EmptyView()
                }
            }
            .onChange(of: recordToEditData) { newValue in
                if newValue != nil {
                    isPresentingEditSheet = true
                }
            }
            .onChange(of: isPresentingEditSheet) { newValue in
                if !newValue {
                    recordToEditData = nil
                    viewModel.forceRefresh()
                }
            }
            .onAppear {
                viewModel.refresh()
            }
        }
    }

    private var viewModePicker: some View {
        Picker(NSLocalizedString("view.mode", comment: ""), selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(NSLocalizedString(mode.localizedKey, comment: ""))
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    private var listView: some View {
        Group {
            if viewModel.records.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: NSLocalizedString("home.no.records", comment: ""),
                    message: NSLocalizedString("home.start.record", comment: ""),
                    actionTitle: NSLocalizedString("record.add", comment: ""),
                    action: { isPresentingAddSheet = true }
                )
            } else {
                List {
                    ForEach(viewModel.sortedGroupedRecords, id: \.0) { date, monthRecords in
                        Section(header: monthHeaderView(date, count: monthRecords.count)) {
                            ForEach(monthRecords, id: \.record.objectID) { item in
                                RecordRowView(record: item.record, unit: unit, weightChange: item.weightChange)
                                    .id("\(item.record.objectID)-\(item.record.updatedAt.timeIntervalSince1970)")
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.bottom, 12)
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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteRecord(item.record)
                                        } label: {
                                            Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var calendarView: some View {
        ScrollView {
            VStack(spacing: 20) {
                CalendarView(
                    records: viewModel.records,
                    unit: unit,
                    selectedDate: $selectedDate,
                    onDateSelected: { _ in }
                )

                if let date = selectedDate {
                    selectedDateRecordsView(date)
                }
            }
            .padding()
        }
    }

    private func selectedDateRecordsView(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date.mediumDateString)
                .font(.headline)
                .foregroundColor(.primaryText)

            let dayRecordsArray = viewModel.records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            let dayRecordsWithChange = dayRecordsArray.computeWeightChanges()

            if dayRecordsWithChange.isEmpty {
                Text(NSLocalizedString("home.no.records", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(dayRecordsWithChange, id: \.record.objectID) { item in
                    RecordRowView(record: item.record, unit: unit, weightChange: item.weightChange)
                        .id("\(item.record.objectID)-\(item.record.updatedAt.timeIntervalSince1970)")
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecord(item.record)
                            } label: {
                                Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
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

    private func deleteRecord(_ record: WeightRecord) {
        let recordId = record.id.uuidString
        withAnimation {
            context.delete(record)
            try? context.save()
        }
        
        viewModel.refresh()
        
        Task {
            await DataSyncManager.shared.syncDeletedRecords(recordIds: [recordId])
        }
    }
    
    @ViewBuilder
    private var avatarImageView: some View {
        if !settingsManager.avatarUrl.isEmpty {
            if let cachedImage = settingsManager.cachedAvatarImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else if let avatarUrl = resolveAvatarUrl() {
                AsyncImageView(
                    url: avatarUrl,
                    placeholder: { AnyView(Image(systemName: "person.circle.fill").resizable().foregroundColor(.primaryBlue)) },
                    errorPlaceholder: { AnyView(Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)) },
                    contentMode: .fill,
                    cacheKey: settingsManager.avatarUrl
                )
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.gray)
            }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(.gray)
        }
    }
    
    private func resolveAvatarUrl() -> URL? {
        let avatarUrlString = settingsManager.avatarUrl
        guard !avatarUrlString.isEmpty else { return nil }
        
        if let url = URL(string: avatarUrlString), url.scheme != nil {
            return url
        }
        
        return APIService.shared.baseURL.appendingPathComponent(avatarUrlString)
    }
}
