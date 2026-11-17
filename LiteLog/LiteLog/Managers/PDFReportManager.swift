import CoreData
import Foundation
import UIKit

@MainActor
final class PDFReportManager {
    static let shared = PDFReportManager()

    private init() {}

    func generateReport(
        context: NSManagedObjectContext,
        settings: SettingsManager,
        lookbackDays: Int? = nil
    ) async throws -> URL {
        let recordRequest = WeightRecord.fetchRequest()
        recordRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: true)]

        var reportStartDate: Date?
        var reportEndDate: Date?
        if let lookbackDays {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let startDate = calendar.date(
                byAdding: .day,
                value: -(max(lookbackDays, 1) - 1),
                to: today
            ) ?? today
            let endExclusive = calendar.date(byAdding: .day, value: 1, to: today) ?? Date().endOfDay
            recordRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                startDate as NSDate,
                endExclusive as NSDate
            )
            reportStartDate = startDate
            reportEndDate = today
        }

        let records = try context.fetch(recordRequest)
        guard !records.isEmpty else {
            throw lookbackDays == nil ? ReportError.noRecords : ReportError.noRecordsInRange
        }

        let profile = try context.fetch(UserProfile.fetchRequest()).first
        let entries = TrendAnalytics.entries(from: records)
        let dailyEntries = TrendAnalytics.dailyEntries(from: entries, scope: .all)

        let snapshot = ReportSnapshot(
            generatedAt: Date(),
            entries: entries.sorted { $0.date < $1.date },
            dailyEntries: dailyEntries,
            profile: profile.map(ReportProfile.init),
            displayName: settings.displayName,
            unit: settings.weightUnit,
            reportStartDate: reportStartDate,
            reportEndDate: reportEndDate
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmssSSS"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteLog_Report_\(formatter.string(from: Date())).pdf")

        try await Task.detached(priority: .userInitiated) {
            let data = PDFReportRenderer(snapshot: snapshot).render()
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        }.value

        return url
    }
}

private final class PDFReportRenderer {
    private let snapshot: ReportSnapshot
    private let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    private let margin: CGFloat = 40
    private let contentWidth: CGFloat

    private var context: UIGraphicsPDFRendererContext?
    private var pageNumber = 0
    private var y: CGFloat = 0

    init(snapshot: ReportSnapshot) {
        self.snapshot = snapshot
        contentWidth = pageRect.width - margin * 2
    }

    func render() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            self.context = context
            beginPage()
            drawContent()
        }
    }

    private func beginPage() {
        guard let context else { return }
        context.beginPage()
        pageNumber += 1
        context.cgContext.setFillColor(UIColor.white.cgColor)
        context.cgContext.fill(pageRect)

        guard pageNumber == 1 else {
            y = margin
            drawFooter()
            return
        }

        drawText(
            NSLocalizedString("app.name", comment: ""),
            in: CGRect(x: margin, y: 30, width: 120, height: 16),
            font: .systemFont(ofSize: 9, weight: .semibold),
            color: ReportPalette.accent
        )
        drawText(
            NSLocalizedString("report.title", comment: ""),
            in: CGRect(x: margin, y: 46, width: contentWidth, height: 32),
            font: .systemFont(ofSize: 23, weight: .bold),
            color: ReportPalette.primaryText
        )
        drawText(
            String(
                format: NSLocalizedString("report.generated.format", comment: ""),
                snapshot.generatedAt.mediumDateString
            ),
            in: CGRect(x: margin, y: 78, width: contentWidth, height: 14),
            font: .systemFont(ofSize: 8.5),
            color: ReportPalette.secondaryText
        )

        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: 98))
        line.addLine(to: CGPoint(x: pageRect.width - margin, y: 98))
        ReportPalette.separator.setStroke()
        line.lineWidth = 0.6
        line.stroke()

        y = 116
        drawFooter()
    }

    private func drawContent() {
        let firstDate = snapshot.reportStartDate ?? snapshot.entries.first?.date ?? snapshot.generatedAt
        let lastDate = snapshot.reportEndDate ?? snapshot.entries.last?.date ?? snapshot.generatedAt
        drawText(
            String(
                format: NSLocalizedString("report.range.format", comment: ""),
                firstDate.shortDateString,
                lastDate.shortDateString
            ),
            in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
            font: .systemFont(ofSize: 9.5),
            color: ReportPalette.secondaryText
        )
        y += 24

        drawSectionTitle(NSLocalizedString("report.summary", comment: ""))
        drawSummaryCards()

        drawSectionTitle(NSLocalizedString("report.profile", comment: ""))
        drawProfile()

        if snapshot.dailyEntries.count >= 2 {
            y += 10
            drawSectionTitle(NSLocalizedString("report.chart", comment: ""))
            ensureSpace(190)
            let chartRect = CGRect(x: margin, y: y, width: contentWidth, height: 160)
            drawChart(entries: snapshot.dailyEntries, rect: chartRect, unit: snapshot.unit)
            y += 174
        }

        drawSectionTitle(NSLocalizedString("report.table", comment: ""))
        drawTable()
        drawFinalDisclaimer()
    }

    private func drawSummaryCards() {
        let dailyEntries = snapshot.dailyEntries
        let dailyWeights = dailyEntries.map(\.weight)
        let firstWeight = dailyEntries.first?.weight
        let latestWeight = dailyEntries.last?.weight

        let changeText: String
        if let firstWeight, let latestWeight, dailyEntries.count > 1 {
            let change = snapshot.unit.convertFromKg(latestWeight - firstWeight)
            changeText = formattedChange(change, suffix: " \(snapshot.unit.shortName)")
        } else {
            changeText = NSLocalizedString(
                dailyEntries.isEmpty ? "report.no.data" : "report.no.comparison",
                comment: ""
            )
        }

        drawWeightSummary(
            firstWeight: firstWeight,
            latestWeight: latestWeight,
            changeText: changeText
        )

        let bodyFatSamples = snapshot.entries.compactMap(\.bodyFatPercentage)
        let waistSamples = snapshot.entries.compactMap(\.waistCircumference)
        let averageWeight = dailyWeights.average.map {
            "\(snapshot.unit.convertFromKg($0).smartFormatted) \(snapshot.unit.shortName)"
        } ?? "--"
        let minimumWeight = dailyWeights.min().map {
            snapshot.unit.convertFromKg($0).smartFormatted
        } ?? "--"
        let maximumWeight = dailyWeights.max().map {
            snapshot.unit.convertFromKg($0).smartFormatted
        } ?? "--"

        let metrics = [
            ReportSummaryMetric(
                title: NSLocalizedString("report.body.fat", comment: ""),
                value: bodyFatSamples.last.map { "\($0.smartFormatted)%" } ?? "--",
                detail: comparisonDetail(samples: bodyFatSamples, suffix: "%")
            ),
            ReportSummaryMetric(
                title: NSLocalizedString("report.waist", comment: ""),
                value: waistSamples.last.map { "\($0.smartFormatted) cm" } ?? "--",
                detail: comparisonDetail(samples: waistSamples, suffix: " cm")
            ),
            ReportSummaryMetric(
                title: NSLocalizedString("report.average", comment: ""),
                value: averageWeight,
                detail: String(
                    format: NSLocalizedString("report.min.max.format", comment: ""),
                    minimumWeight,
                    maximumWeight,
                    snapshot.unit.shortName
                )
            ),
            ReportSummaryMetric(
                title: NSLocalizedString("report.coverage", comment: ""),
                value: String(
                    format: NSLocalizedString("report.days.format", comment: ""),
                    dailyEntries.count
                ),
                detail: String(
                    format: NSLocalizedString("report.entries.format", comment: ""),
                    snapshot.entries.count
                )
            )
        ]

        drawSummaryMetricCards(metrics)
        y += 2
    }

    private func drawWeightSummary(
        firstWeight: Double?,
        latestWeight: Double?,
        changeText: String
    ) {
        let cardHeight: CGFloat = 94
        ensureSpace(cardHeight + 12)
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: cardHeight)

        ReportPalette.accentSoft.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()

        drawText(
            NSLocalizedString("report.latest.weight", comment: ""),
            in: CGRect(x: rect.minX + 16, y: rect.minY + 12, width: rect.width / 2 - 24, height: 12),
            font: .systemFont(ofSize: 8),
            color: ReportPalette.secondaryText
        )

        let latestText = latestWeight.map {
            "\(snapshot.unit.convertFromKg($0).smartFormatted) \(snapshot.unit.shortName)"
        } ?? "--"
        drawText(
            latestText,
            in: CGRect(x: rect.minX + 16, y: rect.minY + 26, width: rect.width / 2 - 24, height: 32),
            font: .systemFont(ofSize: 25, weight: .bold),
            color: ReportPalette.accent
        )

        if let firstWeight {
            let startText = String(
                format: NSLocalizedString("report.summary.start.format", comment: ""),
                "\(snapshot.unit.convertFromKg(firstWeight).smartFormatted) \(snapshot.unit.shortName)"
            )
            drawText(
                startText,
                in: CGRect(x: rect.minX + 16, y: rect.maxY - 24, width: rect.width / 2 - 24, height: 12),
                font: .systemFont(ofSize: 7.5),
                color: ReportPalette.secondaryText
            )
        }

        let divider = UIBezierPath()
        divider.move(to: CGPoint(x: rect.midX, y: rect.minY + 14))
        divider.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 14))
        ReportPalette.separator.setStroke()
        divider.lineWidth = 0.6
        divider.stroke()

        let rightWidth = rect.width / 2 - 32
        drawText(
            NSLocalizedString("report.change", comment: ""),
            in: CGRect(x: rect.midX + 16, y: rect.minY + 14, width: rightWidth, height: 12),
            font: .systemFont(ofSize: 8),
            color: ReportPalette.secondaryText,
            alignment: .right
        )
        drawText(
            changeText,
            in: CGRect(x: rect.midX + 16, y: rect.minY + 36, width: rightWidth, height: 24),
            font: .systemFont(ofSize: 16, weight: .bold),
            color: ReportPalette.accent,
            alignment: .right
        )

        y += cardHeight + 12
    }

    private func drawSummaryMetricCards(_ metrics: [ReportSummaryMetric]) {
        let gap: CGFloat = 10
        let cardWidth = (contentWidth - gap) / 2
        let cardHeight: CGFloat = 68

        for (index, metric) in metrics.enumerated() {
            if index.isMultiple(of: 2) {
                ensureSpace(cardHeight + gap)
            }

            let column = index % 2
            let rect = CGRect(
                x: margin + CGFloat(column) * (cardWidth + gap),
                y: y,
                width: cardWidth,
                height: cardHeight
            )
            ReportPalette.cardBackground.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

            drawText(
                metric.title,
                in: CGRect(x: rect.minX + 12, y: rect.minY + 10, width: rect.width - 24, height: 12),
                font: .systemFont(ofSize: 8),
                color: ReportPalette.secondaryText
            )
            drawText(
                metric.value,
                in: CGRect(x: rect.minX + 12, y: rect.minY + 23, width: rect.width - 24, height: 22),
                font: .systemFont(ofSize: 15, weight: .bold),
                color: ReportPalette.accent
            )
            drawText(
                metric.detail,
                in: CGRect(x: rect.minX + 12, y: rect.minY + 46, width: rect.width - 24, height: 13),
                font: .systemFont(ofSize: 7.5),
                color: ReportPalette.secondaryText
            )

            if column == 1 || index == metrics.count - 1 {
                y += cardHeight + gap
            }
        }
    }

    private func comparisonDetail(samples: [Double], suffix: String) -> String {
        guard samples.count > 1 else {
            return NSLocalizedString(
                samples.isEmpty ? "report.no.data" : "report.no.comparison",
                comment: ""
            )
        }

        return formattedChange(samples[samples.count - 1] - samples[0], suffix: suffix)
    }

    private func formattedChange(_ value: Double, suffix: String) -> String {
        if abs(value) < 0.005 {
            return "→ 0\(suffix)"
        }

        let arrow = value > 0 ? "↑" : "↓"
        return "\(arrow) \(abs(value).smartFormatted)\(suffix)"
    }

    private func drawProfile() {
        guard let profile = snapshot.profile else {
            ensureSpace(22)
            drawText(
                NSLocalizedString("report.no.profile", comment: ""),
                in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
                font: .systemFont(ofSize: 9.5),
                color: ReportPalette.secondaryText
            )
            y += 24
            return
        }

        let lines: [String] = [
            String(format: NSLocalizedString("report.profile.name.format", comment: ""), snapshot.displayName),
            String(
                format: NSLocalizedString("report.profile.body.format", comment: ""),
                profile.height.smartFormatted,
                Int(profile.age),
                profile.gender
            ),
            String(
                format: NSLocalizedString("report.profile.goal.format", comment: ""),
                profile.goalWeight.map { snapshot.unit.convertFromKg($0).smartFormatted + " " + snapshot.unit.shortName } ?? "--",
                profile.goalBodyFat.map { $0.smartFormatted + "%" } ?? "--"
            )
        ]

        for line in lines {
            ensureSpace(18)
            drawText(
                line,
                in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
                font: .systemFont(ofSize: 9.5),
                color: ReportPalette.primaryText
            )
            y += 18
        }
    }

    private func drawChart(entries: [TrendEntry], rect: CGRect, unit: WeightUnit) {
        let points = entries
        guard points.count >= 2 else { return }

        let values = points.map { unit.convertFromKg($0.weight) }
        guard let minimum = values.min(), let maximum = values.max() else { return }
        let spread = max(maximum - minimum, 1)
        let lower = minimum - spread * 0.18
        let upper = maximum + spread * 0.18

        ReportPalette.cardBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        let plot = rect.insetBy(dx: 34, dy: 26)

        for index in 0...4 {
            let fraction = CGFloat(index) / 4
            let gridY = plot.maxY - plot.height * fraction
            let path = UIBezierPath()
            path.move(to: CGPoint(x: plot.minX, y: gridY))
            path.addLine(to: CGPoint(x: plot.maxX, y: gridY))
            ReportPalette.separator.setStroke()
            path.lineWidth = 0.4
            path.stroke()

            let value = lower + (upper - lower) * Double(fraction)
            drawText(
                value.smartFormatted,
                in: CGRect(x: rect.minX + 4, y: gridY - 6, width: 28, height: 12),
                font: .systemFont(ofSize: 6.5),
                color: ReportPalette.secondaryText,
                alignment: .right
            )
        }

        let firstDate = points[0].date
        let lastDate = points[points.count - 1].date
        let dateSpan = max(lastDate.timeIntervalSince(firstDate), 1)

        let line = UIBezierPath()
        for (index, point) in points.enumerated() {
            let fraction = CGFloat(point.date.timeIntervalSince(firstDate) / dateSpan)
            let value = unit.convertFromKg(point.weight)
            let normalized = (value - lower) / (upper - lower)
            let position = CGPoint(
                x: plot.minX + plot.width * fraction,
                y: plot.maxY - plot.height * CGFloat(normalized)
            )
            if index == 0 {
                line.move(to: position)
            } else {
                line.addLine(to: position)
            }
        }
        ReportPalette.accent.setStroke()
        line.lineWidth = 1.6
        line.lineJoinStyle = .round
        line.stroke()

        if let first = points.first, let last = points.last {
            drawText(
                first.date.shortDateString,
                in: CGRect(x: plot.minX, y: plot.maxY + 8, width: 60, height: 12),
                font: .systemFont(ofSize: 7),
                color: ReportPalette.secondaryText
            )
            drawText(
                last.date.shortDateString,
                in: CGRect(x: plot.maxX - 60, y: plot.maxY + 8, width: 60, height: 12),
                font: .systemFont(ofSize: 7),
                color: ReportPalette.secondaryText,
                alignment: .right
            )
        }
    }

    private func drawTable() {
        let columns: [(String, CGFloat)] = [
            (NSLocalizedString("report.date", comment: ""), 92),
            (NSLocalizedString("report.period.column", comment: ""), 76),
            (NSLocalizedString("report.weight", comment: ""), 64),
            (NSLocalizedString("report.body.fat", comment: ""), 62),
            (NSLocalizedString("report.waist", comment: ""), 62),
            (NSLocalizedString("report.hip", comment: ""), 62),
            (NSLocalizedString("report.chest", comment: ""), 62)
        ]
        let tableWidth = columns.reduce(0) { $0 + $1.1 }
        let rowHeight: CGFloat = 22
        let headerHeight: CGFloat = 24

        drawTableHeader(columns: columns, tableWidth: tableWidth, headerHeight: headerHeight)

        let reportEntries = snapshot.entries.sorted { $0.date > $1.date }
        for (index, entry) in reportEntries.enumerated() {
            if y + rowHeight > pageRect.height - 48 {
                beginPage()
                drawTableHeader(columns: columns, tableWidth: tableWidth, headerHeight: headerHeight)
            }

            let rowRect = CGRect(x: margin, y: y, width: tableWidth, height: rowHeight)
            if index.isMultiple(of: 2) {
                ReportPalette.cardBackground.setFill()
                UIBezierPath(rect: rowRect).fill()
            }

            let period = entry.measurementTimePeriod?.displayName ?? "--"
            let values: [String] = [
                entry.date.shortDateString,
                period,
                snapshot.unit.convertFromKg(entry.weight).smartFormatted,
                entry.bodyFatPercentage.map { $0.smartFormatted + "%" } ?? "--",
                entry.waistCircumference.map { $0.smartFormatted } ?? "--",
                entry.hipCircumference.map { $0.smartFormatted } ?? "--",
                entry.chestCircumference.map { $0.smartFormatted } ?? "--"
            ]

            var x = margin
            for (columnIndex, column) in columns.enumerated() {
                drawText(
                    values[columnIndex],
                    in: CGRect(x: x + 6, y: y + 6, width: column.1 - 12, height: 14),
                    font: .systemFont(ofSize: 8),
                    color: ReportPalette.primaryText
                )
                x += column.1
            }
            y += rowHeight
        }
    }

    private func drawTableHeader(
        columns: [(String, CGFloat)],
        tableWidth: CGFloat,
        headerHeight: CGFloat
    ) {
        ensureSpace(headerHeight)
        let headerRect = CGRect(x: margin, y: y, width: tableWidth, height: headerHeight)
        ReportPalette.cardBackground.setFill()
        UIBezierPath(roundedRect: headerRect, cornerRadius: 6).fill()

        var x = margin
        for column in columns {
            drawText(
                column.0,
                in: CGRect(x: x + 6, y: y + 7, width: column.1 - 12, height: 12),
                font: .systemFont(ofSize: 7.5, weight: .semibold),
                color: ReportPalette.secondaryText
            )
            x += column.1
        }
        y += headerHeight
    }

    private func drawSectionTitle(_ text: String) {
        ensureSpace(34)
        drawText(
            text,
            in: CGRect(x: margin, y: y, width: contentWidth, height: 20),
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: ReportPalette.primaryText
        )
        y += 26
    }

    private func ensureSpace(_ height: CGFloat) {
        if y + height > pageRect.height - 48 {
            beginPage()
        }
    }

    private func drawFooter() {
        let footerY = pageRect.height - 30
        drawText(
            String(format: NSLocalizedString("report.page", comment: ""), pageNumber),
            in: CGRect(x: pageRect.width - margin - 54, y: footerY, width: 54, height: 16),
            font: .systemFont(ofSize: 8),
            color: ReportPalette.secondaryText,
            alignment: .right
        )
    }

    private func drawFinalDisclaimer() {
        drawText(
            NSLocalizedString("report.disclaimer", comment: ""),
            in: CGRect(x: margin, y: pageRect.height - 30, width: contentWidth - 60, height: 16),
            font: .systemFont(ofSize: 7.5),
            color: ReportPalette.secondaryText
        )
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

private enum ReportPalette {
    static let accent = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1)
    static let accentSoft = UIColor(red: 0.94, green: 0.97, blue: 1, alpha: 1)
    static let primaryText = UIColor(white: 0.14, alpha: 1)
    static let secondaryText = UIColor(white: 0.44, alpha: 1)
    static let separator = UIColor(white: 0.88, alpha: 1)
    static let cardBackground = UIColor(white: 0.965, alpha: 1)
}

private struct ReportSummaryMetric {
    let title: String
    let value: String
    let detail: String
}

private struct ReportSnapshot {
    let generatedAt: Date
    let entries: [TrendEntry]
    let dailyEntries: [TrendEntry]
    let profile: ReportProfile?
    let displayName: String
    let unit: WeightUnit
    let reportStartDate: Date?
    let reportEndDate: Date?
}

private struct ReportProfile {
    let height: Double
    let age: Int16
    let gender: String
    let goalWeight: Double?
    let goalBodyFat: Double?

    init(_ profile: UserProfile) {
        height = profile.height
        age = profile.age
        gender = profile.genderEnum.displayName
        goalWeight = profile.goalWeightValue
        goalBodyFat = profile.goalBodyFatPercentage
    }
}

enum ReportError: LocalizedError {
    case noRecords
    case noRecordsInRange

    var errorDescription: String? {
        switch self {
        case .noRecords:
            return NSLocalizedString("pro.pdf.empty", comment: "")
        case .noRecordsInRange:
            return NSLocalizedString("pro.pdf.empty.range", comment: "")
        }
    }
}
