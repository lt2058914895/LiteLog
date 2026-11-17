import CoreData
import PDFKit
import SwiftUI

enum ProFeaturePreview: String, Identifiable {
    case iCloudBackup
    case pdfReport

    var id: String { rawValue }
}

struct ProFeaturePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var proStore: ProEntitlementStore

    let feature: ProFeaturePreview
    let recordCount: Int
    let onUnlock: () -> Void

    @State private var reportURL: URL?
    @State private var isGeneratingReport = false
    @State private var reportError: String?
    @State private var selectedReportRange: PDFReportTimeRange = .all
    @State private var pendingReportRange: PDFReportTimeRange = .all
    @State private var showingReportRangePicker = false
    @State private var isBackingUp = false
    @State private var sharedReportURL: IdentifiableURL?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        content
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationTitle(
                feature == .pdfReport
                    ? NSLocalizedString("pro.preview.pdf.title", comment: "")
                    : ""
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .sheet(item: $sharedReportURL) { item in
                ShareSheet(items: [item.url])
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .task {
                guard feature == .pdfReport else { return }
                generateReportIfNeeded()
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

    @ViewBuilder
    private var content: some View {
        switch feature {
        case .iCloudBackup:
            iCloudContent
        case .pdfReport:
            pdfReportContent
        }
    }

    private var iCloudContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                iCloudPreview
                iCloudBenefitList
            }
            .padding(20)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
    }

    private var pdfReportContent: some View {
        VStack(spacing: 0) {
            pdfReportRangeSelector
                .sheet(isPresented: $showingReportRangePicker) {
                    reportRangePicker
                }

            Divider()

            pdfReportViewer
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconGradient)
                    .frame(width: 58, height: 58)

                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(NSLocalizedString(titleKey, comment: ""))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)

            Text(NSLocalizedString(subtitleKey, comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Image(systemName: proStore.isPro ? "checkmark.seal.fill" : "sparkles")
                Text(
                    NSLocalizedString(
                        proStore.isPro ? "pro.preview.eyebrow.pro" : "pro.preview.eyebrow",
                        comment: ""
                    )
                )
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(proStore.isPro ? .green : .purple)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((proStore.isPro ? Color.green : Color.purple).opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var pdfReportRangeSelector: some View {
        Button {
            pendingReportRange = selectedReportRange
            showingReportRangePicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryBlue)
                    .frame(width: 20)

                Text(NSLocalizedString("pro.preview.pdf.range.label", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                Spacer(minLength: 8)

                Text(selectedReportRange.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryBlue)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primaryBlue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var reportRangePicker: some View {
        NavigationStack {
            Picker(
                NSLocalizedString("pro.preview.pdf.range.title", comment: ""),
                selection: $pendingReportRange
            ) {
                ForEach(PDFReportTimeRange.options, id: \.self) { range in
                    Text(range.title)
                        .tag(range)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .navigationTitle(NSLocalizedString("pro.preview.pdf.range.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        showingReportRangePicker = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        applyReportRange()
                    }
                }
            }
        }
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var pdfReportViewer: some View {
        if isGeneratingReport {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)

                Text(NSLocalizedString("pro.preview.pdf.generating", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let reportURL {
            PDFPageScrollView(url: reportURL)
                .id(reportURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.secondaryText)

                Text(reportError ?? NSLocalizedString("pro.pdf.failed", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    generateReportIfNeeded()
                } label: {
                    Text(NSLocalizedString("action.retry", comment: ""))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryBlue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primaryBlue.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                    icon: "slider.horizontal.3",
                    titleKey: "pro.preview.icloud.settings",
                    value: NSLocalizedString("pro.preview.included", comment: "")
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(Color(hex: "4FB6A8"))

                Text(NSLocalizedString("pro.preview.icloud.private", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.separator).opacity(0.16), lineWidth: 1)
        )
    }

    private var iCloudBenefitList: some View {
        VStack(spacing: 0) {
            benefitRow(textKey: "pro.preview.icloud.benefit.auto")

            Divider()
                .padding(.leading, 50)

            benefitRow(textKey: "pro.preview.icloud.benefit.restore")

            Divider()
                .padding(.leading, 50)

            benefitRow(textKey: "pro.preview.icloud.benefit.private")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.16), lineWidth: 1)
        )
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            Button {
                HapticManager.light()
                performPrimaryAction()
            } label: {
                HStack(spacing: 7) {
                    if shouldShowActionProgress {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: actionIconName)
                    }

                    Text(actionTitle)
                }
                .primaryButtonStyle()
            }
            .disabled(isPrimaryActionDisabled)

            Text(actionNote)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var actionTitle: String {
        if !proStore.isPro {
            return NSLocalizedString(ctaKey, comment: "")
        }

        switch feature {
        case .iCloudBackup:
            return NSLocalizedString("pro.icloud.backup.now", comment: "")
        case .pdfReport:
            return NSLocalizedString("pro.pdf.share", comment: "")
        }
    }

    private var actionNote: String {
        if proStore.isPro {
            return NSLocalizedString("pro.preview.pro.note", comment: "")
        }
        return NSLocalizedString("pro.purchase.note", comment: "")
    }

    private var actionIconName: String {
        if !proStore.isPro {
            return "sparkles"
        }

        switch feature {
        case .iCloudBackup:
            return "icloud.and.arrow.up.fill"
        case .pdfReport:
            return "square.and.arrow.up"
        }
    }

    private var shouldShowActionProgress: Bool {
        guard proStore.isPro else { return false }
        return isBackingUp || (feature == .pdfReport && isGeneratingReport)
    }

    private var isPrimaryActionDisabled: Bool {
        guard proStore.isPro else { return false }

        switch feature {
        case .iCloudBackup:
            return isBackingUp
        case .pdfReport:
            return isGeneratingReport || reportURL == nil
        }
    }

    private func performPrimaryAction() {
        guard proStore.isPro else {
            onUnlock()
            return
        }

        switch feature {
        case .iCloudBackup:
            backUpNow()
        case .pdfReport:
            shareReport()
        }
    }

    private func backUpNow() {
        guard !isBackingUp else { return }
        isBackingUp = true
        defer { isBackingUp = false }

        do {
            try ICloudBackupManager.shared.backup(
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

    private func shareReport() {
        guard let reportURL else {
            showAlert(
                title: NSLocalizedString("pro.pdf.failed", comment: ""),
                message: NSLocalizedString("pro.preview.pdf.not.ready", comment: "")
            )
            return
        }

        sharedReportURL = IdentifiableURL(reportURL)
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

    private func benefitRow(textKey: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)

                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(NSLocalizedString(textKey, comment: ""))
                .font(.subheadline)
                .foregroundColor(.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var recordCountText: String {
        let key = recordCount == 1
            ? "record.count.records.one"
            : "record.count.records.other"
        return String(format: NSLocalizedString(key, comment: ""), recordCount)
    }

    private func generateReportIfNeeded(force: Bool = false) {
        guard !isGeneratingReport else { return }
        guard force || reportURL == nil else { return }

        let lookbackDays = selectedReportRange.lookbackDays
        isGeneratingReport = true
        reportError = nil

        Task {
            await Task.yield()

            do {
                let url = try PDFReportManager.shared.generateReport(
                    context: context,
                    settings: settingsManager,
                    lookbackDays: lookbackDays
                )
                reportURL = url
            } catch {
                reportError = error.localizedDescription
            }

            isGeneratingReport = false
        }
    }

    private func applyReportRange() {
        showingReportRangePicker = false
        guard pendingReportRange != selectedReportRange else { return }

        selectedReportRange = pendingReportRange
        reportURL = nil
        reportError = nil
        generateReportIfNeeded(force: true)
    }

    private var titleKey: String {
        switch feature {
        case .iCloudBackup:
            return "pro.preview.icloud.title"
        case .pdfReport:
            return "pro.preview.pdf.title"
        }
    }

    private var subtitleKey: String {
        switch feature {
        case .iCloudBackup:
            return "pro.preview.icloud.subtitle"
        case .pdfReport:
            return "pro.preview.pdf.subtitle"
        }
    }

    private var ctaKey: String {
        switch feature {
        case .iCloudBackup:
            return "pro.preview.icloud.cta"
        case .pdfReport:
            return "pro.preview.pdf.cta"
        }
    }

    private var iconName: String {
        switch feature {
        case .iCloudBackup:
            return "icloud.and.arrow.up.fill"
        case .pdfReport:
            return "doc.richtext.fill"
        }
    }

    private var iconGradient: LinearGradient {
        switch feature {
        case .iCloudBackup:
            return LinearGradient(
                colors: [Color.primaryBlue, Color(hex: "4FB6A8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pdfReport:
            return LinearGradient(
                colors: [Color(hex: "F39C5A"), Color(hex: "E36F6F")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private enum PDFReportTimeRange: Hashable {
    case all
    case lastDays(Int)
    case lastWeeks(Int)

    static let options: [PDFReportTimeRange] = [.all, .lastDays(7)]
        + (2...52).map { .lastWeeks($0) }

    var lookbackDays: Int? {
        switch self {
        case .all:
            return nil
        case .lastDays(let days):
            return days
        case .lastWeeks(let weeks):
            return weeks * 7
        }
    }

    var title: String {
        switch self {
        case .all:
            return NSLocalizedString("pro.preview.pdf.range.all", comment: "")
        case .lastDays(let days):
            return String(
                format: NSLocalizedString("pro.preview.pdf.range.days.format", comment: ""),
                days
            )
        case .lastWeeks(let weeks):
            return String(
                format: NSLocalizedString("pro.preview.pdf.range.weeks.format", comment: ""),
                weeks
            )
        }
    }
}

private struct PDFPageScrollView: View {
    let url: URL
    @State private var document: PDFDocument?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if let document {
                LazyVStack(spacing: 12) {
                    ForEach(0..<document.pageCount, id: \.self) { pageIndex in
                        PDFReportPageView(document: document, pageIndex: pageIndex)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .background(Color.clear)
        .task(id: url) {
            document = PDFDocument(url: url)
        }
    }
}

private struct PDFReportPageView: View {
    let document: PDFDocument
    let pageIndex: Int

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 240)
            }
        }
        .task(id: pageIndex) {
            guard image == nil, let page = document.page(at: pageIndex) else { return }
            image = page.thumbnail(
                of: CGSize(width: 1400, height: 1980),
                for: .mediaBox
            )
        }
    }
}
