import SwiftUI
import Charts

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
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Waist", point.waist)
            )
            .foregroundStyle(Color.primaryBlue)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Waist", point.waist)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.primaryBlue.opacity(0.3), Color.primaryBlue.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date),
                y: .value("Waist", point.waist)
            )
            .foregroundStyle(Color.primaryBlue)
            .symbolSize(30)
        }
        .chartXAxis {
            AxisMarks(values: [data.first?.date, data.last?.date].compactMap { $0 }) { value in
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let value = value.as(Double.self) {
                        Text(String(format: "%.0fcm", value))
                    }
                }
            }
        }
        .frame(height: 200)
    }
}
