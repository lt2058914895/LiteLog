import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var selectedDate: Date?
    @State private var showingAddSheet = false
    @State private var selectedRecord: WeightRecord?
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

struct RecordFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    let record: WeightRecord?
    @Binding var isPresented: Bool

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var date: Date
    @State private var weightString: String
    @State private var bodyFatString: String
    @State private var waistString: String
    @State private var note: String
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateAlert = false

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var isEditMode: Bool { record != nil }

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

    private var waistCircumference: Double? {
        guard !waistString.isEmpty, let value = Double(waistString) else { return nil }
        return value
    }

    init(record: WeightRecord? = nil, isPresented: Binding<Bool>) {
        self.record = record
        self._isPresented = isPresented
        
        if let record = record {
            self._date = State(initialValue: record.date)
            self._weightString = State(initialValue: "")
            self._bodyFatString = State(initialValue: record.bodyFatPercentage.map { String(format: "%.1f", $0) } ?? "")
            self._waistString = State(initialValue: record.waistCircumference.map { String(format: "%.1f", $0) } ?? "")
            self._note = State(initialValue: record.note ?? "")
        } else {
            self._date = State(initialValue: Date())
            self._weightString = State(initialValue: "")
            self._bodyFatString = State(initialValue: "")
            self._waistString = State(initialValue: "")
            self._note = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("record.date", comment: "")) {
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .disabled(isEditMode)
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

                Section(NSLocalizedString("record.waist.circumference.optional", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("record.waist.circumference", comment: ""), text: $waistString)
                            .keyboardType(.decimalPad)

                        Text("cm")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.note", comment: "")) {
                    TextField(NSLocalizedString("record.note.placeholder", comment: ""), text: $note)
                }

                if isEditMode {
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
            }
            .navigationTitle(isEditMode ? NSLocalizedString("record.edit", comment: "") : NSLocalizedString("record.add", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.save", comment: "")) {
                        saveRecord()
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
            .alert(NSLocalizedString("record.duplicate.title", comment: ""), isPresented: $showingDuplicateAlert) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.confirm", comment: "")) {
                    confirmSaveRecord()
                }
            } message: {
                Text(NSLocalizedString("record.duplicate.message", comment: ""))
            }
            .onAppear {
                if isEditMode && weightString.isEmpty, let record = record {
                    weightString = String(format: "%.1f", unit.convertFromKg(record.weight))
                }
            }
        }
    }

    private func saveRecord() {
        guard Double(weightString) != nil else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        if isEditMode {
            updateRecord()
        } else {
            if selectedDateHasRecord {
                showingDuplicateAlert = true
                return
            }
            confirmSaveRecord()
        }
    }

    private func confirmSaveRecord() {
        guard let weightValue = Double(weightString) else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        let weightInKg = unit.convertToKg(weightValue)
        
        if !isEditMode && selectedDateHasRecord {
            deleteRecordsForSelectedDate()
        }
        
        let newRecord = WeightRecord(
            date: date.startOfDay,
            weight: weightInKg,
            bodyFatPercentage: bodyFatPercentage,
            waistCircumference: waistCircumference,
            note: note.isEmpty ? nil : note
        )

        modelContext.insert(newRecord)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = NSLocalizedString("error.save.failed", comment: "")
            showingError = true
            return
        }

        if settingsManager.healthKitEnabled {
            Task {
                try? await HealthKitManager.shared.saveWeight(
                    weightInKg: weightInKg,
                    date: date,
                    bodyFatPercentage: bodyFatPercentage
                )
            }
        }

        dismiss()
    }

    private func updateRecord() {
        guard let record = record, let weightValue = Double(weightString) else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        record.date = date.startOfDay
        record.weight = unit.convertToKg(weightValue)
        record.bodyFatPercentage = Double(bodyFatString)
        record.waistCircumference = Double(waistString)
        record.note = note.isEmpty ? nil : note
        record.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = NSLocalizedString("error.save.failed", comment: "")
            showingError = true
            return
        }

        dismiss()
    }

    private func deleteRecord() {
        if let record = record {
            modelContext.delete(record)
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to delete record: \(error)")
            }
        }
        dismiss()
    }

    private func deleteRecordsForSelectedDate() {
        let dateRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        for record in dateRecords {
            modelContext.delete(record)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete records for selected date: \(error)")
        }
    }
}
