import SwiftUI

struct TrendChartView: View {
    let data: [(Date, Double)]
    let color: Color
    let unit: String
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString(title, comment: ""))
                    .font(.headline)
                    .foregroundColor(.primaryText)
            }

            if data.isEmpty {
                emptyChartView
            } else {
                chartView
            }
        }
        .padding()
        .cardStyle()
    }

    private var emptyChartView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondaryText)

            Text(NSLocalizedString("stats.no.data", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    private var chartView: some View {
        GeometryReader { geometry in
            ZStack {
                if data.count > 1 {
                    let points = calculatePoints(in: geometry.size)
                    
                    // 渐变填充
                    if let firstPoint = points.first, let lastPoint = points.last {
                        Path { path in
                            path.move(to: CGPoint(x: firstPoint.x, y: geometry.size.height))
                            path.addLine(to: firstPoint)
                            for i in 1..<points.count {
                                path.addLine(to: points[i])
                            }
                            path.addLine(to: CGPoint(x: lastPoint.x, y: geometry.size.height))
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    }
                    
                    // 折线
                    Path { path in
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                    }
                    .stroke(color, lineWidth: 2)

                    // 数据点
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(point)
                    }
                } else if let point = data.first {
                    Text(String(format: "%.1f%@", point.1, unit))
                        .font(.title)
                        .foregroundColor(color)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(height: 200)
    }

    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard !data.isEmpty else { return [] }

        let width = size.width
        let height = size.height
        let padding: CGFloat = 20

        let maxValue = data.map { $0.1 }.max() ?? 1
        let minValue = data.map { $0.1 }.min() ?? 0
        let range = maxValue - minValue

        return data.enumerated().map { index, point in
            let x = padding + CGFloat(index) * (width - 2 * padding) / CGFloat(max(data.count - 1, 1))
            let normalizedY = range > 0 ? (point.1 - minValue) / range : 0.5
            let y = height - padding - normalizedY * (height - 2 * padding)
            return CGPoint(x: x, y: y)
        }
    }
}