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

    private var bmiCategory: UserProfile.BMICategory {
        let profile = UserProfile(height: height)
        return profile.bmiCategory(bmi: currentBMI)
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

    var body: some View {
        VStack(spacing: 16) {
            bmiView

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

    private var weightDifference: Double {
        goalWeight - currentWeight
    }

    private var weightDifferenceString: String {
        let difference = unit.convertFromKg(weightDifference)
        if weightDifference > 0 {
            return "+\(difference.weightString)"
        } else if weightDifference < 0 {
            return difference.weightString
        } else {
            return "0"
        }
    }

    private var goalView: some View {
        VStack(spacing: 8) {
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
                
                Text("\(weightDifferenceString) \(unit.shortName)")
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
            }
            .font(.subheadline)
        }
    }
}
