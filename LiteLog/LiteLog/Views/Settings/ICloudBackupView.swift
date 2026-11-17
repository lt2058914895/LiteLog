import CoreData
import SwiftUI

struct ICloudBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var iCloudBackupManager = ICloudBackupManager.shared

    let recordCount: Int

    @State private var isBackingUp = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                iCloudPreview
                if !iCloudBackupManager.isAvailable {
                    iCloudUnavailableHint
                }
                if iCloudBackupManager.isAvailable {
                    iCloudBackupStatus
                }
            }
            .padding(20)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .task {
            await iCloudBackupManager.refreshAvailabilityWithRetry()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task {
                await iCloudBackupManager.refreshAvailabilityWithRetry()
            }
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.primaryBlue, Color(hex: "4FB6A8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)

                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(NSLocalizedString("pro.icloud.title", comment: ""))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("pro.preview.icloud.subtitle", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var iCloudPreview: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                previewNode(
                    icon: "iphone",
                    labelKey: "pro.preview.icloud.phone",
                    tint: .primaryBlue
                )

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.tertiaryText)

                previewNode(
                    icon: "icloud.fill",
                    labelKey: "pro.preview.icloud.cloud",
                    tint: Color(hex: "4FB6A8")
                )
            }

            VStack(spacing: 0) {
                dataRow(
                    icon: "chart.bar.fill",
                    titleKey: "pro.preview.icloud.records",
                    value: recordCountText
                )

                Divider()
                    .padding(.leading, 30)

                dataRow(
                    icon: "person.fill",
                    titleKey: "pro.preview.icloud.profile",
                    value: NSLocalizedString("pro.preview.included", comment: "")
                )

                Divider()
                    .padding(.leading, 30)

                dataRow(
                    icon: "person.crop.circle",
                    titleKey: "pro.preview.icloud.settings",
                    value: NSLocalizedString("pro.preview.included", comment: "")
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "4FB6A8"))

                Text(NSLocalizedString("pro.preview.icloud.benefit.combined", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.separator).opacity(0.16), lineWidth: 1)
        )
    }

    private var iCloudBackupStatus: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.12))
                    .frame(width: 38, height: 38)

                if isICloudBackingUp {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: statusIconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(statusTint)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)

                Text(statusDetail)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if !isICloudBackingUp, iCloudBackupManager.lastBackupDate != nil {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(hex: "2ECC71"))
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.16), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: iCloudBackupManager.lastBackupDate)
    }

    private var iCloudUnavailableHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("pro.icloud.help.title", comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)

                Text(NSLocalizedString("pro.icloud.help.detail", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.16), lineWidth: 1)
        )
    }

    private var actionBar: some View {
        Button {
            HapticManager.light()
            backUpNow()
        } label: {
            HStack(spacing: 7) {
                if isICloudBackingUp {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "icloud.and.arrow.up.fill")
                }

                Text(NSLocalizedString("pro.icloud.backup.now", comment: ""))
            }
            .primaryButtonStyle()
        }
        .disabled(isICloudBackingUp)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var isICloudBackingUp: Bool {
        isBackingUp || iCloudBackupManager.isBackingUp
    }

    private var statusTint: Color {
        if isICloudBackingUp {
            return .primaryBlue
        }
        return iCloudBackupManager.lastBackupDate == nil ? .secondaryText : Color(hex: "2ECC71")
    }

    private var statusIconName: String {
        iCloudBackupManager.lastBackupDate == nil ? "icloud.and.arrow.up" : "icloud.fill"
    }

    private var statusTitle: String {
        if isICloudBackingUp {
            return NSLocalizedString("pro.icloud.status.backing.up", comment: "")
        }
        if iCloudBackupManager.lastBackupDate == nil {
            return NSLocalizedString("pro.icloud.status.waiting", comment: "")
        }
        return NSLocalizedString("pro.icloud.status.success", comment: "")
    }

    private var statusDetail: String {
        if isICloudBackingUp {
            return NSLocalizedString("pro.icloud.status.backing.up.detail", comment: "")
        }
        guard let lastBackupDate = iCloudBackupManager.lastBackupDate else {
            return NSLocalizedString("pro.icloud.status.waiting.detail", comment: "")
        }
        return String(
            format: NSLocalizedString("pro.icloud.last.backup", comment: ""),
            "\(lastBackupDate.shortDateString) \(lastBackupDate.timeString)"
        )
    }

    private var recordCountText: String {
        let key = recordCount == 1
            ? "record.count.records.one"
            : "record.count.records.other"
        return String(format: NSLocalizedString(key, comment: ""), recordCount)
    }

    private func backUpNow() {
        guard !isBackingUp else { return }
        isBackingUp = true

        Task {
            defer { isBackingUp = false }

            do {
                try await iCloudBackupManager.backup(
                    context: context,
                    settings: settingsManager,
                    force: true
                )
                HapticManager.success()
                showAlert(
                    title: NSLocalizedString("pro.icloud.backup.success", comment: ""),
                    message: NSLocalizedString("pro.icloud.backup.success.message", comment: "")
                )
            } catch {
                showAlert(
                    title: NSLocalizedString("pro.icloud.backup.failed", comment: ""),
                    message: error.localizedDescription
                )
            }
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }

    private func previewNode(icon: String, labelKey: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(tint)
            }

            Text(NSLocalizedString(labelKey, comment: ""))
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dataRow(icon: String, titleKey: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primaryBlue)
                .frame(width: 20)

            Text(NSLocalizedString(titleKey, comment: ""))
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondaryText)
        }
        .padding(.vertical, 10)
    }
}
