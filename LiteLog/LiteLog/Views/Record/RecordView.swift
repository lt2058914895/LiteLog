import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var selectedDate: Date?
    @State private var showingAddSheet = false
    @State private var selectedRecord: WeightRecord?
    @State private var showingEditSheet = false
    @State private var viewMode: ViewMode = .list

    @Query private var userProfile: [UserProfile]

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

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
            .navigationTitle(NSLocalizedString("tab.record", comment: ""))
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
                AddRecordView(isPresented: $showingAddSheet)
            }
            .sheet(isPresented: $showingEditSheet) {
                if let record = selectedRecord {
                    EditRecordView(record: record, isPresented: $showingEditSheet)
                }
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
                                        showingEditSheet = true
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
                                            showingEditSheet = true
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
                    records: records,
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
                            showingEditSheet = true
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
        withAnimation {
            modelContext.delete(record)
        }
    }
}

struct AddRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    @Binding var isPresented: Bool

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var date = Date()
    @State private var weightString = ""
    @State private var bodyFatString = ""
    @State private var note = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateAlert = false

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var isValidWeight: Bool {
        guard let value = Double(weightString) else { return false }
        return value > 0 && value < 500
    }

    private var selectedDateHasRecord: Bool {
        records.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var bodyFatPercentage: Double? {
        guard !bodyFatString.isEmpty, let value = Double(bodyFatString) else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("record.date", comment: "")) {
                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                }

                Section(NSLocalizedString("record.weight", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("record.weight", comment: ""), text: $weightString)
                            .keyboardType(.decimalPad)

                        Text(unit.shortName)
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.body.fat.optional", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("record.body.fat", comment: ""), text: $bodyFatString)
                            .keyboardType(.decimalPad)

                        Text("%")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.note", comment: "")) {
                    TextField(NSLocalizedString("record.note.placeholder", comment: ""), text: $note)
                }
            }
            .navigationTitle(NSLocalizedString("record.add", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.save", comment: "")) {
                        saveRecord()
                    }
                    .disabled(!isValidWeight)
                }
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert(NSLocalizedString("record.duplicate.title", comment: ""), isPresented: $showingDuplicateAlert) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.confirm", comment: "")) {
                    confirmSaveRecord()
                }
            } message: {
                Text(NSLocalizedString("record.duplicate.message", comment: ""))
            }
        }
    }

    private func saveRecord() {
        guard Double(weightString) != nil else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        if selectedDateHasRecord {
            showingDuplicateAlert = true
            return
        }

        confirmSaveRecord()
    }

    private func confirmSaveRecord() {
        guard let weightValue = Double(weightString) else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        let weightInKg = unit.convertToKg(weightValue)
        
        if selectedDateHasRecord {
            deleteRecordsForSelectedDate()
        }
        
        let record = WeightRecord(
            date: date,
            weight: weightInKg,
            bodyFatPercentage: bodyFatPercentage,
            note: note.isEmpty ? nil : note
        )

        modelContext.insert(record)

        if settingsManager.healthKitEnabled {
            Task {
                try? await HealthKitManager.shared.saveWeight(
                    weightInKg: weightInKg,
                    date: date,
                    bodyFatPercentage: bodyFatPercentage
                )
            }
        }

        isPresented = false
    }

    private func deleteRecordsForSelectedDate() {
        let dateRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        for record in dateRecords {
            modelContext.delete(record)
        }
    }
}

struct EditRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    let record: WeightRecord
    @Binding var isPresented: Bool

    @State private var date: Date = Date()
    @State private var weightString: String = ""
    @State private var bodyFatString: String = ""
    @State private var note: String = ""
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var isValidWeight: Bool {
        guard let value = Double(weightString) else { return false }
        return value > 0 && value < 500
    }

    init(record: WeightRecord, isPresented: Binding<Bool>) {
        self.record = record
        self._isPresented = isPresented
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("record.date", comment: "")) {
                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                }

                Section(NSLocalizedString("record.weight", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("record.weight", comment: ""), text: $weightString)
                            .keyboardType(.decimalPad)

                        Text(unit.shortName)
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.body.fat.optional", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("record.body.fat", comment: ""), text: $bodyFatString)
                            .keyboardType(.decimalPad)

                        Text("%")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.note", comment: "")) {
                    TextField(NSLocalizedString("record.note.placeholder", comment: ""), text: $note)
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(NSLocalizedString("record.delete", comment: ""))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("record.edit", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.save", comment: "")) {
                        updateRecord()
                    }
                    .disabled(!isValidWeight)
                }
            }
            .alert(NSLocalizedString("record.delete.confirm", comment: ""), isPresented: $showingDeleteAlert) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                    deleteRecord()
                }
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func updateRecord() {
        guard let weightValue = Double(weightString) else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        record.date = date
        record.weight = unit.convertToKg(weightValue)
        record.bodyFatPercentage = Double(bodyFatString)
        record.note = note.isEmpty ? nil : note
        record.updatedAt = Date()

        isPresented = false
    }

    private func deleteRecord() {
        modelContext.delete(record)
        isPresented = false
    }
}
