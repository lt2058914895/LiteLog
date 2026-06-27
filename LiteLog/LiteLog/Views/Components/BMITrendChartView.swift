import SwiftUI

struct BMITrendChartView: View {
    let data: [(Date, Double)]
    
    private let yAxisWidth: CGFloat = 20
    private let xAxisHeight: CGFloat = 26
    private let chartHeight: CGFloat = 160
    private let lineWidth: CGFloat = 2.5
    private let gridLineWidth: CGFloat = 0.5
    private let pointSize: CGFloat = 6
    private let chartPadding: CGFloat = 8
    
    private let bmiCriticalPoints: [Double] = [18.5, 24.0, 28.0]
    
    private let bmiRanges: [(range: ClosedRange<Double>, color: Color, name: String)] = [
        (0...18.5, Color(hex: "60A5FA"), NSLocalizedString("bmi.underweight", comment: "")),
        (18.5...24.0, Color(hex: "34D399"), NSLocalizedString("bmi.normal", comment: "")),
        (24.0...28.0, Color(hex: "FBBF24"), NSLocalizedString("bmi.overweight", comment: "")),
        (28.0...Double.infinity, Color(hex: "F87171"), NSLocalizedString("bmi.obese", comment: ""))
    ]
    
    private var chartData: ChartData {
        ChartData(data: data)
    }
    
    struct ChartData {
        let values: [Double]
        let maxValue: Double
        let minValue: Double
        let displayMax: Double
        let displayMin: Double
        let displayRange: Double
        
        init(data: [(Date, Double)]) {
            self.values = data.map { $0.1 }
            self.maxValue = values.max() ?? 30
            self.minValue = values.min() ?? 18.5
            let range = maxValue - minValue
            let margin = range * 0.1
            self.displayMax = max(maxValue + margin, 35)
            self.displayMin = min(minValue - margin, 15)
            self.displayRange = displayMax - displayMin
        }
        
        func normalizedY(for value: Double) -> Double {
            displayRange > 0 ? (value - displayMin) / displayRange : 0.5
        }
        
        func pixelY(for value: Double, height: CGFloat) -> CGFloat {
            let normalizedY = self.normalizedY(for: value)
            return height - normalizedY * height
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("stats.bmi.trend", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)
            
            if data.isEmpty {
                emptyStateView
            } else {
                chartView
            }
            
            bmiLegend
        }
        .padding()
        .cardStyle()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "activity")
                .font(.system(size: 32))
                .foregroundColor(.secondaryText)
            
            Text(NSLocalizedString("stats.no.data", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(height: chartHeight)
        .frame(maxWidth: .infinity)
    }
    
    private var chartView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                yAxisLabels
                
                chartContent
            }
            
            xAxisLabels
        }
        .frame(height: chartHeight)
    }
    
    private var yAxisLabels: some View {
        GeometryReader { geometry in
            let innerHeight = geometry.size.height - chartPadding * 2
            
            ZStack(alignment: .trailing) {
                ForEach(bmiCriticalPoints.indices, id: \.self) { index in
                    let value = bmiCriticalPoints[index]
                    let y = chartPadding + chartData.pixelY(for: value, height: innerHeight)
                    
                    Text(value == Double(Int(value)) ? "\(Int(value))" : String(format: "%.1f", value))
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                        .position(x: yAxisWidth - 6, y: y)
                }
            }
        }
        .frame(width: yAxisWidth)
    }
    
    private var chartContent: some View {
        GeometryReader { geometry in
            let chartAreaHeight = geometry.size.height
            let chartAreaWidth = geometry.size.width
            let innerWidth = chartAreaWidth - chartPadding * 2
            let innerHeight = chartAreaHeight - chartPadding * 2
            
            ZStack(alignment: .topLeading) {
                bmiBackground(width: innerWidth, height: innerHeight)
                gridLines(width: innerWidth, height: innerHeight)
                axisLines(width: innerWidth, height: innerHeight)
                
                if data.count > 1 {
                    curvePath(width: innerWidth, height: innerHeight)
                    dataPoints(width: innerWidth, height: innerHeight)
                } else if let point = data.first {
                    singlePointView(width: innerWidth, height: innerHeight, value: point.1)
                }
            }
        }
        .drawingGroup()
    }
    
    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(bmiCriticalPoints.indices, id: \.self) { index in
                let value = bmiCriticalPoints[index]
                let y = chartPadding + chartData.pixelY(for: value, height: height)
                
                Path { path in
                    path.move(to: CGPoint(x: chartPadding, y: y))
                    path.addLine(to: CGPoint(x: width + chartPadding, y: y))
                }
                .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: gridLineWidth, dash: [2, 4]))
            }
        }
    }
    
    private func axisLines(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: chartPadding, y: chartPadding))
                path.addLine(to: CGPoint(x: chartPadding, y: height + chartPadding))
            }
            .stroke(Color.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            
            Path { path in
                path.move(to: CGPoint(x: chartPadding, y: height + chartPadding))
                path.addLine(to: CGPoint(x: width + chartPadding, y: height + chartPadding))
            }
            .stroke(Color.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
    
    private func bmiBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(bmiRanges.indices, id: \.self) { index in
                let rangeItem = bmiRanges[index]
                let rangeStart = max(rangeItem.range.lowerBound, chartData.displayMin)
                let rangeEnd = min(rangeItem.range.upperBound, chartData.displayMax)
                
                if rangeEnd > rangeStart {
                    let startPixel = chartData.pixelY(for: rangeEnd, height: height)
                    let endPixel = chartData.pixelY(for: rangeStart, height: height)
                    let bgHeight = endPixel - startPixel
                    
                    rangeItem.color.opacity(0.18)
                        .frame(width: width, height: bgHeight)
                        .position(x: width / 2, y: startPixel + bgHeight / 2)
                }
            }
        }
        .offset(x: chartPadding, y: chartPadding)
    }
    
    private var xAxisLabels: some View {
        GeometryReader { geometry in
            let chartAreaWidth = geometry.size.width - yAxisWidth
            let innerWidth = chartAreaWidth - chartPadding * 2
            
            ZStack(alignment: .bottom) {
                ForEach(calculateXAxisLabelIndices(), id: \.self) { dataIndex in
                    let x = yAxisWidth + chartPadding + CGFloat(dataIndex) * innerWidth / CGFloat(max(data.count - 1, 1))
                    
                    Text(formatDate(data[dataIndex].0))
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                        .position(x: x, y: xAxisHeight / 2)
                }
            }
        }
        .frame(height: xAxisHeight)
    }
    
    private func curvePath(width: CGFloat, height: CGFloat) -> some View {
        let points = calculatePoints(width: width, height: height)
        
        return Path { path in
            guard points.count >= 2 else { return }
            
            if points.count == 2 {
                path.move(to: points[0])
                path.addLine(to: points[1])
                return
            }
            
            path.move(to: points[0])
            
            for i in 0..<points.count - 1 {
                let p0 = i > 0 ? points[i - 1] : points[i]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]
                
                let cp1x = p1.x + (p2.x - p0.x) / 6
                let cp1y = p1.y + (p2.y - p0.y) / 6
                let cp2x = p2.x - (p3.x - p1.x) / 6
                let cp2y = p2.y - (p3.y - p1.y) / 6
                
                path.addCurve(to: p2, control1: CGPoint(x: cp1x, y: cp1y), control2: CGPoint(x: cp2x, y: cp2y))
            }
        }
        .stroke(Color.white, lineWidth: lineWidth)
        .offset(x: chartPadding, y: chartPadding)
    }
    
    private func dataPoints(width: CGFloat, height: CGFloat) -> some View {
        let points = calculatePoints(width: width, height: height)
        
        return ForEach(points.indices, id: \.self) { index in
            Circle()
                .fill(bmiColor(for: data[index].1))
                .frame(width: pointSize, height: pointSize)
                .position(x: chartPadding + points[index].x, y: chartPadding + points[index].y)
        }
    }
    
    private func singlePointView(width: CGFloat, height: CGFloat, value: Double) -> some View {
        let pointY = chartData.pixelY(for: value, height: height)
        let pointX = CGFloat(0) * width / CGFloat(max(data.count - 1, 1))
        let pointColor = bmiColor(for: value)
        
        return Circle()
            .fill(pointColor)
            .frame(width: pointSize, height: pointSize)
            .position(x: chartPadding + pointX, y: chartPadding + pointY)
    }
    
    private func calculatePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        data.enumerated().map { index, point in
            let x = CGFloat(index) * width / CGFloat(max(data.count - 1, 1))
            let y = chartData.pixelY(for: point.1, height: height)
            return CGPoint(x: x, y: y)
        }
    }
    
    private func calculateXAxisLabelIndices() -> [Int] {
        guard data.count > 0 else { return [] }
        
        let count = data.count
        if count <= 7 {
            return (0..<count).map { $0 }
        }
        
        let labelCount: Int
        if count <= 14 {
            labelCount = 5
        } else if count <= 30 {
            labelCount = 6
        } else {
            labelCount = 8
        }
        
        var indices = [Int]()
        for i in 0..<labelCount {
            let index = Int(Double(i) * Double(count - 1) / Double(labelCount - 1))
            if !indices.contains(index) {
                indices.append(index)
            }
        }
        
        if !indices.contains(0) {
            indices.insert(0, at: 0)
        }
        if !indices.contains(count - 1) {
            indices.append(count - 1)
        }
        
        return indices.sorted()
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day)"
    }
    
    private func bmiColor(for bmi: Double) -> Color {
        if bmi <= 18.5 {
            return Color(hex: "60A5FA")
        } else if bmi <= 24.0 {
            return Color(hex: "34D399")
        } else if bmi <= 28.0 {
            return Color(hex: "FBBF24")
        } else {
            return Color(hex: "F87171")
        }
    }
    
    private var bmiLegend: some View {
        HStack(spacing: 12) {
            ForEach(bmiRanges, id: \.name) { range in
                HStack(spacing: 4) {
                    Circle()
                        .fill(range.color)
                        .frame(width: 8, height: 8)
                    
                    Text(NSLocalizedString(range.name, comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}
