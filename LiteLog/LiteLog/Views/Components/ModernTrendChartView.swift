import SwiftUI

struct ModernTrendChartView: View {
    let data: [(Date, Double)]
    let color: Color
    let unit: String
    let title: String
    
    private let yAxisWidth: CGFloat = 20
    private let xAxisHeight: CGFloat = 26
    private let chartHeight: CGFloat = 180
    private let lineWidth: CGFloat = 2.5
    private let gridLineWidth: CGFloat = 0.5
    private let gridLineCount = 5
    private let pointSize: CGFloat = 6
    private let chartPadding: CGFloat = 8
    
    private var chartData: ChartData {
        ChartData(data: data)
    }
    
    struct ChartData {
        let values: [Double]
        let maxValue: Double
        let minValue: Double
        let range: Double
        let displayMax: Double
        let displayMin: Double
        let displayRange: Double
        
        init(data: [(Date, Double)]) {
            self.values = data.map { $0.1 }
            self.maxValue = values.max() ?? 1
            self.minValue = values.min() ?? 0
            self.range = maxValue - minValue
            
            let margin = range * 0.1
            self.displayMax = maxValue + margin
            self.displayMin = max(minValue - margin, 0)
            self.displayRange = displayMax - displayMin
        }
        
        func normalizedY(for value: Double) -> Double {
            displayRange > 0 ? (value - displayMin) / displayRange : 0.5
        }
        
        func yAxisValue(at index: Int, total: Int) -> Double {
            displayMax - Double(index) * displayRange / Double(total - 1)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Text(NSLocalizedString(title, comment: ""))
                    .font(.headline)
                    .foregroundColor(.primaryText)
            }
            
            if data.isEmpty {
                emptyStateView
            } else {
                chartView
            }
        }
        .padding()
        .cardStyle()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
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
        VStack(spacing: 0) {
            ForEach(0..<gridLineCount, id: \.self) { index in
                let value = chartData.yAxisValue(at: index, total: gridLineCount)
                Text("\(Int(value))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
                    .frame(height: (chartHeight - xAxisHeight) / CGFloat(gridLineCount - 1), alignment: .center)
            }
        }
        .frame(width: yAxisWidth, alignment: .trailing)
    }
    
    private var chartContent: some View {
        GeometryReader { geometry in
            let chartAreaHeight = geometry.size.height
            let chartAreaWidth = geometry.size.width
            let innerWidth = chartAreaWidth - chartPadding * 2
            let innerHeight = chartAreaHeight - chartPadding * 2
            
            ZStack(alignment: .topLeading) {
                gridLines(width: innerWidth, height: innerHeight)
                axisLines(width: innerWidth, height: innerHeight)
                
                if data.count > 1 {
                    gradientFill(width: innerWidth, height: innerHeight)
                    curvePath(width: innerWidth, height: innerHeight)
                    dataPoints(width: innerWidth, height: innerHeight)
                } else if let point = data.first {
                    Text(String(format: "%.1f%@", point.1, unit))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(color)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .drawingGroup()
    }
    
    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<gridLineCount, id: \.self) { index in
                let y = chartPadding + CGFloat(index) * (height + chartPadding) / CGFloat(gridLineCount - 1)
                Path { path in
                    path.move(to: CGPoint(x: chartPadding, y: y))
                    path.addLine(to: CGPoint(x: width + chartPadding, y: y))
                }
                .stroke(Color.tertiaryBackground, style: StrokeStyle(lineWidth: gridLineWidth, dash: [2, 4]))
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
    
    private func gradientFill(width: CGFloat, height: CGFloat) -> some View {
        let points = calculatePoints(width: width, height: height)
        let fillPath = createFillPath(points: points, width: width, height: height)
        
        return fillPath.fill(LinearGradient(
            colors: [color.opacity(0.25), color.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        ))
        .offset(x: chartPadding, y: chartPadding)
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
        .stroke(color, lineWidth: lineWidth)
        .offset(x: chartPadding, y: chartPadding)
    }
    
    private func dataPoints(width: CGFloat, height: CGFloat) -> some View {
        let points = calculatePoints(width: width, height: height)
        
        return ForEach(points.indices, id: \.self) { index in
            Circle()
                .fill(color)
                .frame(width: pointSize, height: pointSize)
                .position(x: chartPadding + points[index].x, y: chartPadding + points[index].y)
        }
    }
    
    private func calculatePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        data.enumerated().map { index, point in
            let x = CGFloat(index) * width / CGFloat(max(data.count - 1, 1))
            let normalizedY = chartData.normalizedY(for: point.1)
            let y = height - normalizedY * height
            return CGPoint(x: x, y: y)
        }
    }
    
    private func createFillPath(points: [CGPoint], width: CGFloat, height: CGFloat) -> Path {
        guard points.count >= 2 else { return Path() }
        
        return Path { path in
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: points[0])
            
            if points.count == 2 {
                path.addLine(to: points[1])
            } else {
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
            
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
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
}
