import SwiftUI

struct WeightChartView: View {
    let data: [ChartDataPoint]
    let unit: WeightUnit
    @Binding var trendType: TrendType

    enum TrendType: String, CaseIterable {
        case day = "home.day"
        case week = "home.week"
        case month = "home.month"

        var localizedKey: String { rawValue }
    }

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("home.trend", comment: ""))
                    .font(.headline)
                    .foregroundColor(.primaryText)

                Spacer()

                Picker(NSLocalizedString("home.trend", comment: ""), selection: $trendType) {
                    ForEach(TrendType.allCases, id: \.self) { type in
                        Text(NSLocalizedString(type.localizedKey, comment: ""))
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
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
        VStack(spacing: 16) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let minWeight = data.map { $0.weight }.min() ?? 0
                let maxWeight = data.map { $0.weight }.max() ?? 100
                let range = max(maxWeight - minWeight, 1.0)

                ZStack {
                    gridLines(height: height)

                    if data.count > 1 {
                        linePath(width: width, height: height, minWeight: minWeight, range: range)
                            .stroke(
                                LinearGradient(
                                    colors: [.primaryBlue, .lightBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )

                        dataPoints(width: width, height: height, minWeight: minWeight, range: range)
                    } else {
                        singlePointView(height: height, minWeight: minWeight, range: range)
                    }
                }
            }
            .frame(height: 180)

            dateLabelsView
        }
    }

    private func gridLines(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                Divider()
                    .background(Color.secondaryText.opacity(0.2))
                Spacer()
            }
            Divider()
                .background(Color.secondaryText.opacity(0.2))
        }
    }

    private func linePath(width: CGFloat, height: CGFloat, minWeight: Double, range: Double) -> Path {
        Path { path in
            let stepX = width / CGFloat(data.count - 1)

            for (index, point) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let y = height - ((point.weight - minWeight) / range) * height

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func dataPoints(width: CGFloat, height: CGFloat, minWeight: Double, range: Double) -> some View {
        let stepX = width / CGFloat(data.count - 1)

        return ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
            let x = CGFloat(index) * stepX
            let y = height - ((point.weight - minWeight) / range) * height

            Circle()
                .fill(Color.primaryBlue)
                .frame(width: 8, height: 8)
                .position(x: x, y: y)
        }
    }

    private func singlePointView(height: CGFloat, minWeight: Double, range: Double) -> some View {
        let y = height - ((data[0].weight - minWeight) / range) * height

        return Circle()
            .fill(Color.primaryBlue)
            .frame(width: 12, height: 12)
            .position(x: 40, y: y)
    }

    private var dateLabelsView: some View {
        HStack {
            if let firstDate = data.first?.date {
                Text(firstDate.shortDateString)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }

            Spacer()

            if let lastDate = data.last?.date, data.count > 1 {
                Text(lastDate.shortDateString)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
    }
}
