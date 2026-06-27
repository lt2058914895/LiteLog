import SwiftUI
import CoreData

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
    var imageUrl: String?
    var measurementTimePeriod: MeasurementTimePeriod
    
    static func == (lhs: RecordFormData, rhs: RecordFormData) -> Bool {
        lhs.id == rhs.id
    }
}

extension View {
    func dismissKeyboardOnTapOutside() -> some View {
        self.modifier(DismissKeyboardModifier())
    }
}

struct DismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let tapGesture = UITapGestureRecognizer(target: UIApplication.shared, action: #selector(UIApplication.shared.dismissKeyboard))
                tapGesture.cancelsTouchesInView = false
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.windows.first?.addGestureRecognizer(tapGesture)
                }
            }
            .onDisappear {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.windows.first?.gestureRecognizers?.removeAll { $0 is UITapGestureRecognizer }
                }
            }
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
    @State private var selectedTimePeriod: MeasurementTimePeriod = .random
    
    // 图片相关状态
    @State private var selectedImage: UIImage?
    @State private var imageUrl: String?
    @State private var showingImagePicker = false
    @State private var showingImageSourcePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .camera

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var isEditMode: Bool { recordData != nil }

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

    private var chestCircumference: Double? {
        guard !chestString.isEmpty, let value = Double(chestString) else { return nil }
        return value
    }

    private var thighCircumference: Double? {
        guard !thighString.isEmpty, let value = Double(thighString) else { return nil }
        return value
    }

    init(recordData: RecordFormData? = nil, isPresented: Binding<Bool>) {
        self.recordData = recordData
        self._isPresented = isPresented
        
        if let recordData = recordData {
            self._date = State(initialValue: recordData.date)
            self._weightString = State(initialValue: recordData.weightString)
            self._bodyFatString = State(initialValue: recordData.bodyFatString)
            self._waistString = State(initialValue: recordData.waistString)
            self._hipString = State(initialValue: recordData.hipString)
            self._chestString = State(initialValue: recordData.chestString)
            self._thighString = State(initialValue: recordData.thighString)
            self._note = State(initialValue: recordData.note)
            self._imageUrl = State(initialValue: recordData.imageUrl)
            self._selectedTimePeriod = State(initialValue: recordData.measurementTimePeriod)
        } else {
            self._date = State(initialValue: Date())
            self._weightString = State(initialValue: "")
            self._bodyFatString = State(initialValue: "")
            self._waistString = State(initialValue: "")
            self._hipString = State(initialValue: "")
            self._chestString = State(initialValue: "")
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
                    MeasurementPeriodSelector(selectedPeriod: $selectedTimePeriod)
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
                        CameraButtonView(action: { showingImageSourcePicker = true })
                    }
                    .listRowBackground(Color.clear)
                }

                Section(NSLocalizedString("record.weight", comment: "")) {
                    HStack {
                        NumericTextField(NSLocalizedString("record.weight", comment: ""), text: $weightString)

                        Text(unit.shortName)
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.body.fat.optional", comment: "")) {
                    HStack {
                        NumericTextField(NSLocalizedString("record.body.fat", comment: ""), text: $bodyFatString)

                        Text("%")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.waist.circumference.optional", comment: "")) {
                    HStack {
                        NumericTextField(NSLocalizedString("record.waist.circumference", comment: ""), text: $waistString)

                        Text("cm")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.hip.circumference.optional", comment: "")) {
                    HStack {
                        NumericTextField(NSLocalizedString("record.hip.circumference", comment: ""), text: $hipString)

                        Text("cm")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.chest.circumference.optional", comment: "")) {
                    HStack {
                        NumericTextField(NSLocalizedString("record.chest.circumference", comment: ""), text: $chestString)

                        Text("cm")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.thigh.circumference.optional", comment: "")) {
                    HStack {
                        NumericTextField(NSLocalizedString("record.thigh.circumference", comment: ""), text: $thighString)

                        Text("cm")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("record.note", comment: "")) {
                    noteEditorView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditMode ? NSLocalizedString("record.edit", comment: "") : NSLocalizedString("record.add", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: backButton, trailing: saveButton)
            .tabBarHidden(true)
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
            .dismissKeyboardOnTapOutside()
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
        
        let newRecord = WeightRecord.create(in: context, weight: weightInKg)
        newRecord.date = date.startOfDay
        newRecord.bodyFatPercentage = bodyFatPercentage ?? 0
        newRecord.waistCircumference = waistCircumference ?? 0
        newRecord.hipCircumference = hipCircumference ?? 0
        newRecord.chestCircumference = chestCircumference ?? 0
        newRecord.thighCircumference = thighCircumference ?? 0
        newRecord.note = note.isEmpty ? nil : note
        newRecord.imageUrl = imageUrl
        newRecord.measurementTimePeriod = selectedTimePeriod.rawValue
        newRecord.selectedImage = selectedImage

        do {
            try context.save()
        } catch {
            errorMessage = NSLocalizedString("error.save.failed", comment: "")
            showingError = true
            return
        }

        DataSyncManager.shared.triggerWeightRecordSync(context: context)
        dismiss()
    }

    private func updateRecord() {
        guard let recordData = recordData, let recordId = UUID(uuidString: recordData.id), let weightValue = Double(weightString) else {
            errorMessage = NSLocalizedString("error.weight.invalid", comment: "")
            showingError = true
            return
        }

        guard let record = records.first(where: { $0.id == recordId }) else {
            errorMessage = NSLocalizedString("error.record.not.found", comment: "")
            showingError = true
            return
        }

        record.date = date.startOfDay
        record.weight = unit.convertToKg(weightValue)
        record.bodyFatPercentage = Double(bodyFatString) ?? 0
        record.waistCircumference = Double(waistString) ?? 0
        record.hipCircumference = Double(hipString) ?? 0
        record.chestCircumference = Double(chestString) ?? 0
        record.thighCircumference = Double(thighString) ?? 0
        record.measurementTimePeriod = selectedTimePeriod.rawValue
        record.note = note.isEmpty ? nil : note
        record.imageUrl = imageUrl
        record.selectedImage = selectedImage
        record.updatedAt = Date()
        record.syncStatusEnum = .pending
        
        do {
            try context.save()
        } catch {
            errorMessage = NSLocalizedString("error.save.failed", comment: "")
            showingError = true
            return
        }

        DataSyncManager.shared.triggerWeightRecordSync(context: context)
        dismiss()
    }
    
    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            saveRecord()
        }) {
            Text(NSLocalizedString("action.save", comment: ""))
                .foregroundColor(isValidWeight ? .primaryBlue : .gray)
        }
        .disabled(!isValidWeight)
    }
    
    private var noteEditorView: some View {
        ZStack(alignment: .topLeading) {
            Text(note.isEmpty ? NSLocalizedString("record.note.placeholder", comment: "") : "")
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .opacity(note.isEmpty ? 1 : 0)
            
            TextEditor(text: $note)
                .background(Color.clear)
        }
        .frame(minHeight: 100)
    }

    private func deleteRecordsForSelectedDate() {
        let dateRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let recordIds = dateRecords.map { $0.id.uuidString }
        for record in dateRecords {
            context.delete(record)
        }
        
        do {
            try context.save()
            // 同步删除到云数据库
            Task {
                await DataSyncManager.shared.syncDeletedRecords(recordIds: recordIds)
            }
        } catch {
            print("Failed to delete records for selected date: \(error)")
        }
    }

}

struct MeasurementPeriodSelector: View {
    @Binding var selectedPeriod: MeasurementTimePeriod
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(MeasurementTimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    Text(period.displayName)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedPeriod == period ? Color.primaryBlue : Color(.secondarySystemGroupedBackground))
                        .foregroundColor(selectedPeriod == period ? .white : .primaryText)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CameraButtonView: View {
    let action: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                    .foregroundColor(.primaryBlue)
            }
            .padding(8)
            .background(Color.primaryBlue.opacity(0.1))
            .cornerRadius(8)
            .accessibilityLabel(NSLocalizedString("record.accessibility.camera", comment: ""))
            Spacer()
        }
    }
}
