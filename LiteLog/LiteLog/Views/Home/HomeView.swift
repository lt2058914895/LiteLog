import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var allRecords: [WeightRecord]
    @Query private var userProfile: [UserProfile]

    @State private var weightInput = ""
    @State private var showingAddSheet = false

    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    private var latestWeight: Double? {
        allRecords.first?.weight
    }

    private var todayRecord: WeightRecord? {
        let today = Date().startOfDay
        return allRecords.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var latestBodyFatRecord: WeightRecord? {
        allRecords.first { $0.bodyFatPercentage != nil }
    }

    private var latestBodyFat: Double? {
        latestBodyFatRecord?.bodyFatPercentage
    }

    private var latestWaistRecord: WeightRecord? {
        allRecords.first { $0.waistCircumference != nil }
    }

    private var latestWaist: Double? {
        latestWaistRecord?.waistCircumference
    }

    private var latestHipRecord: WeightRecord? {
        allRecords.first { $0.hipCircumference != nil }
    }

    private var latestHip: Double? {
        latestHipRecord?.hipCircumference
    }

    private var latestThighRecord: WeightRecord? {
        allRecords.first { $0.thighCircumference != nil }
    }

    private var latestThigh: Double? {
        latestThighRecord?.thighCircumference
    }

    private var bodyFatProgress: Double {
        guard let current = latestBodyFat else { return 0 }
        return min(current / 50.0 * 100, 100)
    }

    

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    todayWeightCard

                    bmiProgressSection

                    HStack(spacing: 16) {
                        bodyFatCard
                            .frame(maxWidth: .infinity)
                        measurementsCard
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        avatarImageView
                        Text(NSLocalizedString("tab.home", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .adaptiveSheet(isPresented: $showingAddSheet) {
                QuickAddWeightView(isPresented: $showingAddSheet)
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var todayWeightCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("home.today", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)

                    if let latest = latestWeight {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(unit.convertFromKg(latest).weightString)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)

                            Text(unit.shortName)
                                .font(.title2)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text("-- \(unit.shortName)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                }

                Spacer()
            }

            Button(action: { showingAddSheet = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text(NSLocalizedString("home.add.weight", comment: ""))
                }
                .primaryButtonStyle()
            }
        }
        .padding()
        .cardStyle()
    }



    private var bodyFatCard: some View {
        NavigationLink(destination: BodyFatView()) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Text(NSLocalizedString("home.body.fat", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.tertiaryText)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let bodyFat = latestBodyFat {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", bodyFat))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)

                            Text("%")
                                .font(.title)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text("-- %")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var measurementsCard: some View {
        NavigationLink(destination: WaistCircumferenceView()) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Text(NSLocalizedString("home.measurements", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.tertiaryText)
                }
                VStack(spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("home.waist", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text(latestWaist != nil ? String(format: "%.1f cm", latestWaist!) : "--")
                            .font(.body)
                            .foregroundColor(.primaryText)
                    }
                    HStack {
                        Text(NSLocalizedString("home.hip", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text(latestHip != nil ? String(format: "%.1f cm", latestHip!) : "--")
                            .font(.body)
                            .foregroundColor(.primaryText)
                    }
                    HStack {
                        Text(NSLocalizedString("home.thigh", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text(latestThigh != nil ? String(format: "%.1f cm", latestThigh!) : "--")
                            .font(.body)
                            .foregroundColor(.primaryText)
                    }
                }
            }
            .padding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var bmiCard: some View {
        if let profile = profile {
            if let latest = latestWeight {
                return AnyView(BMIProgressView(
                    currentWeight: latest,
                    height: profile.height
                ))
            } else {
                return AnyView(
                    VStack(spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("home.bmi", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                        }
                        
                        Text(NSLocalizedString("home.bmi.no.data", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .padding(.vertical, 20)
                    }
                    .padding()
                    .cardStyle()
                )
            }
        } else {
            return AnyView(
                VStack(spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("home.bmi", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("home.bmi.no.profile", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        
                        Button(NSLocalizedString("action.edit", comment: "")) {
                            NotificationCenter.default.post(name: .showProfileEditor, object: nil)
                        }
                        .foregroundColor(.primaryBlue)
                        .font(.subheadline)
                    }
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .cardStyle()
            )
        }
    }
    
    private var goalCard: some View {
        if let profile = profile {
            return AnyView(
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.primaryBlue)
                        
                        Text(NSLocalizedString("home.goal", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        if let latest = latestWeight {
                            let weightDifference = profile.goalWeight - latest
                            let difference = unit.convertFromKg(weightDifference)
                            let differenceString = weightDifference > 0 ? "+\(difference.weightString)" : difference.weightString
                            
                            HStack(alignment: .lastTextBaseline) {
                                VStack(alignment: .leading) {
                                    Text("\(unit.convertFromKg(profile.goalWeight).weightString) \(unit.shortName)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.primaryText)
                                    
                                    Text("\(NSLocalizedString("home.goal.weight", comment: ""))")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(differenceString)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(weightDifference > 0 ? .orange : .green)
                                    
                                    Text(NSLocalizedString("home.to.goal", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                            }
                        } else {
                            VStack(spacing: 8) {
                                Text("\(unit.convertFromKg(profile.goalWeight).weightString) \(unit.shortName)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primaryText)
                                
                                Text(NSLocalizedString("home.goal.weight", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .padding()
                .cardStyle()
            )
        } else {
            return AnyView(EmptyView())
        }
    }
    
    private var bmiProgressSection: some View {
        VStack(spacing: 16) {
            bmiCard
            goalCard
        }
    }
    

    
    @ViewBuilder
    private var avatarImageView: some View {
        if settingsManager.isLoggedIn, !settingsManager.avatarUrl.isEmpty {
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

struct QuickAddWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    @Binding var isPresented: Bool

    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var weightInput = ""
    @FocusState private var isKeyboardFocused: Bool
    @State private var showingDuplicateAlert = false
    @State private var selectedTimePeriod: MeasurementTimePeriod = .random
    
    // 图片相关状态
    @State private var selectedImage: UIImage?
    @State private var imageUrl: String?
    @State private var showingImagePicker = false
    @State private var showingImageSourcePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .camera

    private var unit: WeightUnit { settingsManager.weightUnit }

    private var isValidWeight: Bool {
        guard let value = Double(weightInput) else { return false }
        return value > 0 && value < 500
    }

    private var todayHasRecord: Bool {
        let today = Date().startOfDay
        return records.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                displayView

                NumericKeyboardView(value: $weightInput, unit: unit) {
                    saveWeight()
                }

                Spacer()

                saveButton
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("home.add.weight", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        isPresented = false
                    }
                }
            }
            .alert(NSLocalizedString("record.duplicate.title", comment: ""), isPresented: $showingDuplicateAlert) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.confirm", comment: "")) {
                    confirmSaveWeight()
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
        }
    }

    private var displayView: some View {
        VStack(spacing: 16) {
            // 测量时段选择
            VStack(spacing: 8) {
                Text(NSLocalizedString("record.measurement_period", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
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
            
            // OCR 照片区域或相机按钮
            if selectedImage != nil || imageUrl != nil {
                // 有照片时显示照片区域
                VStack(spacing: 12) {
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
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                // 没有照片时显示相机按钮
                HStack {
                    Spacer()
                    Button(action: { showingImageSourcePicker = true }) {
                        Image(systemName: "camera")
                            .font(.system(size: 20))
                            .foregroundColor(.primaryBlue)
                    }
                    .padding(10)
                    .background(Color.primaryBlue.opacity(0.1))
                    .cornerRadius(8)
                    .accessibilityLabel(NSLocalizedString("record.accessibility.camera", comment: ""))
                }
            }
            
            // 体重
            Text(NSLocalizedString("home.weight", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            // 体重数值显示
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(weightInput.isEmpty ? "0" : weightInput)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(unit.shortName)
                    .font(.title)
                    .foregroundColor(.secondaryText)
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveWeight) {
            Text(NSLocalizedString("action.save", comment: ""))
                .primaryButtonStyle()
        }
        .disabled(!isValidWeight)
        .opacity(isValidWeight ? 1.0 : 0.5)
    }

    private func saveWeight() {
        guard Double(weightInput) != nil else { return }

        if todayHasRecord {
            showingDuplicateAlert = true
            return
        }

        confirmSaveWeight()
    }

    private func confirmSaveWeight() {
        guard let weightValue = Double(weightInput) else { return }

        let weightInKg = unit.convertToKg(weightValue)

        if todayHasRecord {
            deleteTodayRecords()
        }

        let record = WeightRecord(
            date: Date(),
            weight: weightInKg,
            imageUrl: imageUrl,
            measurementTimePeriod: selectedTimePeriod.rawValue,
            syncStatus: WeightRecordSyncStatus.pending
        )
        record.selectedImage = selectedImage

        modelContext.insert(record)
        
        do {
            try modelContext.save()
            // 触发同步到云数据库
            DataSyncManager.shared.triggerWeightRecordSync(modelContext: modelContext)
        } catch {
            print("Failed to save weight: \(error)")
            return
        }

        isPresented = false
    }

    private func deleteTodayRecords() {
        let today = Date().startOfDay
        let todayRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let recordIds = todayRecords.map { $0.id.uuidString }
        for record in todayRecords {
            modelContext.delete(record)
        }
        
        do {
            try modelContext.save()
            // 同步删除到云数据库
            Task {
                await DataSyncManager.shared.syncDeletedRecords(recordIds: recordIds)
            }
        } catch {
            print("Failed to delete today records: \(error)")
        }
    }
}
