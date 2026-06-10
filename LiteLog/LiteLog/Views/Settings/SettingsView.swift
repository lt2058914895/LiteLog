import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var notificationManager = NotificationManager.shared

    @Query private var userProfile: [UserProfile]
    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]

    @State private var showingProfileEditor = false
    @State private var showingUserInfoEditor = false
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var exportURL: URL?
    @State private var showingExportError = false
    @State private var notificationTime = SettingsManager.defaultNotificationTime()
    @State private var showingLoginSheet = false
    
    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    var body: some View {
        NavigationStack {
            List {
                userHeaderSection
                
                profileSection

                unitSection

                syncNotificationSection

                actionSection
                
                dataSection

                aboutSection
            }
            .navigationBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .showProfileEditor)) { _ in
                showingProfileEditor = true
            }
            .adaptiveSheet(isPresented: $showingProfileEditor) {
                ProfileEditorView()
            }
            .adaptiveSheet(isPresented: $showingUserInfoEditor) {
                UserInfoEditorView()
            }
            .adaptiveSheet(item: $exportURL) { url in
                ShareSheet(items: [url])
            }
            .adaptiveSheet(isPresented: $showingLoginSheet) {
                LoginView()
            }
            .alert(NSLocalizedString("settings.delete.confirm", comment: ""), isPresented: $showingDeleteAlert) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                    deleteAllData()
                }
            }
            .alert(NSLocalizedString("settings.export.error", comment: ""), isPresented: $showingExportError) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            }
        }
    }

    private var userHeaderSection: some View {
            Section {
                Button(action: {
                    if settingsManager.isLoggedIn {
                        showingUserInfoEditor = true
                    } else {
                        showingLoginSheet = true
                    }
                }) {
                    HStack(alignment: .center, spacing: 16) {
                        avatarImageView
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settingsManager.isLoggedIn ? settingsManager.displayName : NSLocalizedString("settings.not.logged.in", comment: ""))
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondaryText)
                    }
                }
            }
        }
        
        @ViewBuilder
        private var avatarImageView: some View {
            if settingsManager.isLoggedIn, !settingsManager.avatarUrl.isEmpty {
                // 优先使用缓存的头像，提升加载速度
                if let cachedImage = settingsManager.cachedAvatarImage {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        // 默认头像作为占位符
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 54, height: 54)
                            .foregroundColor(.primaryBlue)
                        
                        // 异步加载并缓存
                        AsyncImage(url: URL(string: settingsManager.avatarUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 54, height: 54)
                                    .clipShape(Circle())
                            case .failure, .empty:
                                EmptyView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .onAppear {
                            // 在后台异步加载并缓存头像
                            Task {
                                await loadAndCacheAvatar()
                            }
                        }
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 54, height: 54)
                    .foregroundColor(.gray)
            }
        }
        
        private func loadAndCacheAvatar() async {
            guard !settingsManager.avatarUrl.isEmpty, settingsManager.cachedAvatarImage == nil else { return }
            
            if let url = URL(string: settingsManager.avatarUrl), 
               let data = try? Data(contentsOf: url), 
               let image = UIImage(data: data) {
                settingsManager.updateCachedAvatar(with: image)
            }
        }
        
        private var profileSection: some View {
        Section(NSLocalizedString("settings.profile", comment: "")) {
            if let profile = profile {
                HStack {
                    Text(NSLocalizedString("settings.height", comment: ""))
                    Spacer()
                    Text("\(settingsManager.heightUnit.convertFromCm(profile.height).formatted()) \(settingsManager.heightUnit.displayName)")
                        .foregroundColor(.secondaryText)
                }

                HStack {
                    Text(NSLocalizedString("settings.gender", comment: ""))
                    Spacer()
                    Text(profile.gender.displayName)
                        .foregroundColor(.secondaryText)
                }

                HStack {
                    Text(NSLocalizedString("settings.age", comment: ""))
                    Spacer()
                    Text("\(profile.age)")
                        .foregroundColor(.secondaryText)
                }

                HStack {
                    Text(NSLocalizedString("settings.goal.weight", comment: ""))
                    Spacer()
                    Text("\(unit.convertFromKg(profile.goalWeight).weightString) \(unit.shortName)")
                        .foregroundColor(.secondaryText)
                }

                if let goalBodyFat = profile.goalBodyFat {
                    HStack {
                        Text(NSLocalizedString("settings.goal.body.fat", comment: ""))
                        Spacer()
                        Text("\(goalBodyFat.formatted())%")
                            .foregroundColor(.secondaryText)
                    }
                }

                if let goalWaistCircumference = profile.goalWaistCircumference {
                    HStack {
                        Text(NSLocalizedString("settings.goal.waist", comment: ""))
                        Spacer()
                        Text("\(goalWaistCircumference.formatted()) \(NSLocalizedString("settings.cm", comment: ""))")
                            .foregroundColor(.secondaryText)
                    }
                }

                if let goalHipCircumference = profile.goalHipCircumference {
                    HStack {
                        Text(NSLocalizedString("settings.goal.hip", comment: ""))
                        Spacer()
                        Text("\(goalHipCircumference.formatted()) \(NSLocalizedString("settings.cm", comment: ""))")
                            .foregroundColor(.secondaryText)
                    }
                }

                if let goalChestCircumference = profile.goalChestCircumference {
                    HStack {
                        Text(NSLocalizedString("settings.goal.chest", comment: ""))
                        Spacer()
                        Text("\(goalChestCircumference.formatted()) \(NSLocalizedString("settings.cm", comment: ""))")
                            .foregroundColor(.secondaryText)
                    }
                }
            }

            Button(action: { showingProfileEditor = true }) {
                Label(NSLocalizedString("action.edit", comment: ""), systemImage: "pencil")
                    .foregroundColor(.primaryBlue)
            }
        }
    }

    private var unitSection: some View {
        Section(NSLocalizedString("settings.unit", comment: "")) {
            Picker(NSLocalizedString("settings.unit", comment: ""), selection: $settingsManager.weightUnit) {
                ForEach(WeightUnit.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
        }
    }

    private var syncNotificationSection: some View {
        Section {
            Toggle(isOn: $settingsManager.iCloudSyncEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("settings.icloud", comment: ""))
                        Text(NSLocalizedString("settings.icloud.desc", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                } icon: {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(.primaryBlue)
                }
            }

            Toggle(isOn: $settingsManager.notificationsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("settings.notification", comment: ""))
                        Text(NSLocalizedString("settings.notification.desc", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                } icon: {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                }
            }
            .onChange(of: settingsManager.notificationsEnabled) { _, newValue in
                if newValue {
                    Task {
                        try? await notificationManager.requestAuthorization()
                        if notificationManager.isAuthorized {
                            try? await notificationManager.scheduleDailyReminder(at: settingsManager.notificationTime)
                        }
                    }
                } else {
                    Task {
                        await notificationManager.cancelDailyReminder()
                    }
                }
            }

            if settingsManager.notificationsEnabled {
                DatePicker(
                    NSLocalizedString("settings.notification.time", comment: ""),
                    selection: $settingsManager.notificationTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: settingsManager.notificationTime) { _, newValue in
                    Task {
                        try? await notificationManager.scheduleDailyReminder(at: newValue)
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        Section {
            Button(action: exportData) {
                HStack {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundColor(.primaryBlue)
                    Text(NSLocalizedString("settings.export.csv", comment: ""))
                        .foregroundColor(.primary)
                }
            }

            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text(NSLocalizedString("settings.delete.all", comment: ""))
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private var actionSection: some View {
        Section {
            NavigationLink(destination: FeedbackView()) {
                HStack {
                    Image(systemName: "message.badge.filled.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("settings.send.feedback", comment: ""))
                    Spacer()
                }
            }

            NavigationLink(destination: ContactView()) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.primaryBlue)
                    Text(NSLocalizedString("settings.contact", comment: ""))
                    Spacer()
                }
            }

            Button(action: {
                if let url = URL(string: "https://apps.apple.com/cn/app/6768547821") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("settings.rate", comment: ""))
                        .foregroundColor(.primary)
                    Spacer()
                    HStack(spacing: 1) {
                        ForEach(0..<5) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                }
            }

            Button(action: {
                if let url = URL(string: "https://apps.apple.com/cn/app/6768547821") {
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true)
                }
            }) {
                HStack {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .foregroundColor(.primaryBlue)
                    Text(NSLocalizedString("settings.share", comment: ""))
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray)
                Text(NSLocalizedString("settings.version", comment: ""))
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondaryText)
            }
        }
    }

    private func exportData() {
        guard !records.isEmpty else {
            showingExportError = true
            return
        }
        
        if let url = ExportManager.shared.exportToCSV(records: records, unit: unit) {
            exportURL = url
        } else {
            showingExportError = true
        }
    }

    private func deleteAllData() {
        // 删除体重记录
        let recordIds = records.map { $0.id.uuidString }
        for record in records {
            modelContext.delete(record)
        }
        
        // 删除个人资料数据
        let profileFetch = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(profileFetch) {
            for profile in profiles {
                modelContext.delete(profile)
            }
        }

        do {
            try modelContext.save()
            // 同步删除到云数据库
            Task {
                await DataSyncManager.shared.syncDeletedRecords(recordIds: recordIds)
            }
        } catch {
            print("Failed to delete all data: \(error)")
        }
    }
}

struct ProfileEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query private var userProfile: [UserProfile]

    @State private var heightString: String = ""
    @State private var gender: UserProfile.Gender = .male
    @State private var age: Int = 30
    @State private var goalWeightString: String = ""
    @State private var goalBodyFatString: String = ""
    @State private var goalWaistCircumferenceString: String = ""
    @State private var goalHipCircumferenceString: String = ""
    @State private var goalChestCircumferenceString: String = ""
    @State private var showingValidationAlert = false
    @State private var validationErrorMessage = ""

    private var existingProfile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }
    private var heightUnit: HeightUnit { settingsManager.heightUnit }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("settings.height", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("settings.height", comment: ""), text: $heightString)
                            .keyboardType(.decimalPad)

                        Text(heightUnit.displayName)
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("settings.gender", comment: "")) {
                    Picker(NSLocalizedString("settings.gender", comment: ""), selection: $gender) {
                        Text(NSLocalizedString("settings.male", comment: "")).tag(UserProfile.Gender.male)
                        Text(NSLocalizedString("settings.female", comment: "")).tag(UserProfile.Gender.female)
                    }
                    .pickerStyle(.segmented)
                }

                Section(NSLocalizedString("settings.age", comment: "")) {
                    Stepper("\(age)", value: $age, in: 1...120)
                }

                Section(NSLocalizedString("settings.goal.weight", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("settings.goal.weight", comment: ""), text: $goalWeightString)
                            .keyboardType(.decimalPad)

                        Text(unit.shortName)
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("settings.goal.body.fat", comment: "")) {
                    HStack {
                        TextField(NSLocalizedString("settings.goal.body.fat", comment: ""), text: $goalBodyFatString)
                            .keyboardType(.decimalPad)

                        Text("%")
                            .foregroundColor(.secondaryText)
                    }
                }

                Section(NSLocalizedString("settings.goal.measurements", comment: "")) {
                    HStack {
                        Text(NSLocalizedString("settings.goal.waist", comment: ""))
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("", text: $goalWaistCircumferenceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(NSLocalizedString("settings.cm", comment: ""))
                            .foregroundColor(.secondaryText)
                    }

                    HStack {
                        Text(NSLocalizedString("settings.goal.hip", comment: ""))
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("", text: $goalHipCircumferenceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(NSLocalizedString("settings.cm", comment: ""))
                            .foregroundColor(.secondaryText)
                    }

                    HStack {
                        Text(NSLocalizedString("settings.goal.chest", comment: ""))
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("", text: $goalChestCircumferenceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)

                        Text(NSLocalizedString("settings.cm", comment: ""))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("settings.profile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .alert(NSLocalizedString("settings.error", comment: ""), isPresented: $showingValidationAlert) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(validationErrorMessage)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.save", comment: "")) {
                        saveProfile()
                    }
                }
            }
            .onAppear {
                loadExistingProfile()
            }
        }
    }

    private func loadExistingProfile() {
        if let profile = existingProfile {
            heightString = heightUnit.convertFromCm(profile.height).formatted()
            gender = profile.gender
            age = profile.age
            goalWeightString = unit.convertFromKg(profile.goalWeight).formatted()
            goalBodyFatString = profile.goalBodyFat?.formatted() ?? ""
            goalWaistCircumferenceString = profile.goalWaistCircumference?.formatted() ?? ""
            goalHipCircumferenceString = profile.goalHipCircumference?.formatted() ?? ""
            goalChestCircumferenceString = profile.goalChestCircumference?.formatted() ?? ""
        }
    }

    private func saveProfile() {
        var errors: [String] = []
        
        if heightString.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(NSLocalizedString("settings.height.required", comment: ""))
        } else if let heightValue = Double(heightString), heightValue <= 0 {
            errors.append(NSLocalizedString("settings.height.invalid", comment: ""))
        }
        
        if goalWeightString.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(NSLocalizedString("settings.goal.weight.required", comment: ""))
        } else if let goalWeightValue = Double(goalWeightString), goalWeightValue <= 0 {
            errors.append(NSLocalizedString("settings.goal.weight.invalid", comment: ""))
        }
        
        if !goalBodyFatString.isEmpty {
            if let bodyFatValue = Double(goalBodyFatString), (bodyFatValue <= 0 || bodyFatValue >= 100) {
                errors.append(NSLocalizedString("settings.goal.body.fat.invalid", comment: ""))
            }
        }
        
        if !goalWaistCircumferenceString.isEmpty {
            if let waistValue = Double(goalWaistCircumferenceString), waistValue <= 0 {
                errors.append(NSLocalizedString("settings.goal.waist.circumference.invalid", comment: ""))
            }
        }
        
        if !goalHipCircumferenceString.isEmpty {
            if let hipValue = Double(goalHipCircumferenceString), hipValue <= 0 {
                errors.append(NSLocalizedString("settings.goal.hip.circumference.invalid", comment: ""))
            }
        }
        
        if !goalChestCircumferenceString.isEmpty {
            if let chestValue = Double(goalChestCircumferenceString), chestValue <= 0 {
                errors.append(NSLocalizedString("settings.goal.chest.circumference.invalid", comment: ""))
            }
        }
        
        if !errors.isEmpty {
            validationErrorMessage = errors.joined(separator: "\n")
            showingValidationAlert = true
            return
        }

        guard let heightValue = Double(heightString),
              let goalWeightValue = Double(goalWeightString) else {
            return
        }

        let heightInCm = heightUnit.convertToCm(heightValue)
        let goalWeightInKg = unit.convertToKg(goalWeightValue)
        let goalBodyFat = Double(goalBodyFatString)
        let goalWaistCircumference = Double(goalWaistCircumferenceString)
        let goalHipCircumference = Double(goalHipCircumferenceString)
        let goalChestCircumference = Double(goalChestCircumferenceString)

        if let existing = existingProfile {
            existing.height = heightInCm
            existing.gender = gender
            existing.age = age
            existing.goalWeight = goalWeightInKg
            existing.goalBodyFat = goalBodyFat
            existing.goalWaistCircumference = goalWaistCircumference
            existing.goalHipCircumference = goalHipCircumference
            existing.goalChestCircumference = goalChestCircumference
            existing.updatedAt = Date()
            existing.syncStatus = .pending
        } else {
            let newProfile = UserProfile(
                height: heightInCm,
                gender: gender,
                age: age,
                goalWeight: goalWeightInKg,
                goalBodyFat: goalBodyFat,
                goalWaistCircumference: goalWaistCircumference,
                goalHipCircumference: goalHipCircumference,
                goalChestCircumference: goalChestCircumference,
                weightUnit: SettingsManager.shared.weightUnit.rawValue,
                syncStatus: UserProfileSyncStatus.pending
            )
            modelContext.insert(newProfile)
        }
        
        do {
            try modelContext.save()
            // 触发同步到云数据库
            DataSyncManager.shared.triggerProfileSync(modelContext: modelContext)
        } catch {
            print("保存个人资料失败: \(error)")
        }

        dismiss()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // iPad support - configure popover presentation
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Make URL conform to Identifiable for sheet(item:)
extension URL: Identifiable {
    public var id: String { absoluteString }
}
