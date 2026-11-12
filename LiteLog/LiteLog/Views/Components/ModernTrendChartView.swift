import SwiftUI
import Charts

struct ModernTrendChartView: View {
    let data: [(Date, Double)]
    let color: Color
    let unit: String
    let title: String
    let period: StatisticsView.Period?
    let chartRange: ClosedRange<Date>?
    let showsUnitInHeader: Bool

    @State private var selectedIndex: Int?

    private let axisScale: TrendAxisScale
    private let chartHeight: CGFloat = 212
    private let cardContentHeight: CGFloat = 244
    private let plotTopSpacing: CGFloat = 8
    private let xAxisLabelSpacing: CGFloat = 20
    private let xAxisBottomSpacing: CGFloat = 8
    private let xAxisEdgePadding: CGFloat = 12

    init(
        data: [(Date, Double)],
        color: Color,
        unit: String,
        title: String,
        period: StatisticsView.Period? = nil,
        chartRange: ClosedRange<Date>? = nil,
        showsUnitInHeader: Bool = true
    ) {
        let sortedData = data.sorted { $0.0 < $1.0 }
        self.data = sortedData
        self.color = color
        self.unit = unit
        self.title = title
        self.period = period
        self.chartRange = chartRange
        self.showsUnitInHeader = showsUnitInHeader
        self.axisScale = TrendAxisScale(values: sortedData.map(\.1))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            if shouldShowChartHeader {
                chartHeader
            }

            if data.isEmpty {
                emptyStateView
            } else {
                chart
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: chartHeight)
                    .padding(.top, plotTopSpacing)
                    .padding(.bottom, xAxisBottomSpacing)
            }
        }
        .frame(
            height: shouldShowChartHeader
                ? cardContentHeight + plotTopSpacing + 36
                : cardContentHeight + plotTopSpacing
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .cardStyle()
        .onChange(of: data.count) { _ in
            selectedIndex = nil
        }
    }

    private var shouldShowChartHeader: Bool {
        !title.isEmpty || showsUnitInHeader
    }

    private var chartHeader: some View {
        HStack(spacing: 8) {
            if !title.isEmpty {
                Text(NSLocalizedString(title, comment: ""))
                    .font(.headline)
                    .foregroundColor(.primaryText)
            }

            Spacer()

            if showsUnitInHeader {
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primaryText.opacity(0.82))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .cornerRadius(8)
            }
        }
        .frame(minHeight: 20)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.secondaryText)

            Text(NSLocalizedString("common.no.data", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(height: chartHeight)
        .frame(maxWidth: .infinity)
    }

    private var chart: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                let point = data[index]

                AreaMark(
                    x: .value("Date", point.0),
                    yStart: .value("Base", axisScale.displayMin),
                    yEnd: .value("Value", point.1)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.22), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.0),
                    y: .value("Value", point.1)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(color)
                .lineStyle(
                    StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

                PointMark(
                    x: .value("Date", point.0),
                    y: .value("Value", point.1)
                )
                .foregroundStyle(color)
                .symbolSize(34)
            }

            if let selectedPoint {
                RuleMark(
                    x: .value("Selected Date", selectedPoint.date)
                )
                .foregroundStyle(color.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Selected Date", selectedPoint.date),
                    y: .value("Selected Value", selectedPoint.value)
                )
                .foregroundStyle(color)
                .symbolSize(72)
            }
        }
        .chartXScale(
            domain: xDomain,
            range: .plotDimension(
                startPadding: xAxisEdgePadding,
                endPadding: xAxisEdgePadding
            )
        )
        .chartYScale(domain: axisScale.displayMin...axisScale.displayMax)
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(
                position: .leading,
                values: axisScale.anchorValues.sorted()
            ) { value in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])
                )
                .foregroundStyle(Color.secondaryText.opacity(0.18))

                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(axisScale.label(for: number))
                            .font(.system(size: 10, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.secondaryText)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisDates) { _ in
                AxisValueLabel {
                    Text(" ")
                        .font(.system(size: 10))
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let plotFrame = geometry[proxy.plotAreaFrame]

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    updateSelection(
                                        at: value.location,
                                        proxy: proxy,
                                        geometry: geometry
                                    )
                                }
                        )

                    ForEach(xAxisDates, id: \.self) { date in
                        let x = xPosition(for: date, plotFrame: plotFrame)
                        let labelWidth: CGFloat = 42
                        let labelX = min(
                            max(x, plotFrame.minX + labelWidth / 2),
                            plotFrame.maxX - labelWidth / 2
                        )

                        Text(formatAxisDate(date))
                            .font(.system(size: 10, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(width: labelWidth)
                            .position(
                                x: labelX,
                                y: plotFrame.maxY + xAxisLabelSpacing
                            )
                    }
                    .allowsHitTesting(false)

                    if let selectedPoint {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatAxisDate(selectedPoint.date))
                                .font(.caption2)
                                .foregroundColor(.secondaryText)

                            Text("\(selectedPoint.value.smartFormatted) \(unit)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(color)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                        .frame(width: 104, alignment: .trailing)
                        .position(
                            x: plotFrame.maxX - 58,
                            y: plotFrame.minY + 28
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var selectedPoint: (date: Date, value: Double)? {
        guard let selectedIndex, data.indices.contains(selectedIndex) else {
            return nil
        }
        return data[selectedIndex]
    }

    private var xDomain: ClosedRange<Date> {
        if let chartRange {
            return chartRange
        }

        guard let first = data.first?.0, let last = data.last?.0 else {
            let now = Date()
            return now.addingTimeInterval(-43_200)...now.addingTimeInterval(43_200)
        }
        if first == last {
            return first.addingTimeInterval(-43_200)...last.addingTimeInterval(43_200)
        }
        return first...last
    }

    private var xAxisDates: [Date] {
        if let chartRange {
            let span = chartRange.upperBound.timeIntervalSince(chartRange.lowerBound)
            let weekCount = period?.weekCount ?? 4
            let count = weekCount <= 1 ? 3 : (weekCount <= 4 ? 4 : 5)
            return (0..<count).map { index in
                chartRange.lowerBound.addingTimeInterval(
                    span * Double(index) / Double(count - 1)
                )
            }
        }

        guard !data.isEmpty else { return [] }
        if data.count <= 4 {
            return data.map(\.0)
        }

        let labelCount = data.count > 12 ? 5 : 3
        var indices = Set<Int>()
        for index in 0..<labelCount {
            indices.insert(
                Int(Double(index) * Double(data.count - 1) / Double(labelCount - 1))
            )
        }
        indices.insert(0)
        indices.insert(data.count - 1)
        return indices.sorted().map { data[$0].0 }
    }

    private func xPosition(for date: Date, plotFrame: CGRect) -> CGFloat {
        let domainStart = xDomain.lowerBound
        let domainEnd = xDomain.upperBound
        let span = max(domainEnd.timeIntervalSince(domainStart), 1)
        let progress = date.timeIntervalSince(domainStart) / span
        let usableWidth = max(plotFrame.width - xAxisEdgePadding * 2, 1)
        return plotFrame.minX + xAxisEdgePadding + CGFloat(progress) * usableWidth
    }

    private func updateSelection(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        guard plotFrame.contains(location) else {
            selectedIndex = nil
            return
        }

        let xPosition = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xPosition),
              let nearestIndex = data.indices.min(by: {
                  abs(data[$0].0.timeIntervalSince(date))
                      < abs(data[$1].0.timeIntervalSince(date))
              }) else {
            return
        }

        selectedIndex = nearestIndex
    }

    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        let template = (period?.weekCount ?? 0) > 8 ? "MMM" : "Md"
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date).trimmingTrailingDecimalZeros
    }

}
