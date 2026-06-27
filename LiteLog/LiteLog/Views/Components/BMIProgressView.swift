import SwiftUI
import CoreData

struct BMIProgressView: View {
    let currentWeight: Double
    let height: Double
    var onInfoTapped: (() -> Void)? = nil

    private let currentBMI: Double
    private let bmiCategory: UserProfile.BMICategory
    private let bmiCategoryColor: Color

    init(currentWeight: Double, height: Double, onInfoTapped: (() -> Void)? = nil) {
        self.currentWeight = currentWeight
        self.height = height
        self.onInfoTapped = onInfoTapped
        
        let heightInMeters = height / 100.0
        self.currentBMI = currentWeight / (heightInMeters * heightInMeters)
        self.bmiCategory = UserProfile.BMICategory.from(bmi: self.currentBMI)
        self.bmiCategoryColor = bmiCategory.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("home.bmi", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Button(action: {
                    onInfoTapped?()
                }) {
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
