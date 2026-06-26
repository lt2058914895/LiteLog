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
                
                ZStack(alignment: .topLeading) {
                    gridLines
                    axisLines
                    
                    if data.count > 1 {
                        gradientFill
                        curvePath
                        dataPoints
                    } else if let point = data.first {
                        Text(String(format: "%.1f%@", point.1, unit))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(color)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            
            xAxisLabels
        }
        .frame(height: chartHeight)
    }
    
    private var yAxisLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<gridLineCount, id: \.self) { index in
                let value = yAxisValue(at: index)
                Text("\(Int(value))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
                    .frame(height: (chartHeight - xAxisHeight) / CGFloat(gridLineCount - 1), alignment: .center)
            }
        }
        .frame(width: yAxisWidth, alignment: .trailing)
    }
    
    private var gridLines: some View {
        GeometryReader { geometry in
            let chartAreaHeight = geometry.size.height
            let chartAreaWidth = geometry.size.width
            
            VStack(spacing: 0) {
                ForEach(0..<gridLineCount, id: \.self) { index in
                    let y = chartPadding + CGFloat(index) * (chartAreaHeight - chartPadding * 2) / CGFloat(gridLineCount - 1)
                    Path { path in
                        path.move(to: CGPoint(x: chartPadding, y: y))
                        path.addLine(to: CGPoint(x: chartAreaWidth - chartPadding, y: y))
                    }
                    .stroke(Color.tertiaryBackground, style: StrokeStyle(lineWidth: gridLineWidth, dash: [2, 4]))
                }
            }
        }
    }
    
    private var axisLines: some View {
        GeometryReader { geometry in
            let chartAreaHeight = geometry.size.height
            let chartAreaWidth = geometry.size.width
            
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: chartPadding, y: chartPadding))
                    path.addLine(to: CGPoint(x: chartPadding, y: chartAreaHeight - chartPadding))
                }
                .stroke(Color.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                
                Path { path in
                    path.move(to: CGPoint(x: chartPadding, y: chartAreaHeight - chartPadding))
                    path.addLine(to: CGPoint(x: chartAreaWidth - chartPadding, y: chartAreaHeight - chartPadding))
                }
                .stroke(Color.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
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
    
    private var gradientFill: some View {
        GeometryReader { geometry in
            let chartAreaHeight = geometry.size.height
            let chartAreaWidth = geometry.size.width
            let innerWidth = chartAreaWidth - chartPadding * 2
            let innerHeight = chartAreaHeight - chartPadding * 2
            
            let points = calculatePoints(width: innerWidth, height: innerHeight)
            let fillPath = createFillPath(points: points, width: innerWidth, height: innerHeight)
            
            fillPath.fill(LinearGradient(
                colors: [color.opacity(0.25), color.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .offset(x: chartPadding, y: chartPadding)
        }
    }
    
    private var curvePath: some View {
        GeometryReader { geometry in
            let chartAreaHeight = geometry.size.height
            let chartAreaWidth = geometry.size.width
            let innerWidth = chartAreaWidth - chartPadding * 2
            let innerHeight = chartAreaHeight - chartPadding * 2
            
            let points = calculatePoints(width: innerWidth, height: innerHeight)
            Path { path in
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
    }
    
    private var dataPoints: some View {
        GeometryReader { geometry in
            let chartAreaHeight = geometry.size.height
            let chartAreaWidth = geometry.size.width
            let innerWidth = chartAreaWidth - chartPadding * 2
            let innerHeight = chartAreaHeight - chartPadding * 2
            
            let points = calculatePoints(width: innerWidth, height: innerHeight)
            
            ForEach(points.indices, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: pointSize, height: pointSize)
                    .position(x: chartPadding + points[index].x, y: chartPadding + points[index].y)
            }
        }
    }
    
    private func calculatePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        let values = data.map { $0.1 }
        let maxValue = values.max() ?? 1
        let minValue = values.min() ?? 0
        let range = maxValue - minValue
        
        let margin = range * 0.1
        let displayMax = maxValue + margin
        let displayMin = max(minValue - margin, 0)
        let displayRange = displayMax - displayMin
        
        return data.enumerated().map { index, point in
            let x = CGFloat(index) * width / CGFloat(max(data.count - 1, 1))
            let normalizedY = displayRange > 0 ? (point.1 - displayMin) / displayRange : 0.5
            let y = height - normalizedY * height
            return CGPoint(x: x, y: y)
        }
    }
    
    private func yAxisValue(at index: Int) -> Double {
        let values = data.map { $0.1 }
        let maxValue = values.max() ?? 1
        let minValue = values.min() ?? 0
        let range = maxValue - minValue
        
        let margin = range * 0.1
        let displayMax = maxValue + margin
        let displayMin = max(minValue - margin, 0)
        let displayRange = displayMax - displayMin
        
        return displayMax - Double(index) * displayRange / Double(gridLineCount - 1)
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