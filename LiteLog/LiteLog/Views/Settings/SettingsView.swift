import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var notificationManager = NotificationManager.shared

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.id, ascending: true)]) private var userProfile: FetchedResults<UserProfile>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) private var records: FetchedResults<WeightRecord>

    @State private var showingProfileEditor = false
    @State private var showingUserInfoEditor = false
    @State private var showingContact = false
    @State private var showingExportOptions = false
    @State private var showingRestoreSheet = false
    @State private var showingRestorePicker = false
    @State private var pendingExportFormat: ExportManager.ExportFormat?
    @State private var restoreRequested = false
    @State private var exportURL: IdentifiableURL?
    @State private var settingsAlert: SettingsAlert?

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    profileHero
                    healthProfileSection
                    notificationSection
                    dataSection
                    supportSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 720 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
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
            .adaptiveSheet(item: $exportURL) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $showingExportOptions, onDismiss: handleExportSheetDismissed) {
                ExportOptionsSheet { format in
                    pendingExportFormat = format
                    showingExportOptions = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingRestoreSheet, onDismiss: handleRestoreSheetDismissed) {
                RestoreBackupSheet {
                    restoreRequested = true
                    showingRestoreSheet = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .alert(item: $settingsAlert) { alert in
                if case .notificationPermissionDenied = alert {
                    return Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        primaryButton: .default(Text(NSLocalizedString("settings.open.settings", comment: ""))) {
                            openNotificationSettings()
                        },
                        secondaryButton: .cancel(Text(NSLocalizedString("action.cancel", comment: "")))
                    )
                }
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(NSLocalizedString("action.ok", comment: "")))
                )
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
                    settingsAlert = .restoreFailed(error.localizedDescription)
                }
            }
            .task {
                await refreshNotificationAuthorization()
            }
        }
    }

    private var profileHero: some View {
        Button {
            HapticManager.light()
            showingUserInfoEditor = true
        } label: {
            HStack(spacing: 16) {
                avatarView(size: 68)
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))

                VStack(alignment: .leading, spacing: 6) {
                    Text(settingsManager.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.primaryBlue, Color(hex: "4FB6A8")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.primaryBlue.opacity(0.22), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("profile.title", comment: ""))
    }

    private var healthProfileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("settings.section.health")

            settingsCard {
                Button {
                    HapticManager.light()
                    showingProfileEditor = true
                } label: {
                    SettingsRowLabel(
                        icon: "heart.text.square.fill",
                        tint: .pink,
                        title: NSLocalizedString("settings.profile", comment: ""),
                        subtitle: profileSummary
                    )
                }
                .buttonStyle(.plain)

                if let profile {
                    divider

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        profileMetric(
                            title: NSLocalizedString("common.age", comment: ""),
                            value: "\(profile.age) \(NSLocalizedString("common.years", comment: ""))"
                        )
                        profileMetric(
                            title: NSLocalizedString("common.height", comment: ""),
                            value: "\(profile.height.smartFormatted) \(NSLocalizedString("unit.cm", comment: ""))"
                        )
                        profileMetric(
                            title: NSLocalizedString("goal.weight", comment: ""),
                            value: goalWeightText(profile)
                        )
                        profileMetric(
                            title: NSLocalizedString("goal.body.fat", comment: ""),
                            value: profile.goalBodyFatPercentage.map { "\($0.smartFormatted)%" } ??
                                NSLocalizedString("common.no.data", comment: "")
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("settings.section.notifications")

            settingsCard {
                HStack(spacing: 14) {
                    SettingsIcon(systemName: "bell.badge.fill", tint: .orange)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString("settings.notification", comment: ""))
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        Text(NSLocalizedString("settings.notification.desc", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle(
                        NSLocalizedString("settings.notification", comment: ""),
                        isOn: $settingsManager.notificationsEnabled
                    )
                    .labelsHidden()
                    .tint(.primaryBlue)
                }
                .padding(16)
                .onChange(of: settingsManager.notificationsEnabled) { enabled in
                    updateNotifications(enabled: enabled)
                }

                if settingsManager.notificationsEnabled {
                    divider

                    HStack(spacing: 14) {
                        SettingsIcon(systemName: "clock.fill", tint: .primaryBlue)

                        Text(NSLocalizedString("settings.notification.time", comment: ""))
                            .font(.body)
                            .foregroundColor(.primary)

                        Spacer()

                        DatePicker(
                            NSLocalizedString("settings.notification.time", comment: ""),
                            selection: $settingsManager.notificationTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .onChange(of: settingsManager.notificationTime) { date in
                            Task {
                                try? await notificationManager.scheduleDailyReminder(at: date)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("settings.section.data")

            settingsCard {
                Button {
                    HapticManager.light()
                    showingExportOptions = true
                } label: {
                    SettingsRowLabel(
                        icon: "square.and.arrow.up.fill",
                        tint: .green,
                        title: NSLocalizedString("settings.export", comment: ""),
                        subtitle: NSLocalizedString("settings.export.desc", comment: "")
                    )
                }
                .buttonStyle(.plain)

                divider

                Button {
                    HapticManager.light()
                    showingRestoreSheet = true
                } label: {
                    SettingsRowLabel(
                        icon: "arrow.counterclockwise.circle.fill",
                        tint: .primaryBlue,
                        title: NSLocalizedString("settings.restore", comment: ""),
                        subtitle: NSLocalizedString("settings.restore.desc", comment: "")
                    )
                }
                .buttonStyle(.plain)

            }

            Label(
                NSLocalizedString("settings.backup.hint", comment: ""),
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundColor(.secondaryText)
            .padding(.horizontal, 4)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("settings.section.support")

            settingsCard {
                Button {
                    HapticManager.light()
                    showingContact = true
                } label: {
                    SettingsRowLabel(
                        icon: "envelope.fill",
                        tint: .primaryBlue,
                        title: NSLocalizedString("settings.contact", comment: ""),
                        subtitle: NSLocalizedString("settings.contact.desc", comment: "")
                    )
                }
                .buttonStyle(.plain)

                divider

                Button {
                    HapticManager.light()
                    openAppStore()
                } label: {
                    SettingsRowLabel(
                        icon: "star.fill",
                        tint: .orange,
                        title: NSLocalizedString("settings.rate", comment: ""),
                        subtitle: NSLocalizedString("settings.rate.desc", comment: ""),
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)

                divider

                Button {
                    HapticManager.light()
                    shareApp()
                } label: {
                    SettingsRowLabel(
                        icon: "person.2.fill",
                        tint: .purple,
                        title: NSLocalizedString("settings.share", comment: ""),
                        subtitle: NSLocalizedString("settings.share.desc", comment: ""),
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutSection: some View {
        Text(
            String(
                format: NSLocalizedString("settings.version.format", comment: ""),
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3"
            )
        )
        .font(.caption)
        .foregroundColor(.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var profileSummary: String {
        guard profile != nil else {
            return NSLocalizedString("settings.profile.incomplete", comment: "")
        }
        return NSLocalizedString("settings.profile.edit.hint", comment: "")
    }

    private func goalWeightText(_ profile: UserProfile) -> String {
        guard let goal = profile.goalWeightValue else {
            return NSLocalizedString("common.no.data", comment: "")
        }
        return "\(unit.convertFromKg(goal).smartFormatted) \(unit.shortName)"
    }

    private func profileMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(.tertiarySystemGroupedBackground) : Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        if let image = settingsManager.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .id(settingsManager.avatarUpdatedToken)
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(NSLocalizedString(key, comment: ""))
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondaryText)
            .padding(.horizontal, 4)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(0.16), lineWidth: 1)
            )
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 58)
    }

    private func updateNotifications(enabled: Bool) {
        HapticManager.light()
        guard enabled else {
            Task {
                await notificationManager.cancelDailyReminder()
            }
            return
        }

        Task {
            do {
                try await notificationManager.requestAuthorization()
                await notificationManager.checkAuthorizationStatus()
                if notificationManager.isAuthorized {
                    try await notificationManager.scheduleDailyReminder(at: settingsManager.notificationTime)
                    HapticManager.success()
                } else {
                    settingsManager.notificationsEnabled = false
                    settingsAlert = .notificationPermissionDenied
                }
            } catch {
                settingsManager.notificationsEnabled = false
                settingsAlert = .notificationFailed(error.localizedDescription)
            }
        }
    }

    private func refreshNotificationAuthorization() async {
        guard settingsManager.notificationsEnabled else { return }
        await notificationManager.checkAuthorizationStatus()
        if !notificationManager.isAuthorized {
            settingsManager.notificationsEnabled = false
        }
    }

    private func handleExportSheetDismissed() {
        guard let format = pendingExportFormat else { return }
        pendingExportFormat = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exportData(format: format)
        }
    }

    private func handleRestoreSheetDismissed() {
        guard restoreRequested else { return }
        restoreRequested = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showingRestorePicker = true
        }
    }

    private func exportData(format: ExportManager.ExportFormat) {
        guard format != .csv || !records.isEmpty else {
            settingsAlert = .exportFailed
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
            settingsAlert = .exportFailed
        }
    }

    private func restoreBackup(from url: URL) {
        do {
            let recordCount = try LocalBackupManager.shared.restoreBackup(
                from: url,
                context: context,
                settings: settingsManager
            )
            HapticManager.success()
            settingsAlert = .restoreSucceeded(recordCount)
        } catch {
            settingsAlert = .restoreFailed(error.localizedDescription)
        }
    }

    private func openAppStore() {
        guard let url = URL(string: "https://apps.apple.com/app/id6768547821") else { return }
        UIApplication.shared.open(url)
    }

    private func shareApp() {
        guard let url = URL(string: "https://apps.apple.com/app/id6768547821"),
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        rootViewController.present(activity, animated: true)
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct SettingsIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct SettingsRowLabel: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    var showsChevron = true
    var titleColor: Color = .primary

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: icon, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(titleColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondaryText)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

private struct ExportOptionsSheet: View {
    let onSelect: (ExportManager.ExportFormat) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(NSLocalizedString("settings.export.sheet.desc", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        exportOption(
                            format: .json,
                            icon: "externaldrive.fill.badge.checkmark",
                            tint: .primaryBlue,
                            titleKey: "settings.export.json",
                            descriptionKey: "settings.export.json.desc"
                        )

                        exportOption(
                            format: .csv,
                            icon: "tablecells",
                            tint: .green,
                            titleKey: "settings.export.csv",
                            descriptionKey: "settings.export.csv.desc"
                        )
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("settings.export", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func exportOption(
        format: ExportManager.ExportFormat,
        icon: String,
        tint: Color,
        titleKey: String,
        descriptionKey: String
    ) -> some View {
        Button {
            onSelect(format)
        } label: {
            HStack(spacing: 14) {
                SettingsIcon(systemName: icon, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString(titleKey, comment: ""))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(NSLocalizedString(descriptionKey, comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondaryText)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RestoreBackupSheet: View {
    let onChooseBackup: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    SettingsIcon(systemName: "arrow.counterclockwise.circle.fill", tint: .primaryBlue)
                    Text(NSLocalizedString("settings.restore.desc", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.primaryText)
                }

                Label(
                    NSLocalizedString("settings.restore.confirm", comment: ""),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundColor(.orange)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                Button(action: onChooseBackup) {
                    Text(NSLocalizedString("settings.restore.continue", comment: ""))
                        .primaryButtonStyle()
                }
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("settings.restore", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(
                x: UIScreen.main.bounds.midX,
                y: UIScreen.main.bounds.midY,
                width: 0,
                height: 0
            )
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

private enum SettingsAlert: Identifiable {
    case exportFailed
    case restoreSucceeded(Int)
    case restoreFailed(String)
    case notificationPermissionDenied
    case notificationFailed(String)

    var id: String {
        switch self {
        case .exportFailed: return "exportFailed"
        case .restoreSucceeded: return "restoreSucceeded"
        case .restoreFailed: return "restoreFailed"
        case .notificationPermissionDenied: return "notificationPermissionDenied"
        case .notificationFailed: return "notificationFailed"
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
        case .notificationPermissionDenied:
            return NSLocalizedString("settings.notification.denied.title", comment: "")
        case .notificationFailed:
            return NSLocalizedString("settings.notification.error.title", comment: "")
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
        case .restoreFailed(let message), .notificationFailed(let message):
            return message
        case .notificationPermissionDenied:
            return NSLocalizedString("settings.notification.denied.message", comment: "")
        }
    }
}
