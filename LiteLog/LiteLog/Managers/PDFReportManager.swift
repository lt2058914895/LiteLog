import CoreData
import Foundation
import UIKit

@MainActor
final class PDFReportManager {
    static let shared = PDFReportManager()

    private init() {}

    func generateReport(
        context: NSManagedObjectContext,
        settings: SettingsManager
    ) throws -> URL {
        let recordRequest = WeightRecord.fetchRequest()
        recordRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: true)]
        let records = try context.fetch(recordRequest)
        guard !records.isEmpty else { throw ReportError.noRecords }

        let profile = try context.fetch(UserProfile.fetchRequest()).first
        let entries = TrendAnalytics.entries(from: records)
        let dailyEntries = TrendAnalytics.dailyEntries(from: entries, scope: .all)
        let goalEstimate = profile?.goalWeightValue.map {
            TrendAnalytics.estimateWeightGoal(from: dailyEntries, targetWeight: $0)
        }

        let snapshot = ReportSnapshot(
            generatedAt: Date(),
            entries: entries.sorted { $0.date < $1.date },
            dailyEntries: dailyEntries,
            profile: profile.map(ReportProfile.init),
            displayName: settings.displayName,
            unit: settings.weightUnit,
            goalEstimate: goalEstimate
        )

        let data = PDFReportRenderer(snapshot: snapshot).render()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteLog_Report_\(formatter.string(from: Date())).pdf")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
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

        let isFirstPage = pageNumber == 1
        drawText(
            NSLocalizedString("app.name", comment: ""),
            in: CGRect(x: margin, y: 30, width: 120, height: 16),
            font: .systemFont(ofSize: 9, weight: .semibold),
            color: ReportPalette.accent
        )
        drawText(
            NSLocalizedString(isFirstPage ? "report.title" : "report.title.continued", comment: ""),
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
        let firstDate = snapshot.entries.first?.date ?? snapshot.generatedAt
        let lastDate = snapshot.entries.last?.date ?? snapshot.generatedAt
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

        if snapshot.entries.count >= 2 {
            drawSectionTitle(NSLocalizedString("report.chart", comment: ""))
            ensureSpace(190)
            let chartRect = CGRect(x: margin, y: y, width: contentWidth, height: 160)
            drawChart(entries: snapshot.dailyEntries, rect: chartRect, unit: snapshot.unit)
            y += 174
        }

        drawSectionTitle(NSLocalizedString("report.table", comment: ""))
        drawTable()
    }

    private func drawSummaryCards() {
        let weights = snapshot.entries.map(\.weight)
        let average = weights.average.map { snapshot.unit.convertFromKg($0).smartFormatted } ?? "--"
        let latest = snapshot.entries.last.map { snapshot.unit.convertFromKg($0.weight).smartFormatted } ?? "--"
        let first = snapshot.entries.first.map { snapshot.unit.convertFromKg($0.weight).smartFormatted } ?? "--"
        let change = snapshot.entries.first.flatMap { firstEntry in
            snapshot.entries.last.map { lastEntry in
                let value = snapshot.unit.convertFromKg(lastEntry.weight - firstEntry.weight)
                return (value > 0 ? "+" : "") + value.smartFormatted
            }
        } ?? "--"

        let cards: [(String, String, String)] = [
            (NSLocalizedString("report.latest.weight", comment: ""), latest, snapshot.unit.shortName),
            (NSLocalizedString("report.change", comment: ""), change, snapshot.unit.shortName),
            (NSLocalizedString("report.average", comment: ""), average, snapshot.unit.shortName),
            (NSLocalizedString("report.records", comment: ""), "\(snapshot.entries.count)", ""),
            (NSLocalizedString("report.first.weight", comment: ""), first, snapshot.unit.shortName),
            (NSLocalizedString("report.goal.weight", comment: ""), snapshot.profile?.goalWeight.map { snapshot.unit.convertFromKg($0).smartFormatted } ?? "--", snapshot.unit.shortName)
        ]

        let gap: CGFloat = 10
        let cardWidth = (contentWidth - gap) / 2
        let cardHeight: CGFloat = 58

        for (index, card) in cards.enumerated() {
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
                card.0,
                in: CGRect(x: rect.minX + 12, y: rect.minY + 10, width: rect.width - 24, height: 12),
                font: .systemFont(ofSize: 8),
                color: ReportPalette.secondaryText
            )
            let valueText = card.2.isEmpty ? card.1 : "\(card.1) \(card.2)"
            drawText(
                valueText,
                in: CGRect(x: rect.minX + 12, y: rect.minY + 25, width: rect.width - 24, height: 22),
                font: .systemFont(ofSize: 16, weight: .bold),
                color: ReportPalette.accent
            )

            if column == 1 || index == cards.count - 1 {
                y += cardHeight + gap
            }
        }

        y += 2
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

        if let estimate = snapshot.goalEstimate {
            ensureSpace(24)
            drawText(
                estimate.summaryText,
                in: CGRect(x: margin, y: y + 2, width: contentWidth, height: 30),
                font: .systemFont(ofSize: 9),
                color: ReportPalette.secondaryText
            )
            y += 32
        }
    }

    private func drawChart(entries: [TrendEntry], rect: CGRect, unit: WeightUnit) {
        let points = Array(entries.suffix(90))
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

        let line = UIBezierPath()
        for (index, point) in points.enumerated() {
            let fraction = points.count == 1 ? 0.5 : CGFloat(index) / CGFloat(points.count - 1)
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

        let recentEntries = snapshot.entries.sorted { $0.date > $1.date }.prefix(30)
        for (index, entry) in recentEntries.enumerated() {
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
            NSLocalizedString("report.disclaimer", comment: ""),
            in: CGRect(x: margin, y: footerY, width: contentWidth - 60, height: 16),
            font: .systemFont(ofSize: 7.5),
            color: ReportPalette.secondaryText
        )
        drawText(
            String(format: NSLocalizedString("report.page", comment: ""), pageNumber),
            in: CGRect(x: pageRect.width - margin - 54, y: footerY, width: 54, height: 16),
            font: .systemFont(ofSize: 8),
            color: ReportPalette.secondaryText,
            alignment: .right
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
    static let primaryText = UIColor(white: 0.14, alpha: 1)
    static let secondaryText = UIColor(white: 0.44, alpha: 1)
    static let separator = UIColor(white: 0.88, alpha: 1)
    static let cardBackground = UIColor(white: 0.965, alpha: 1)
}

private struct ReportSnapshot {
    let generatedAt: Date
    let entries: [TrendEntry]
    let dailyEntries: [TrendEntry]
    let profile: ReportProfile?
    let displayName: String
    let unit: WeightUnit
    let goalEstimate: WeightGoalEstimate?
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

    var errorDescription: String? {
        switch self {
        case .noRecords:
            return NSLocalizedString("pro.pdf.empty", comment: "")
        }
    }
}
