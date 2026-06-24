import SwiftUI
import CoreData

struct RecordView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>

    @State private var selectedDate: Date?
    @State private var showingAddSheet = false
    @State private var selectedRecord: WeightRecord?
    @State private var viewMode: ViewMode = .list

    @FetchRequest private var userProfile: FetchedResults<UserProfile>
    
    init() {
        _userProfile = FetchRequest(fetchRequest: UserProfile.fetchRequest())
    }

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    enum ViewMode: String, CaseIterable {
        case list = "home.history"
        case calendar = "record.calendar"

        var localizedKey: String { rawValue }
    }

    var body: some View {
        NavigationView {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        avatarImageView
                        Text(NSLocalizedString("tab.record", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
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
            if records.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: NSLocalizedString("home.no.records", comment: ""),
                    message: NSLocalizedString("home.start.record", comment: ""),
                    actionTitle: NSLocalizedString("record.add", comment: ""),
                    action: { showingAddSheet = true }
                )
            } else {
                List {
                    ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { date in
                        Section(header: Text(date.monthYearString)) {
                            ForEach(groupedRecords[date] ?? [], id: \.id) { record in
                                RecordRowView(record: record, unit: unit)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.bottom, 8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecord = record
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteRecord(record)
                                        } label: {
                                            Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            selectedRecord = record
                                        } label: {
                                            Label(NSLocalizedString("action.edit", comment: ""), systemImage: "pencil")
                                        }
                                        .tint(.primaryBlue)
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
                    records: Array(records),
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

            let dayRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }

            if dayRecords.isEmpty {
                Text(NSLocalizedString("home.no.records", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(dayRecords, id: \.id) { record in
                    RecordRowView(record: record, unit: unit)
                        .onTapGesture {
                            selectedRecord = record
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecord(record)
                            } label: {
                                Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var groupedRecords: [Date: [WeightRecord]] {
        Dictionary(grouping: records) { record in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: record.date)
            return calendar.date(from: components) ?? record.date
        }
    }

    private func deleteRecord(_ record: WeightRecord) {
        let recordId = record.id.uuidString
        withAnimation {
            context.delete(record)
            try? context.save()
        }
        
        // 同步删除到云数据库
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
                    .id(settingsManager.avatarCacheUpdated)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.primaryBlue)
            }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(.gray)
        }
    }
}
