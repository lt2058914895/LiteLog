import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var notificationManager = NotificationManager.shared

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.id, ascending: true)]) private var userProfile: FetchedResults<UserProfile>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>

    @State private var showingProfileEditor = false
    @State private var showingUserInfoEditor = false
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var exportURL: IdentifiableURL?
    @State private var showingExportError = false
    @State private var notificationTime = SettingsManager.defaultNotificationTime()
    @State private var showingFeedback = false
    @State private var showingContact = false
    
    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    var body: some View {
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
        .fullScreenCover(isPresented: $showingProfileEditor) {
            ProfileEditorView()
        }
        .fullScreenCover(isPresented: $showingUserInfoEditor) {
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
        .fullScreenCover(isPresented: $showingFeedback) {
            FeedbackView()
        }
        .fullScreenCover(isPresented: $showingContact) {
            ContactView()
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
            Button(action: {
                showingFeedback = true
            }) {
                HStack {
                    Image(systemName: "message.badge.filled.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("settings.send.feedback", comment: ""))
                        .foregroundColor(.primary)
                    Spacer()
                }
            }

            Button(action: {
                showingContact = true
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.primaryBlue)
                    Text(NSLocalizedString("settings.contact", comment: ""))
                        .foregroundColor(.primary)
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
