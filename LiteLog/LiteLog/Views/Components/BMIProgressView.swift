import SwiftUI

struct BMIProgressView: View {
    let currentWeight: Double
    let goalWeight: Double
    let height: Double
    let unit: WeightUnit

    private var currentBMI: Double {
        let heightInMeters = height / 100.0
        return currentWeight / (heightInMeters * heightInMeters)
    }

    private var goalBMI: Double {
        let heightInMeters = height / 100.0
        return goalWeight / (heightInMeters * heightInMeters)
    }

    private var bmiCategory: UserProfile.BMICategory {
        let profile = UserProfile(height: height)
        return profile.bmiCategory(bmi: currentBMI)
    }

    private var progress: Double {
        guard goalWeight < currentWeight else { return 1.0 }
        let totalLoss = currentWeight - goalWeight
        return min(max(totalLoss / 10.0, 0), 1.0)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                bmiView
                progressView
            }

            goalView
        }
        .padding()
        .cardStyle()
    }

    private var bmiView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("home.bmi", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currentBMI.bmiString)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)

                Text(bmiCategory.displayName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bmiCategoryColor)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bmiCategoryColor: Color {
        switch bmiCategory {
        case .underweight:
            return .blue
        case .normal:
            return .green
        case .overweight:
            return .orange
        case .obese:
            return .red
        }
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("home.progress", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondaryBackground)
                    .frame(width: 80, height: 12)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primaryBlue)
                    .frame(width: 80 * progress, height: 12)
            }

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var goalView: some View {
        HStack {
            Image(systemName: "target")
                .foregroundColor(.primaryBlue)

            Text("\(NSLocalizedString("home.goal", comment: "")): ")
                .foregroundColor(.secondaryText)

            Text("\(unit.convertFromKg(goalWeight).weightString) \(unit.shortName)")
                .fontWeight(.medium)
                .foregroundColor(.primaryText)

            Text("(\(unit.convertFromKg(currentWeight).weightString) \(unit.shortName))")
                .foregroundColor(.secondaryText)

            Spacer()
        }
        .font(.subheadline)
    }
}
