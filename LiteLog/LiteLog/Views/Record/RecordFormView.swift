import SwiftUI
import CoreData
import UIKit
import os

struct RecordFormData: Equatable {
    let id: String
    var date: Date
    var weightString: String
    var bodyFatString: String
    var waistString: String
    var hipString: String
    var chestString: String
    var thighString: String
    var note: String
    var measurementTimePeriod: MeasurementTimePeriod
    
    static func == (lhs: RecordFormData, rhs: RecordFormData) -> Bool {
        lhs.id == rhs.id
    }
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "RecordFormView")

extension View {
    func dismissKeyboardOnTapOutside() -> some View {
        self.modifier(DismissKeyboardModifier())
    }
}

struct DismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture(coordinateSpace: .global) { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
    }
}

extension UIApplication {
    @objc func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct RecordFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    let recordData: RecordFormData?
    @Binding var isPresented: Bool
    var onSave: (() -> Void)?

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>

    @State private var date: Date
    @State private var weightString: String
    @State private var bodyFatString: String
    @State private var waistString: String
    @State private var hipString: String
    @State private var chestString: String
    @State private var thighString: String
    @State private var note: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateAlert = false
    @State private var duplicateRecordPending: WeightRecord?
    @State private var editingRecordID: UUID?
    @State private var selectedTimePeriod: MeasurementTimePeriod = .random
    
    @State private var showAdvancedFields = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }
    
    private var unit: WeightUnit { settingsManager.weightUnit }
    private var isEditMode: Bool { editingRecordID != nil }

    private var isValidWeight: Bool {
        guard let value = Double(weightString) else { return false }
        return value > 0 && value < 500
    }

    private var duplicateRecordForSelection: WeightRecord? {
        records.first { record in
            record.id != editingRecordID &&
            Calendar.current.isDate(record.date, inSameDayAs: date) &&
            (record.measurementTimePeriod.flatMap(MeasurementTimePeriod.init(rawValue:)) ?? .random) == selectedTimePeriod
        }
    }

    private var bodyFatPercentage: Double? {
        guard !bodyFatString.isEmpty, let value = Double(bodyFatString) else { return nil }
        return value
    }

    private var waistCircumference: Double? {
        guard !waistString.isEmpty, let value = Double(waistString) else { return nil }
        return value
    }

    private var hipCircumference: Double? {
        guard !hipString.isEmpty, let value = Double(hipString) else { return nil }
        return value
    }

    private var chestCircumference: Double? {
        guard !chestString.isEmpty, let value = Double(chestString) else { return nil }
        return value
    }

    private var thighCircumference: Double? {
        guard !thighString.isEmpty, let value = Double(thighString) else { return nil }
        return value
    }
    
    private var hasAdvancedData: Bool {
        !bodyFatString.isEmpty || !waistString.isEmpty || !hipString.isEmpty || !chestString.isEmpty || !thighString.isEmpty
    }

    init(recordData: RecordFormData? = nil, isPresented: Binding<Bool>, onSave: (() -> Void)? = nil) {
        self.recordData = recordData
        self._isPresented = isPresented
        self.onSave = onSave
        
        if let recordData = recordData {
            self._editingRecordID = State(initialValue: UUID(uuidString: recordData.id))
            self._date = State(initialValue: recordData.date)
            self._weightString = State(initialValue: recordData.weightString)
            self._bodyFatString = State(initialValue: recordData.bodyFatString)
            self._waistString = State(initialValue: recordData.waistString)
            self._hipString = State(initialValue: recordData.hipString)
            self._chestString = State(initialValue: recordData.chestString)
            self._thighString = State(initialValue: recordData.thighString)
            self._note = State(initialValue: recordData.note)
            self._selectedTimePeriod = State(initialValue: recordData.measurementTimePeriod)
            self._showAdvancedFields = State(initialValue: true)
        } else {
            self._editingRecordID = State(initialValue: nil)
            self._date = State(initialValue: Date())
            self._weightString = State(initialValue: "")
            self._bodyFatString = State(initialValue: "")
            self._waistString = State(initialValue: "")
            self._hipString = State(initialValue: "")
            self._chestString = State(initialValue: "")
            self._thighString = State(initialValue: "")
            self._note = State(initialValue: "")
            self._selectedTimePeriod = State(initialValue: .random)
            self._showAdvancedFields = State(initialValue: false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                weightCard
                
                dateAndPeriodSection
                
                VStack {
                    advancedSectionHeader
                    
                    if showAdvancedFields {
                        advancedFieldsSection
                    }
                }
                
                noteSection
                
                saveButtonSection
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isEditMode ? NSLocalizedString("record.edit", comment: "") : NSLocalizedString("record.add", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
            Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(NSLocalizedString("record.duplicate.title", comment: ""), isPresented: $showingDuplicateAlert) {
            Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
            if !isEditMode, duplicateRecordPending != nil {
                Button(NSLocalizedString("record.duplicate.edit", comment: "")) {
                    editDuplicateRecord()
                }
            }
            Button(NSLocalizedString("record.duplicate.replace", comment: "")) {
                let duplicate = duplicateRecordPending
                duplicateRecordPending = nil
                confirmSaveRecord(replacing: duplicate)
            }
        } message: {
            Text(
                NSLocalizedString(
                    isEditMode
                        ? "record.duplicate.conflict.message"
                        : "record.duplicate.message",
                    comment: ""
                )
            )
        }
        .dismissKeyboardOnTapOutside()
    }
    
    private var weightCard: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("measure.weight", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .center, spacing: 8) {
                TextField(NSLocalizedString("common.input.placeholder", comment: ""), text: $weightString)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .onChange(of: weightString) { newValue in
                        weightString = formatNumericInput(newValue)
                    }
                
                Text(unit.shortName)
                    .font(.title)
                    .foregroundColor(.secondaryText)
                    .padding(.bottom, 8)
                
                if !weightString.isEmpty {
                    Button(action: { weightString = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.systemGray4))
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var dateAndPeriodSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .foregroundColor(.primaryBlue)
                    .font(.headline)
                
                DatePicker(
                    "",
                    selection: $date,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .disabled(isEditMode)
                
                Spacer()
                
                if isEditMode {
                    Image(systemName: "lock")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundColor(.primaryBlue)
                    .font(.headline)
                
                MeasurementPeriodSelector(selectedPeriod: $selectedTimePeriod)
            }
        }
        .padding(16)
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }
    
    private var advancedSectionHeader: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showAdvancedFields.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "layers")
                    .foregroundColor(.primaryBlue)
                
                Text(NSLocalizedString("record.more.measurements", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if hasAdvancedData {
                    Text(NSLocalizedString("record.has.data", comment: ""))
                        .font(.caption)
                        .foregroundColor(.primaryBlue)
                }
                
                Image(systemName: showAdvancedFields ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondaryText)
                    .font(.caption)
            }
            .padding(16)
            .background(cardBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    private var advancedFieldsSection: some View {
        VStack(spacing: 0) {
            MeasurementRow(
                label: NSLocalizedString("measure.body.fat", comment: ""),
                placeholder: NSLocalizedString("common.input.placeholder", comment: ""),
                text: $bodyFatString,
                unit: "%"
            )
            
            Divider()
            
            MeasurementRow(
                label: NSLocalizedString("measure.waist", comment: ""),
                placeholder: NSLocalizedString("common.input.placeholder", comment: ""),
                text: $waistString,
                unit: "cm"
            )
            
            Divider()
            
            MeasurementRow(
                label: NSLocalizedString("measure.hip", comment: ""),
                placeholder: NSLocalizedString("common.input.placeholder", comment: ""),
                text: $hipString,
                unit: "cm"
            )
            
            Divider()
            
            MeasurementRow(
                label: NSLocalizedString("measure.chest", comment: ""),
                placeholder: NSLocalizedString("common.input.placeholder", comment: ""),
                text: $chestString,
                unit: "cm"
            )
            
            Divider()
            
            MeasurementRow(
                label: NSLocalizedString("measure.thigh", comment: ""),
                placeholder: NSLocalizedString("common.input.placeholder", comment: ""),
                text: $thighString,
                unit: "cm"
            )
        }
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .padding(.top, 4)
    }
    
    private var noteSection: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("record.note", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ClearTextView(
                text: $note,
                placeholder: NSLocalizedString("record.note.placeholder", comment: ""),
                font: UIFont.preferredFont(forTextStyle: .body),
                textColor: .label
            )
            .frame(minHeight: 80)
            .background(cardBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    private var saveButtonSection: some View {
        Button(action: {
            saveRecord()
        }) {
            Text(NSLocalizedString("action.save", comment: ""))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(isValidWeight ? Color.primaryBlue : Color.gray)
                .cornerRadius(12)
        }
        .disabled(!isValidWeight)
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
            if let duplicate = duplicateRecordForSelection {
                duplicateRecordPending = duplicate
                showingDuplicateAlert = true
                return
            }
            confirmSaveRecord(replacing: nil)
        }
    }

    private func confirmSaveRecord(replacing existingRecord: WeightRecord?) {
        guard let weightValue = Double(weightString) else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        let weightInKg = unit.convertToKg(weightValue)
        let record: WeightRecord
        if let editingRecordID,
           let currentRecord = records.first(where: { $0.id == editingRecordID }) {
            if let existingRecord {
                context.delete(existingRecord)
            }
            record = currentRecord
        } else {
            record = existingRecord ?? WeightRecord.create(in: context, weight: weightInKg)
        }
        applyFormValues(to: record, weightInKg: weightInKg)

        do {
            try context.save()
        } catch {
            errorMessage = NSLocalizedString("error.save.failed", comment: "")
            showingError = true
            return
        }

        HapticManager.success()
        onSave?()
        dismiss()
    }

    private func updateRecord() {
        guard let recordID = editingRecordID, let weightValue = Double(weightString) else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        guard let record = records.first(where: { $0.id == recordID }) else {
            errorMessage = NSLocalizedString("error.record.not.found", comment: "")
            showingError = true
            return
        }

        if let duplicate = duplicateRecordForSelection {
            duplicateRecordPending = duplicate
            showingDuplicateAlert = true
            return
        }

        applyFormValues(to: record, weightInKg: unit.convertToKg(weightValue))
        
        do {
            try context.save()
        } catch {
            errorMessage = NSLocalizedString("error.save.failed", comment: "")
            showingError = true
            return
        }

        HapticManager.success()
        onSave?()
        dismiss()
    }

    private func applyFormValues(to record: WeightRecord, weightInKg: Double) {
        record.date = date
        record.weight = weightInKg
        record.bodyFatPercentageValue = bodyFatPercentage
        record.waistCircumferenceValue = waistCircumference
        record.hipCircumferenceValue = hipCircumference
        record.chestCircumferenceValue = chestCircumference
        record.thighCircumferenceValue = thighCircumference
        record.measurementTimePeriod = selectedTimePeriod.rawValue
        record.note = note.isEmpty ? nil : note
        record.updatedAt = Date()
    }

    private func editDuplicateRecord() {
        guard let duplicate = duplicateRecordPending,
              let period = duplicate.measurementTimePeriod.flatMap(MeasurementTimePeriod.init(rawValue:)) else {
            duplicateRecordPending = nil
            return
        }

        editingRecordID = duplicate.id
        date = duplicate.date
        weightString = unit.convertFromKg(duplicate.weight).smartFormatted
        bodyFatString = duplicate.bodyFatPercentageValue?.smartFormatted ?? ""
        waistString = duplicate.waistCircumferenceValue?.smartFormatted ?? ""
        hipString = duplicate.hipCircumferenceValue?.smartFormatted ?? ""
        chestString = duplicate.chestCircumferenceValue?.smartFormatted ?? ""
        thighString = duplicate.thighCircumferenceValue?.smartFormatted ?? ""
        note = duplicate.note ?? ""
        selectedTimePeriod = period
        showAdvancedFields = true
        duplicateRecordPending = nil
    }
    
    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }
    
    private func formatNumericInput(_ input: String) -> String {
        let filtered = input.filter { "0123456789.".contains($0) }
        let parts = filtered.components(separatedBy: ".")
        if parts.count > 2 {
            let integerPart = parts.first ?? ""
            let decimalPart = parts.dropFirst().joined().prefix(2)
            return "\(integerPart).\(decimalPart)"
        } else if parts.count == 2 {
            let integerPart = parts[0]
            let decimalPart = parts[1].prefix(2)
            return "\(integerPart).\(decimalPart)"
        } else {
            return filtered
        }
    }

}

struct MeasurementRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let unit: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primaryText)
                .frame(width: 60, alignment: .leading)
            
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .font(.body)
                .foregroundColor(.primaryText)
                .onChange(of: text) { newValue in
                    text = formatNumericInput(newValue)
                }
            
            Text(unit)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray4))
                }
            }
        }
        .padding(12)
    }
    
    private func formatNumericInput(_ input: String) -> String {
        let filtered = input.filter { "0123456789.".contains($0) }
        let parts = filtered.components(separatedBy: ".")
        if parts.count > 2 {
            let integerPart = parts.first ?? ""
            let decimalPart = parts.dropFirst().joined().prefix(2)
            return "\(integerPart).\(decimalPart)"
        } else if parts.count == 2 {
            let integerPart = parts[0]
            let decimalPart = parts[1].prefix(2)
            return "\(integerPart).\(decimalPart)"
        } else {
            return filtered
        }
    }
}

struct MeasurementPeriodSelector: View {
    @Binding var selectedPeriod: MeasurementTimePeriod
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(MeasurementTimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    Text(period.displayName)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selectedPeriod == period ? Color.primaryBlue : cardBackgroundColor)
                        .foregroundColor(selectedPeriod == period ? .white : .primaryText)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
