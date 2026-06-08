import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var allRecords: [WeightRecord]
    @Query private var userProfile: [UserProfile]

    @State private var weightInput = ""
    @State private var showingAddSheet = false

    @State private var trendType: WeightChartView.TrendType = .week
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

    private var bodyFatProgress: Double {
        guard let current = latestBodyFat else { return 0 }
        return min(current / 50.0 * 100, 100)
    }

    private var chartStartDate: Date {
        let calendar = Calendar.current
        switch trendType {
        case .week:
            return (calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()).startOfDay
        case .month:
            return (calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()).startOfDay
        case .quarter:
            return (calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()).startOfDay
        }
    }

    private var chartData: [WeightChartView.ChartDataPoint] {
        let filtered = allRecords.filter { $0.date >= chartStartDate }
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.date)
        }

        return grouped.compactMap { $0.value.max(by: { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
            .map { WeightChartView.ChartDataPoint(date: $0.date.startOfDay, weight: $0.weight) }
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
                        waistCard
                            .frame(maxWidth: .infinity)
                    }

                    WeightChartView(data: chartData, unit: unit, trendType: $trendType, startDate: chartStartDate)
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

    private var waistCard: some View {
        NavigationLink(destination: WaistCircumferenceView()) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Text(NSLocalizedString("home.waist.circumference", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.tertiaryText)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let waist = latestWaist {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", waist))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)

                            Text("cm")
                                .font(.title)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text("-- cm")
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

    private var bmiProgressSection: some View {
        VStack(spacing: 16) {
            if let profile = profile {
                if let latest = latestWeight {
                    BMIProgressView(
                        currentWeight: latest,
                        goalWeight: profile.goalWeight,
                        height: profile.height,
                        unit: unit
                    )
                } else {
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
                }
            } else {
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
            }
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
    
    // OCR相关状态
    @State private var selectedImage: UIImage?
    @State private var imageUrl: String?
    @State private var isRecognizing = false
    @State private var showingImagePicker = false
    @State private var showingImageSourcePicker = false
    @State private var showingLoginPrompt = false
    @State private var showingOCRResult = false
    @State private var ocrWeight: Double?
    @State private var imageSourceType: UIImagePickerController.SourceType = .camera
    @State private var showingError = false
    @State private var errorMessage = ""

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
            .alert(NSLocalizedString("ocr.login.required", comment: ""), isPresented: $showingLoginPrompt) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("ocr.action.login", comment: "")) {
                    isPresented = false
                    NotificationCenter.default.post(name: .showProfileEditor, object: nil)
                }
            } message: {
                Text(NSLocalizedString("ocr.login.prompt", comment: ""))
            }
            .alert(NSLocalizedString("ocr.success", comment: ""), isPresented: $showingOCRResult) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.confirm", comment: "")) {
                    confirmOCRResult()
                }
            } message: {
                if let weight = ocrWeight {
                    Text(String(format: NSLocalizedString("ocr.weight.detected", comment: ""), String(format: "%.1f", unit.convertFromKg(weight))))
                } else {
                    Text(NSLocalizedString("ocr.no.weight.detected", comment: ""))
                }
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog(NSLocalizedString("ocr.select.source", comment: ""), isPresented: $showingImageSourcePicker) {
                Button(NSLocalizedString("ocr.take.photo", comment: "")) {
                    if settingsManager.isLoggedIn {
                        imageSourceType = .camera
                        showingImagePicker = true
                    } else {
                        showingLoginPrompt = true
                    }
                }
                Button(NSLocalizedString("ocr.upload.image", comment: "")) {
                    if settingsManager.isLoggedIn {
                        imageSourceType = .photoLibrary
                        showingImagePicker = true
                    } else {
                        showingLoginPrompt = true
                    }
                }
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, isPresented: $showingImagePicker, sourceType: imageSourceType)
                    .ignoresSafeArea(.all)
                    .background(Color.black)
            }
            .onChange(of: selectedImage) { newValue in
                if let image = newValue {
                    processSelectedImage(image)
                }
            }
        }
    }

    private var displayView: some View {
        VStack(spacing: 16) {
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
                            Text(NSLocalizedString("ocr.photo.attached", comment: ""))
                                .font(.subheadline)
                            Button(NSLocalizedString("ocr.change.photo", comment: "")) {
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
                    .disabled(isRecognizing)
                    .padding(10)
                    .background(Color.primaryBlue.opacity(0.1))
                    .cornerRadius(8)
                    .accessibilityLabel(NSLocalizedString("ocr.accessibility.label", comment: ""))
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
            syncStatus: WeightRecordSyncStatus.pending
        )

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
    
    private func processSelectedImage(_ image: UIImage) {
        selectedImage = image
        isRecognizing = true
        
        Task {
            do {
                let response = try await APIService.shared.recognizeWeightFromImage(image: image)
                await MainActor.run {
                    isRecognizing = false
                    if let weight = response.weight {
                        ocrWeight = weight
                        imageUrl = response.imageUrl
                        showingOCRResult = true
                    } else {
                        errorMessage = NSLocalizedString("ocr.no.weight.detected", comment: "")
                        showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isRecognizing = false
                    if let apiError = error as? APIError {
                        if apiError == .notLoggedIn {
                            showingLoginPrompt = true
                        } else {
                            errorMessage = apiError.errorDescription ?? NSLocalizedString("ocr.failed", comment: "")
                            showingError = true
                        }
                    } else {
                        errorMessage = NSLocalizedString("ocr.error.network", comment: "")
                        showingError = true
                    }
                }
            }
        }
    }

    private func confirmOCRResult() {
        if let weight = ocrWeight {
            weightInput = String(format: "%.1f", unit.convertFromKg(weight))
        }
        showingOCRResult = false
    }
}
