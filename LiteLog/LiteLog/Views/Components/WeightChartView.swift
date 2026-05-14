import SwiftUI
import Charts

struct WeightChartView: View {
    let data: [ChartDataPoint]
    let unit: WeightUnit
    @Binding var trendType: TrendType
    let startDate: Date

    enum TrendType: String, CaseIterable {
        case week = "home.week"
        case month = "home.month"
        case quarter = "home.quarter"

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
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Weight", unit.convertFromKg(point.weight))
            )
            .foregroundStyle(Color.primaryBlue)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Weight", unit.convertFromKg(point.weight))
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
                y: .value("Weight", unit.convertFromKg(point.weight))
            )
            .foregroundStyle(Color.primaryBlue)
            .symbolSize(30)
        }
        .chartXScale(domain: startDate...Date().startOfDay)
        .chartXAxis {
            AxisMarks(values: [startDate, Date().startOfDay]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.shortDateString)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 200)
    }
}