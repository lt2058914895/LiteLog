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
    @State private var showingFeedbackSheet = false
    @State private var showingLoginSheet = false
    
    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    var body: some View {
        NavigationStack {
            List {
                userHeaderSection
                
                profileSection

                unitSection

                syncSection

                notificationSection

                dataSection

                feedbackSection

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
            .fullScreenCover(isPresented: $showingFeedbackSheet) {
                FeedbackView()
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
                AsyncImage(url: URL(string: settingsManager.avatarUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                    case .failure, .empty:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 54, height: 54)
                            .foregroundColor(.primaryBlue)
                    @unknown default:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 54, height: 54)
                            .foregroundColor(.primaryBlue)
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 54, height: 54)
                    .foregroundColor(.gray)
            }
        }
        
        private var profileSection: some View {
        Section(NSLocalizedString("settings.profile", comment: "")) {
            if let profile = profile {
                HStack {
                    Label {
                        Text(NSLocalizedString("settings.height", comment: ""))
                    } icon: {
                        Image(systemName: "ruler")
                            .foregroundColor(.primaryBlue)
                    }

                    Spacer()

                    Text("\(settingsManager.heightUnit.convertFromCm(profile.height).formatted()) \(settingsManager.heightUnit.displayName)")
                        .foregroundColor(.secondaryText)
                }

                HStack {
                    Label {
                        Text(NSLocalizedString("settings.gender", comment: ""))
                    } icon: {
                        Image(systemName: profile.gender == .male ? "person.fill" : "person.fill")
                            .foregroundColor(.primaryBlue)
                    }

                    Spacer()

                    Text(profile.gender.displayName)
                        .foregroundColor(.secondaryText)
                }

                HStack {
                    Label {
                        Text(NSLocalizedString("settings.age", comment: ""))
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundColor(.primaryBlue)
                    }

                    Spacer()

                    Text("\(profile.age)")
                        .foregroundColor(.secondaryText)
                }

                HStack {
                    Label {
                        Text(NSLocalizedString("settings.goal.weight", comment: ""))
                    } icon: {
                        Image(systemName: "target")
                            .foregroundColor(.primaryBlue)
                    }

                    Spacer()

                    Text("\(unit.convertFromKg(profile.goalWeight).weightString) \(unit.shortName)")
                        .foregroundColor(.secondaryText)
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

    private var syncSection: some View {
        Section(NSLocalizedString("settings.icloud", comment: "")) {
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
        }
    }

    private var notificationSection: some View {
        Section(NSLocalizedString("settings.notification", comment: "")) {
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
        Section(NSLocalizedString("settings.export", comment: "")) {
            Button(action: exportData) {
                Label(NSLocalizedString("settings.export.csv", comment: ""), systemImage: "square.and.arrow.up")
                    .foregroundColor(.primaryBlue)
            }

            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                Label(NSLocalizedString("settings.delete.all", comment: ""), systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }

    private var feedbackSection: some View {
        Section(NSLocalizedString("settings.feedback", comment: "")) {
            Button(action: { showingFeedbackSheet = true }) {
                Label(NSLocalizedString("settings.send.feedback", comment: ""), systemImage: "message.badge")
                    .foregroundColor(.primaryBlue)
            }
        }
    }

    private var aboutSection: some View {
        Section(NSLocalizedString("settings.about", comment: "")) {
            HStack {
                Text(NSLocalizedString("settings.version", comment: ""))
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondaryText)
            }

            HStack {
                Text(NSLocalizedString("app.name", comment: ""))
                Spacer()
                Text("轻身记")
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

        if let existing = existingProfile {
            existing.height = heightInCm
            existing.gender = gender
            existing.age = age
            existing.goalWeight = goalWeightInKg
            existing.updatedAt = Date()
        } else {
            let newProfile = UserProfile(
                height: heightInCm,
                gender: gender,
                age: age,
                goalWeight: goalWeightInKg
            )
            modelContext.insert(newProfile)
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
