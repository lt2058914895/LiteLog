import SwiftUI
import CoreData
import os
import UniformTypeIdentifiers

struct SettingsView: View {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "SettingsView")
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var notificationManager = NotificationManager.shared

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.id, ascending: true)]) private var userProfile: FetchedResults<UserProfile>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>

    @State private var showingProfileEditor = false
    @State private var showingUserInfoEditor = false
    @State private var exportURL: IdentifiableURL?
    @State private var showingRestorePicker = false
    @State private var dataConfirmation: DataConfirmation?
    @State private var dataOperationAlert: DataOperationAlert?
    @State private var showingContact = false
    
    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    var body: some View {
        NavigationStack {
            List {
                userHeaderSection
                
                profileSection

                notificationSection

                actionSection
                
                dataSection

                aboutSection
            }
            .navigationBarHidden(true)
            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 800 : 600, alignment: .center)
            .navigationDestination(isPresented: $showingProfileEditor) {
                ProfileEditorView()
            }
            .navigationDestination(isPresented: $showingUserInfoEditor) {
                UserInfoEditorView()
            }
            .navigationDestination(isPresented: $showingContact) {
                ContactView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showProfileEditor)) { _ in
                    showingProfileEditor = true
                }
                .adaptiveSheet(item: $exportURL) { url in
                    ShareSheet(items: [url.url])
                }
                .alert(item: $dataOperationAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text(NSLocalizedString("action.ok", comment: "")))
                    )
                }
                .confirmationDialog(
                    dataConfirmation?.title ?? "",
                    isPresented: Binding(
                        get: { dataConfirmation != nil },
                        set: { if !$0 { dataConfirmation = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    switch dataConfirmation {
                    case .restore:
                        Button(NSLocalizedString("settings.restore.continue", comment: "")) {
                            dataConfirmation = nil
                            showingRestorePicker = true
                        }
                    case .delete:
                        Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                            dataConfirmation = nil
                            deleteAllData()
                        }
                    case nil:
                        EmptyView()
                    }
                    Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                } message: {
                    Text(dataConfirmation?.message ?? "")
                }
                .fileImporter(
                    isPresented: $showingRestorePicker,
                    allowedContentTypes: [.json],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            restoreBackup(from: url)
                        }
                    case .failure(let error):
                        dataOperationAlert = .restoreFailed(error.localizedDescription)
                    }
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
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settingsManager.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        
        @ViewBuilder
        private var avatarImageView: some View {
            if let image = settingsManager.avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .id(settingsManager.avatarUpdatedToken)
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
                Button(action: { showingProfileEditor = true }) {
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            Text(UserProfile.Gender(rawValue: profile.gender)?.displayName ?? "")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            Text("\(profile.age) \(NSLocalizedString("common.years", comment: ""))")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(NSLocalizedString("common.height", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                                Text("\(profile.height.smartFormatted) \(NSLocalizedString("unit.cm", comment: ""))")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                        }
                        
                        Divider()
                        
                        VStack(spacing: 10) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("goal.weight", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                    Text("\(profile.goalWeightValue.map { unit.convertFromKg($0).smartFormatted } ?? "--") \(unit.shortName)")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primaryBlue)
                                }
                                
                                Spacer()
                                
                                if let goalBodyFat = profile.goalBodyFatPercentage {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(NSLocalizedString("goal.body.fat", comment: ""))
                                            .font(.caption)
                                            .foregroundColor(.secondaryText)
                                        Text("\(goalBodyFat.smartFormatted)%")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primaryText)
                                    }
                                }
                            }
                            
                            if profile.hasGoalMeasurements {
                                VStack(spacing: 8) {
                                    Divider()
                                    
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(NSLocalizedString("measure.waist", comment: ""))
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                            if let waist = profile.goalWaistCircumferenceValue {
                                                Text("\(waist.smartFormatted) cm")
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primaryText)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(NSLocalizedString("measure.hip", comment: ""))
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                            if let hip = profile.goalHipCircumferenceValue {
                                                Text("\(hip.smartFormatted) cm")
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primaryText)
                                            }
                                        }
                                    }
                                    
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(NSLocalizedString("measure.chest", comment: ""))
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                            if let chest = profile.goalChestCircumferenceValue {
                                                Text("\(chest.smartFormatted) cm")
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primaryText)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(NSLocalizedString("measure.thigh", comment: ""))
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                            if let thigh = profile.goalThighCircumferenceValue {
                                                Text("\(thigh.smartFormatted) cm")
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primaryText)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            
            Button(action: { showingProfileEditor = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .foregroundColor(.primaryBlue)
                        .font(.title3)
                    Text(NSLocalizedString("action.edit", comment: ""))
                        .foregroundColor(.primaryBlue)
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondaryText)
                }
                .padding(.vertical, 8)
            }
        }
    }


    private var notificationSection: some View {
        Section {
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
            Menu {
                Button(action: { exportData(format: .csv) }) {
                    Label(NSLocalizedString("settings.export.csv", comment: ""), systemImage: "filetype.csv")
                }
                Button(action: { exportData(format: .json) }) {
                    Label(NSLocalizedString("settings.export.json", comment: ""), systemImage: "filetype.json")
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundColor(.primaryBlue)
                    Text(NSLocalizedString("settings.export", comment: ""))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondaryText)
                }
            }

            Button(action: { dataConfirmation = .restore }) {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                        .foregroundColor(.primaryBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("settings.restore", comment: ""))
                            .foregroundColor(.primary)
                        Text(NSLocalizedString("settings.restore.desc", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }

            Button(role: .destructive, action: { dataConfirmation = .delete }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text(NSLocalizedString("settings.delete.all", comment: ""))
                        .foregroundColor(.primary)
                }
            }
        } footer: {
            Text(NSLocalizedString("settings.backup.hint", comment: ""))
        }
    }

    private var actionSection: some View {
        Section {
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
                if let url = URL(string: "https://apps.apple.com/app/id6768547821") {
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
                if let url = URL(string: "https://apps.apple.com/app/id6768547821") {
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
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                    .foregroundColor(.secondaryText)
            }
        }
    }

    private func exportData(format: ExportManager.ExportFormat) {
        guard format != .csv || !records.isEmpty else {
            dataOperationAlert = .exportFailed
            return
        }
        
        if let url = ExportManager.shared.export(
            records: Array(records),
            profile: profile,
            settings: settingsManager,
            unit: unit,
            format: format
        ) {
            exportURL = IdentifiableURL(url)
        } else {
            dataOperationAlert = .exportFailed
        }
    }

    private func restoreBackup(from url: URL) {
        do {
            let recordCount = try LocalBackupManager.shared.restoreBackup(
                from: url,
                context: context,
                settings: settingsManager
            )
            dataOperationAlert = .restoreSucceeded(recordCount)
        } catch {
            dataOperationAlert = .restoreFailed(error.localizedDescription)
        }
    }

    private func deleteAllData() {
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
            settingsManager.removeAvatar()
            settingsManager.nickname = ""
            removeLegacyRecordImages()
        } catch {
            Self.logger.error("Failed to delete all data: \(error.localizedDescription)")
        }
    }

    private func removeLegacyRecordImages() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        try? FileManager.default.removeItem(at: imagesDirectory)
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

private enum DataOperationAlert: Identifiable {
    case exportFailed
    case restoreSucceeded(Int)
    case restoreFailed(String)

    var id: String {
        switch self {
        case .exportFailed:
            return "exportFailed"
        case .restoreSucceeded:
            return "restoreSucceeded"
        case .restoreFailed:
            return "restoreFailed"
        }
    }

    var title: String {
        switch self {
        case .exportFailed:
            return NSLocalizedString("settings.export.error", comment: "")
        case .restoreSucceeded:
            return NSLocalizedString("settings.restore.success.title", comment: "")
        case .restoreFailed:
            return NSLocalizedString("settings.restore.error.title", comment: "")
        }
    }

    var message: String {
        switch self {
        case .exportFailed:
            return NSLocalizedString("settings.export.error.message", comment: "")
        case .restoreSucceeded(let count):
            return String(
                format: NSLocalizedString("settings.restore.success.message", comment: ""),
                count
            )
        case .restoreFailed(let message):
            return message
        }
    }
}

private enum DataConfirmation {
    case restore
    case delete

    var title: String {
        switch self {
        case .restore:
            return NSLocalizedString("settings.restore", comment: "")
        case .delete:
            return NSLocalizedString("settings.delete.all", comment: "")
        }
    }

    var message: String {
        switch self {
        case .restore:
            return NSLocalizedString("settings.restore.confirm", comment: "")
        case .delete:
            return NSLocalizedString("settings.delete.confirm", comment: "")
        }
    }
}
