import Foundation

extension String {
    var trimmingTrailingDecimalZeros: String {
        guard contains(".") else { return self }

        var result = self
        while result.last == "0" {
            result.removeLast()
        }
        if result.last == "." {
            result.removeLast()
        }
        return result
    }
}

struct TrendAxisScale {
    let displayMin: Double
    let displayMax: Double
    let tickValues: [Double]
    let decimalPlaces: Int

    init(values: [Double]) {
        let finiteValues = values.filter(\.isFinite)
        guard let dataMin = finiteValues.min(),
              let dataMax = finiteValues.max() else {
            displayMin = 0
            displayMax = 1
            tickValues = [0, 0.25, 0.5, 0.75, 1]
            decimalPlaces = 1
            return
        }

        let dataRange = dataMax - dataMin
        let scaleReference = max(abs(dataMin), abs(dataMax), 1)
        let padding: Double

        if dataRange <= max(scaleReference * 1e-9, 1e-12) {
            padding = max(scaleReference * 0.01, 0.5)
        } else {
            padding = max(dataRange * 0.20, scaleReference * 0.0005)
        }

        let paddedMin = dataMin - padding
        let paddedMax = dataMax + padding
        let rawStep = (paddedMax - paddedMin) / 5
        var step = max(Self.niceStep(atLeast: rawStep), 1)
        var minValue = 0.0
        var maxValue = 0.0
        var intervalCount = 0

        while true {
            minValue = floor(paddedMin / step) * step
            maxValue = ceil(paddedMax / step) * step

            while maxValue - minValue < 3 * step {
                minValue -= step
                maxValue += step
            }

            intervalCount = Int(((maxValue - minValue) / step).rounded())
            if intervalCount <= 5 {
                break
            }
            let candidate = Self.niceStep(atLeast: step * 1.5)
            step = candidate > step ? candidate : step * 2
        }

        displayMin = minValue
        displayMax = maxValue
        decimalPlaces = 0
        tickValues = (0...intervalCount).map { index in
            minValue + Double(index) * step
        }
    }

    var displayRange: Double {
        displayMax - displayMin
    }

    var anchorValues: [Double] {
        tickValues.reversed()
    }

    func normalizedY(for value: Double) -> Double {
        displayRange > 0 ? (value - displayMin) / displayRange : 0.5
    }

    func label(for value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    private static func niceStep(atLeast value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 2 }

        let magnitude = pow(10, floor(log10(value)))
        let normalized = value / magnitude
        let niceMultiplier: Double

        if normalized < 1.5 {
            niceMultiplier = 1
        } else if normalized < 3.5 {
            niceMultiplier = 2
        } else if normalized < 7.5 {
            niceMultiplier = 5
        } else {
            niceMultiplier = 10
        }

        return niceMultiplier * magnitude
    }

}
