import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var notificationManager = NotificationManager.shared

    @FetchRequest private var userProfile: FetchedResults<UserProfile>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>
    
    init() {
        _userProfile = FetchRequest(fetchRequest: UserProfile.fetchRequest())
    }

    @State private var showingProfileEditor = false
    @State private var showingUserInfoEditor = false
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var exportURL: IdentifiableURL?
    @State private var showingExportError = false
    @State private var notificationTime = SettingsManager.defaultNotificationTime()
    
    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    var body: some View {
        NavigationView {
            List {
                userHeaderSection
                
                profileSection

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
                ShareSheet(items: [url.url])
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
                    showingUserInfoEditor = true
                }) {
                    HStack(alignment: .center, spacing: 16) {
                        avatarImageView
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settingsManager.displayName)
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
            if !settingsManager.avatarUrl.isEmpty {
                if let cachedImage = settingsManager.cachedAvatarImage {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 54, height: 54)
                            .foregroundColor(.primaryBlue)
                        
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
            
            guard let url = URL(string: settingsManager.avatarUrl) else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        settingsManager.updateCachedAvatar(with: image)
                    }
                }
            } catch {
                print("Failed to load avatar: \(error)")
            }
        }
        
        private var profileSection: some View {
        Section(NSLocalizedString("settings.profile", comment: "")) {
            if let profile = profile {
                HStack {
                    Text(NSLocalizedString("settings.height", comment: ""))
                    Spacer()
                    Text("\(settingsManager.heightUnit.convertFromCm(profile.height).smartFormatted) \(settingsManager.heightUnit.displayName)")
                        .foregroundColor(.secondaryText)
                }

                HStack {
                    Text(NSLocalizedString("settings.gender", comment: ""))
                    Spacer()
                    Text(UserProfile.Gender(rawValue: profile.gender)?.displayName ?? "")
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
                    Text("\(unit.convertFromKg(profile.goalWeight).smartFormatted) \(unit.shortName)")
                        .foregroundColor(.secondaryText)
                }

                if let goalBodyFat = profile.goalBodyFatPercentage {
                    HStack {
                        Text(NSLocalizedString("settings.goal.body.fat", comment: ""))
                        Spacer()
                        Text("\(goalBodyFat.smartFormatted)%")
                            .foregroundColor(.secondaryText)
                    }
                }

                if let goalWaistCircumference = profile.goalWaistCircumferenceValue {
                    HStack {
                        Text(NSLocalizedString("settings.goal.waist", comment: ""))
                        Spacer()
                        Text("\(goalWaistCircumference.smartFormatted) \(NSLocalizedString("settings.cm", comment: ""))")
                            .foregroundColor(.secondaryText)
                    }
                }

                if let goalHipCircumference = profile.goalHipCircumferenceValue {
                    HStack {
                        Text(NSLocalizedString("settings.goal.hip", comment: ""))
                        Spacer()
                        Text("\(goalHipCircumference.smartFormatted) \(NSLocalizedString("settings.cm", comment: ""))")
                            .foregroundColor(.secondaryText)
                    }
                }

                if let goalChestCircumference = profile.goalChestCircumferenceValue {
                    HStack {
                        Text(NSLocalizedString("settings.goal.chest", comment: ""))
                        Spacer()
                        Text("\(goalChestCircumference.smartFormatted) \(NSLocalizedString("settings.cm", comment: ""))")
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
            .onChange(of: settingsManager.notificationsEnabled) { newValue in
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
                .onChange(of: settingsManager.notificationTime) { newValue in
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
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(activityVC, animated: true)
                }
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
        
        if let url = ExportManager.shared.exportToCSV(records: Array(records), unit: unit) {
            exportURL = IdentifiableURL(url)
        } else {
            showingExportError = true
        }
    }

    private func deleteAllData() {
        let recordIds = records.map { $0.id.uuidString }
        for record in records {
            context.delete(record)
        }
        
        let profileFetch = UserProfile.fetchRequest()
        if let profiles = try? context.fetch(profileFetch) {
            for profile in profiles {
                context.delete(profile)
            }
        }

        do {
            try context.save()
            Task {
                await DataSyncManager.shared.syncDeletedRecords(recordIds: recordIds)
            }
        } catch {
            print("Failed to delete all data: \(error)")
        }
    }
}

struct ProfileEditorView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest private var userProfile: FetchedResults<UserProfile>
    
    init() {
        _userProfile = FetchRequest(fetchRequest: UserProfile.fetchRequest())
    }

    @State private var heightString: String = ""
    @State private var gender: UserProfile.Gender = .male
    @State private var age: Int = 30
    @State private var goalWeightString: String = ""
    @State private var goalBodyFatString: String = ""
    @State private var goalWaistCircumferenceString: String = ""
    @State private var goalHipCircumferenceString: String = ""
    @State private var goalChestCircumferenceString: String = ""
    @State private var goalThighCircumferenceString: String = ""
    @State private var showingValidationAlert = false
    @State private var validationErrorMessage = ""

    private var existingProfile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }
    private var heightUnit: HeightUnit { settingsManager.heightUnit }

    var body: some View {
        Form {
            Section(NSLocalizedString("settings.height", comment: "")) {
                HStack {
                    NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $heightString)
                    
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
                    NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalWeightString)
                    
                    Text(unit.shortName)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Section(NSLocalizedString("settings.goal.body.fat", comment: "")) {
                HStack {
                    NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalBodyFatString)
                    
                    Text("%")
                        .foregroundColor(.secondaryText)
                }
            }
            
            Section(NSLocalizedString("settings.goal.measurements", comment: "")) {
                HStack {
                    Text(NSLocalizedString("settings.goal.waist", comment: ""))
                        .foregroundColor(.secondary)
                    Spacer()
                    NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalWaistCircumferenceString)
                        .multilineTextAlignment(.trailing)
                    Text(NSLocalizedString("settings.cm", comment: ""))
                        .foregroundColor(.secondaryText)
                }
                
                HStack {
                    Text(NSLocalizedString("settings.goal.hip", comment: ""))
                        .foregroundColor(.secondary)
                    Spacer()
                    NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalHipCircumferenceString)
                        .multilineTextAlignment(.trailing)
                    Text(NSLocalizedString("settings.cm", comment: ""))
                        .foregroundColor(.secondaryText)
                }
                
                HStack {
                    Text(NSLocalizedString("settings.goal.chest", comment: ""))
                        .foregroundColor(.secondary)
                    Spacer()
                    NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalChestCircumferenceString)
                        .multilineTextAlignment(.trailing)
                    
                    Text(NSLocalizedString("settings.cm", comment: ""))
                        .foregroundColor(.secondaryText)
                }
                
                HStack {
                    Text(NSLocalizedString("settings.goal.thigh", comment: ""))
                        .foregroundColor(.secondary)
                    Spacer()
                    NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalThighCircumferenceString)
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

    private func loadExistingProfile() {
        if let profile = existingProfile {
            heightString = heightUnit.convertFromCm(profile.height).smartFormatted
            gender = profile.genderEnum
            age = Int(profile.age)
            goalWeightString = unit.convertFromKg(profile.goalWeight).smartFormatted
            goalBodyFatString = profile.goalBodyFatPercentage?.smartFormatted ?? ""
            goalWaistCircumferenceString = profile.goalWaistCircumferenceValue?.smartFormatted ?? ""
            goalHipCircumferenceString = profile.goalHipCircumferenceValue?.smartFormatted ?? ""
            goalChestCircumferenceString = profile.goalChestCircumferenceValue?.smartFormatted ?? ""
            goalThighCircumferenceString = profile.goalThighCircumferenceValue?.smartFormatted ?? ""
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
        
        if !goalThighCircumferenceString.isEmpty {
            if let thighValue = Double(goalThighCircumferenceString), thighValue <= 0 {
                errors.append(NSLocalizedString("settings.goal.thigh.circumference.invalid", comment: ""))
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
        let goalThighCircumference = Double(goalThighCircumferenceString)

        if let existing = existingProfile {
            existing.height = heightInCm
            existing.genderEnum = gender
            existing.age = Int16(age)
            existing.goalWeight = goalWeightInKg
            existing.goalBodyFat = goalBodyFat ?? 0
            existing.goalWaistCircumference = goalWaistCircumference ?? 0
            existing.goalHipCircumference = goalHipCircumference ?? 0
            existing.goalChestCircumference = goalChestCircumference ?? 0
            existing.goalThighCircumference = goalThighCircumference ?? 0
            existing.updatedAt = Date()
            existing.syncStatusEnum = .pending
        } else {
            let newProfile = UserProfile.create(in: context)
            newProfile.height = heightInCm
            newProfile.genderEnum = gender
            newProfile.age = Int16(age)
            newProfile.goalWeight = goalWeightInKg
            newProfile.goalBodyFat = goalBodyFat ?? 0
            newProfile.goalWaistCircumference = goalWaistCircumference ?? 0
            newProfile.goalHipCircumference = goalHipCircumference ?? 0
            newProfile.goalChestCircumference = goalChestCircumference ?? 0
            newProfile.goalThighCircumference = goalThighCircumference ?? 0
        }
        
        do {
            try context.save()
            DataSyncManager.shared.triggerProfileSync(context: context)
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
        
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
    
    init(_ url: URL) {
        self.url = url
    }
}
