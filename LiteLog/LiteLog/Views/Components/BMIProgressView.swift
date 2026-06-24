import SwiftUI
import CoreData

struct BMIProgressView: View {
    let currentWeight: Double
    let height: Double

    private var currentBMI: Double {
        let heightInMeters = height / 100.0
        return currentWeight / (heightInMeters * heightInMeters)
    }

    private var bmiCategory: UserProfile.BMICategory {
        let profile = UserProfile.create(in: PersistenceController.shared.viewContext)
        profile.height = height
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("home.bmi", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                NavigationLink(destination: BMIInfoView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text(NSLocalizedString("bmi.tips", comment: ""))
                    }
                    .font(.caption)
                    .foregroundColor(.primaryBlue)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currentBMI.smartFormatted)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
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
        .padding()
        .cardStyle()
    }
}
