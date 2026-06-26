import SwiftUI

struct BMITrendChartView: View {
    let data: [(Date, Double)]
    
    private let yAxisWidth: CGFloat = 24
    private let xAxisHeight: CGFloat = 26
    private let chartHeight: CGFloat = 160
    private let lineWidth: CGFloat = 2.5
    private let gridLineWidth: CGFloat = 0.5
    private let gridLineCount = 5
    private let pointSize: CGFloat = 6
    private let chartPadding: CGFloat = 8
    
    private let bmiRanges: [(range: ClosedRange<Double>, color: Color, name: String)] = [
        (0...18.4, Color(hex: "60A5FA"), NSLocalizedString("bmi.underweight", comment: "")),
        (18.5...23.9, Color(hex: "34D399"), NSLocalizedString("bmi.normal", comment: "")),
        (24.0...27.9, Color(hex: "FBBF24"), NSLocalizedString("bmi.overweight", comment: "")),
        (28.0...Double.infinity, Color(hex: "F87171"), NSLocalizedString("bmi.obese", comment: ""))
    ]
    
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
                
                ZStack(alignment: .topLeading) {
                    bmiBackground
                    gridLines
                    axisLines
                    
                    if data.count > 1 {
                        curvePath
                        dataPoints
                    } else if let point = data.first {
                        Text(String(format: "%.1f", point.1))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(bmiColor(for: point.1))
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
        .padding(.trailing, 4)
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
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: gridLineWidth, dash: [2, 4]))
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
    
    private var bmiBackground: some View {
        GeometryReader { geometry in
            let chartAreaHeight = geometry.size.height
            let chartAreaWidth = geometry.size.width
            let innerWidth = chartAreaWidth - chartPadding * 2
            let innerHeight = chartAreaHeight - chartPadding * 2
            
            let values = data.map { $0.1 }
            let maxValue = values.max() ?? 30
            let minValue = values.min() ?? 15
            let range = maxValue - minValue
            
            let margin = range * 0.1
            let displayMax = max(maxValue + margin, 35)
            let displayMin = max(minValue - margin, 10)
            let displayRange = displayMax - displayMin
            
            let segments = bmiRanges.compactMap { rangeItem -> (color: Color, height: CGFloat)? in
                let rangeStart = max(rangeItem.range.lowerBound, displayMin)
                let rangeEnd = min(rangeItem.range.upperBound, displayMax)
                
                if rangeEnd > rangeStart {
                    let percentage = (rangeEnd - rangeStart) / displayRange
                    let bgHeight = innerHeight * CGFloat(percentage)
                    return (color: rangeItem.color.opacity(0.18), height: bgHeight)
                }
                return nil
            }
            
            return VStack(spacing: 0) {
                ForEach(segments.reversed().indices, id: \.self) { index in
                    segments.reversed()[index].color
                        .frame(height: segments.reversed()[index].height)
                }
            }
            .frame(width: innerWidth)
            .offset(x: chartPadding, y: chartPadding)
        }
    }
    
    private var xAxisLabels: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: yAxisWidth)
            
            HStack(spacing: 0) {
                ForEach(calculateXAxisLabelIndices(), id: \.self) { dataIndex in
                    Text(formatDate(data[dataIndex].0))
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: xAxisHeight)
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
            .stroke(Color.white, lineWidth: lineWidth)
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
                    .fill(bmiColor(for: data[index].1))
                    .frame(width: pointSize, height: pointSize)
                    .position(x: chartPadding + points[index].x, y: chartPadding + points[index].y)
            }
        }
    }
    
    private func calculatePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        let values = data.map { $0.1 }
        let maxValue = values.max() ?? 30
        let minValue = values.min() ?? 15
        let range = maxValue - minValue
        
        let margin = range * 0.1
        let displayMax = max(maxValue + margin, 35)
        let displayMin = max(minValue - margin, 10)
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
        let maxValue = values.max() ?? 30
        let minValue = values.min() ?? 15
        let range = maxValue - minValue
        
        let margin = range * 0.1
        let displayMax = max(maxValue + margin, 35)
        let displayMin = max(minValue - margin, 10)
        let displayRange = displayMax - displayMin
        
        return displayMax - Double(index) * displayRange / Double(gridLineCount - 1)
    }
    
    private func calculateXAxisLabelIndices() -> [Int] {
        guard data.count > 0 else { return [] }
        
        let count = data.count
        let labelCount: Int
        if count <= 7 {
            labelCount = count
        } else if count <= 14 {
            labelCount = 5
        } else if count <= 30 {
            labelCount = 6
        } else {
            labelCount = 8
        }
        
        return (0..<labelCount).map { i in
            count == 1 ? 0 : Int(Double(i) * Double(count - 1) / Double(labelCount - 1))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day)"
    }
    
    private func bmiColor(for bmi: Double) -> Color {
        if bmi <= 18.4 {
            return Color(hex: "60A5FA")
        } else if bmi <= 23.9 {
            return Color(hex: "34D399")
        } else if bmi <= 27.9 {
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