import CoreData
import PDFKit
import SwiftUI

struct ProFeaturePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var proStore: ProEntitlementStore

    let onUnlock: () -> Void

    @State private var reportURL: URL?
    @State private var isGeneratingReport = false
    @State private var reportError: String?
    @State private var reportRequestID = UUID()
    @State private var selectedReportRange: PDFReportTimeRange = .all
    @State private var pendingReportRange: PDFReportTimeRange = .all
    @State private var showingReportRangePicker = false
    @State private var sharedReportURL: IdentifiableURL?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        pdfReportContent
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
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
            return NSLocalizedString("pro.preview.pdf.cta", comment: "")
        }
        return NSLocalizedString("pro.pdf.share", comment: "")
    }

    private var actionNote: String {
        if proStore.isPro {
            return NSLocalizedString("pro.preview.pro.note", comment: "")
        }
        return NSLocalizedString("pro.purchase.note", comment: "")
    }

    private var actionIconName: String {
        proStore.isPro ? "square.and.arrow.up" : "sparkles"
    }

    private var shouldShowActionProgress: Bool {
        proStore.isPro && isGeneratingReport
    }

    private var isPrimaryActionDisabled: Bool {
        proStore.isPro && (isGeneratingReport || reportURL == nil)
    }

    private func performPrimaryAction() {
        guard proStore.isPro else {
            onUnlock()
            return
        }
        shareReport()
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

    private func generateReportIfNeeded(force: Bool = false) {
        guard force || !isGeneratingReport else { return }
        guard force || reportURL == nil else { return }

        let lookbackDays = selectedReportRange.lookbackDays
        let requestID = UUID()
        reportRequestID = requestID
        isGeneratingReport = true
        reportError = nil

        Task {
            await Task.yield()

            do {
                let url = try await PDFReportManager.shared.generateReport(
                    context: context,
                    settings: settingsManager,
                    lookbackDays: lookbackDays
                )
                guard reportRequestID == requestID else { return }
                reportURL = url
            } catch {
                guard reportRequestID == requestID else { return }
                reportError = error.localizedDescription
            }

            if reportRequestID == requestID {
                isGeneratingReport = false
            }
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
