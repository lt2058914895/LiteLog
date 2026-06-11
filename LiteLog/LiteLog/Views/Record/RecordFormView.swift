import SwiftUI
import SwiftData

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
    @State private var hipString: String
    @State private var thighString: String
    @State private var note: String
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateAlert = false
    @State private var selectedTimePeriod: MeasurementTimePeriod = .random
    
    // 图片相关状态
    @State private var selectedImage: UIImage?
    @State private var imageUrl: String?
    @State private var showingImagePicker = false
    @State private var showingImageSourcePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .camera

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

    private var hipCircumference: Double? {
        guard !hipString.isEmpty, let value = Double(hipString) else { return nil }
        return value
    }

    private var thighCircumference: Double? {
        guard !thighString.isEmpty, let value = Double(thighString) else { return nil }
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
            self._hipString = State(initialValue: record.hipCircumference.map { String(format: "%.1f", $0) } ?? "")
            self._thighString = State(initialValue: record.thighCircumference.map { String(format: "%.1f", $0) } ?? "")
            self._note = State(initialValue: record.note ?? "")
            self._imageUrl = State(initialValue: record.imageUrl)
            self._selectedTimePeriod = State(initialValue: record.measurementTimePeriod.flatMap { MeasurementTimePeriod(rawValue: $0) } ?? .random)
        } else {
            self._date = State(initialValue: Date())
            self._weightString = State(initialValue: "")
            self._bodyFatString = State(initialValue: "")
            self._waistString = State(initialValue: "")
            self._hipString = State(initialValue: "")
            self._thighString = State(initialValue: "")
            self._note = State(initialValue: "")
            self._imageUrl = State(initialValue: nil)
            self._selectedTimePeriod = State(initialValue: .random)
        }
    }

    var body: some View {
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
                
                Section(NSLocalizedString("record.measurement_period", comment: "")) {
                    HStack(spacing: 8) {
                        ForEach(MeasurementTimePeriod.allCases, id: \.self) { period in
                            Button(action: {
                                selectedTimePeriod = period
                            }) {
                                Text(period.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTimePeriod == period ? Color.primaryBlue : Color(.secondarySystemGroupedBackground))
                                    .foregroundColor(selectedTimePeriod == period ? .white : .primaryText)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // 照片区域
                if selectedImage != nil || imageUrl != nil {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                            } else if let url = imageUrl, let imageUrl = URL(string: url) {
                                AsyncImage(url: imageUrl) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 80)
                                            .cornerRadius(8)
                                    } else {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 80)
                                            .foregroundColor(.secondaryText)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("record.photo.attached", comment: ""))
                                    .font(.subheadline)
                                Button(NSLocalizedString("record.change.photo", comment: "")) {
                                    showingImageSourcePicker = true
                                }
                                .font(.caption)
                                .foregroundColor(.primaryBlue)
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                selectedImage = nil
                                imageUrl = nil
                            } label: {
                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.red)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 10, y: -5)
                            .highPriorityGesture(TapGesture().onEnded {
                                selectedImage = nil
                                imageUrl = nil
                            })
                        }
                    }
                } else {
                    // 相机按钮
                    Section {
                        HStack {
                            Spacer()
                            Button(action: { showingImageSourcePicker = true }) {
                                Image(systemName: "camera")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primaryBlue)
                            }
                            
                            .padding(8)
                            .background(Color.primaryBlue.opacity(0.1))
                            .cornerRadius(8)
                            .accessibilityLabel(NSLocalizedString("record.accessibility.camera", comment: ""))
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listSectionSpacing(0)
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

                Section(NSLocalizedString("record.hip.circumference.optional", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("record.hip.circumference", comment: ""), text: $hipString)
                            .keyboardType(.decimalPad)

                        Text("cm")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.thigh.circumference.optional", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("record.thigh.circumference", comment: ""), text: $thighString)
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
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
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
            .confirmationDialog(NSLocalizedString("record.select.source", comment: ""), isPresented: $showingImageSourcePicker) {
                Button(NSLocalizedString("record.take.photo", comment: "")) {
                    imageSourceType = .camera
                    showingImagePicker = true
                }
                Button(NSLocalizedString("record.upload.image", comment: "")) {
                    imageSourceType = .photoLibrary
                    showingImagePicker = true
                }
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, isPresented: $showingImagePicker, sourceType: imageSourceType)
                    .ignoresSafeArea(.all)
                    .background(Color.black)
            }
            
            .onAppear {
                if isEditMode && weightString.isEmpty, let record = record {
                    weightString = String(format: "%.1f", unit.convertFromKg(record.weight))
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
            hipCircumference: hipCircumference,
            thighCircumference: thighCircumference,
            note: note.isEmpty ? nil : note,
            imageUrl: imageUrl,
            measurementTimePeriod: selectedTimePeriod.rawValue,
            syncStatus: WeightRecordSyncStatus.pending
        )
        newRecord.selectedImage = selectedImage

        modelContext.insert(newRecord)
        
        do {
            try modelContext.save()
            // 触发同步到云数据库
            DataSyncManager.shared.triggerWeightRecordSync(modelContext: modelContext)
        } catch {
            errorMessage = NSLocalizedString("error.save.failed", comment: "")
            showingError = true
            return
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
        record.hipCircumference = Double(hipString)
        record.thighCircumference = Double(thighString)
        record.measurementTimePeriod = selectedTimePeriod.rawValue
        record.note = note.isEmpty ? nil : note
        record.imageUrl = imageUrl
        record.selectedImage = selectedImage
        record.updatedAt = Date()
        record.syncStatus = .pending  // 标记为待同步
        
        do {
            try modelContext.save()
            // 触发同步到云数据库
            DataSyncManager.shared.triggerWeightRecordSync(modelContext: modelContext)
        } catch {
            errorMessage = NSLocalizedString("error.save.failed", comment: "")
            showingError = true
            return
        }

        dismiss()
    }

    private func deleteRecord() {
        if let record = record {
            let recordId = record.id.uuidString
            modelContext.delete(record)
            
            do {
                try modelContext.save()
                // 同步删除到云数据库
                Task {
                    await DataSyncManager.shared.syncDeletedRecords(recordIds: [recordId])
                }
            } catch {
                print("Failed to delete record: \(error)")
            }
        }
        dismiss()
    }

    private func deleteRecordsForSelectedDate() {
        let dateRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let recordIds = dateRecords.map { $0.id.uuidString }
        for record in dateRecords {
            modelContext.delete(record)
        }
        
        do {
            try modelContext.save()
            // 同步删除到云数据库
            Task {
                await DataSyncManager.shared.syncDeletedRecords(recordIds: recordIds)
            }
        } catch {
            print("Failed to delete records for selected date: \(error)")
        }
    }

}
