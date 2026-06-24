import SwiftUI

struct WaistCircumferenceChartView: View {
    let data: [ChartDataPoint]

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let waist: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("home.trend", comment: ""))
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

            Text(NSLocalizedString("home.no.records", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    private var chartView: some View {
        GeometryReader { geometry in
            ZStack {
                // 简化的折线图
                if data.count > 1 {
                    let points = calculatePoints(in: geometry.size)
                    Path { path in
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                    }
                    .stroke(Color.primaryBlue, lineWidth: 2)

                    // 数据点
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(Color.primaryBlue)
                            .frame(width: 6, height: 6)
                            .position(point)
                    }
                } else if let point = data.first {
                    Text(String(format: "%.0fcm", point.waist))
                        .font(.title)
                        .foregroundColor(.primaryBlue)
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

        let maxWaist = data.map { $0.waist }.max() ?? 1
        let minWaist = data.map { $0.waist }.min() ?? 0
        let range = maxWaist - minWaist

        return data.enumerated().map { index, point in
            let x = padding + CGFloat(index) * (width - 2 * padding) / CGFloat(max(data.count - 1, 1))
            let normalizedY = range > 0 ? (point.waist - minWaist) / range : 0.5
            let y = height - padding - normalizedY * (height - 2 * padding)
            return CGPoint(x: x, y: y)
        }
    }
}
