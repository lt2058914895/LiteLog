import SwiftUI
import SwiftData

struct BMIInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfile: [UserProfile]
    @Query(sort: \WeightRecord.date, order: .reverse) private var allRecords: [WeightRecord]
    
    private var profile: UserProfile? { userProfile.first }
    
    private var latestWeightRecord: WeightRecord? {
        allRecords.first
    }
    
    private var bmiCategories: [(range: ClosedRange<Double>, name: String, color: Color)] {
        [
            (0...18.4, NSLocalizedString("bmi.underweight", comment: ""), Color.blue),
            (18.5...23.9, NSLocalizedString("bmi.normal", comment: ""), Color.green),
            (24.0...27.9, NSLocalizedString("bmi.overweight", comment: ""), Color.orange),
            (28.0...Double.infinity, NSLocalizedString("bmi.obese", comment: ""), Color.red)
        ]
    }
    
    private var bodyFatRanges: [(range: ClosedRange<Double>, name: String, color: Color, gender: String)] {
        [
            (6...13, NSLocalizedString("body.fat.essential", comment: ""), Color.blue, "male"),
            (14...17, NSLocalizedString("body.fat.athletic", comment: ""), Color.green, "male"),
            (18...24, NSLocalizedString("body.fat.average", comment: ""), Color.yellow, "male"),
            (25...Double.infinity, NSLocalizedString("body.fat.obese", comment: ""), Color.red, "male"),
            (14...20, NSLocalizedString("body.fat.essential", comment: ""), Color.blue, "female"),
            (21...24, NSLocalizedString("body.fat.athletic", comment: ""), Color.green, "female"),
            (25...31, NSLocalizedString("body.fat.average", comment: ""), Color.yellow, "female"),
            (32...Double.infinity, NSLocalizedString("body.fat.obese", comment: ""), Color.red, "female")
        ]
    }
    
    private var currentBMI: Double? {
        guard let profile = profile, let latestRecord = latestWeightRecord else { return nil }
        let heightInMeters = profile.height / 100.0
        return latestRecord.weight / (heightInMeters * heightInMeters)
    }
    
    private var currentBodyFat: Double? {
        latestWeightRecord?.bodyFatPercentage
    }
    
    private var bmiCategory: UserProfile.BMICategory? {
        guard let bmi = currentBMI else { return nil }
        return profile?.bmiCategory(bmi: bmi)
    }
    
    private var bodyFatStatus: (name: String, color: Color)? {
        guard let bodyFat = currentBodyFat, let profile = profile else { return nil }
        let gender = profile.gender == .male ? "male" : "female"
        if let range = bodyFatRanges.first(where: { $0.gender == gender && $0.range.contains(bodyFat) }) {
            return (name: range.name, color: range.color)
        }
        return nil
    }
    
    private var comprehensiveRating: String {
        guard let bmiCat = bmiCategory, let bodyFat = currentBodyFat, let profile = profile else {
            return NSLocalizedString("rating.insufficient", comment: "")
        }
        
        let gender = profile.gender == .male ? "male" : "female"
        let bodyFatRange = bodyFatRanges.first { $0.gender == gender && $0.range.contains(bodyFat) }
        
        if bmiCat == .normal {
            if let bfRange = bodyFatRange {
                if bfRange.color == .green {
                    return NSLocalizedString("rating.excellent", comment: "")
                } else if bfRange.color == .yellow {
                    return NSLocalizedString("rating.hidden.obesity", comment: "")
                } else if bfRange.color == .red {
                    return NSLocalizedString("rating.hidden.obesity.severe", comment: "")
                }
            }
        } else if bmiCat == .overweight || bmiCat == .obese {
            if let bfRange = bodyFatRange, bfRange.color == .green {
                return NSLocalizedString("rating.muscle.heavy", comment: "")
            }
        }
        
        return NSLocalizedString("rating.needs.improvement", comment: "")
    }
    
    private var comprehensiveRatingColor: Color {
        if comprehensiveRating.contains(NSLocalizedString("rating.excellent", comment: "")) {
            return .green
        } else if comprehensiveRating.contains(NSLocalizedString("rating.hidden", comment: "")) {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let profile = profile {
                        currentStatusCard
                        
                        bmiStandardSection
                        
                        bodyFatStandardSection
                        
                        comprehensiveAnalysisSection
                        
                        referenceRangeSection(gender: profile.gender, age: profile.age, height: profile.height)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("bmi.info.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var currentStatusCard: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("bmi.info.current.status", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)
            
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("bmi.info.bmi", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    if let bmi = currentBMI {
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%.1f", bmi))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)
                            
                            if let category = bmiCategory {
                                Text(category.displayName)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(category.color)
                                    .cornerRadius(4)
                            }
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text(NSLocalizedString("bmi.info.body.fat", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    if let bodyFat = currentBodyFat {
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%.1f", bodyFat))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)
                            
                            Text("%")
                                .font(.title)
                                .foregroundColor(.secondaryText)
                            
                            if let status = bodyFatStatus {
                                Text(status.name)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(status.color)
                                    .cornerRadius(4)
                            }
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("bmi.info.comprehensive.rating", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                
                Text(comprehensiveRating)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(comprehensiveRatingColor)
            }
        }
        .padding()
        .cardStyle()
    }
    
    private var bmiStandardSection: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("bmi.info.standard.bmi", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                ForEach(bmiCategories, id: \.name) { category in
                    HStack {
                        HStack {
                            category.color
                                .frame(width: 24, height: 24)
                                .cornerRadius(6)
                            
                            Text(category.name)
                                .font(.body)
                                .foregroundColor(.primaryText)
                        }
                        .frame(width: 120)
                        
                        Spacer()
                        
                        Text(formatRange(category.range))
                            .font(.body)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            Text(NSLocalizedString("bmi.info.bmi.note", comment: ""))
                .font(.caption)
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .cardStyle()
    }
    
    private var bodyFatStandardSection: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("bmi.info.standard.body.fat", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("bmi.info.male", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(bodyFatRanges.filter { $0.gender == "male" }, id: \.name) { range in
                        HStack {
                            range.color
                                .frame(width: 24, height: 24)
                                .cornerRadius(6)
                            
                            Text(range.name)
                                .font(.body)
                                .foregroundColor(.primaryText)
                                .frame(width: 100)
                            
                            Spacer()
                            
                            Text(formatBodyFatRange(range.range))
                                .font(.body)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    Text(NSLocalizedString("bmi.info.female", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(bodyFatRanges.filter { $0.gender == "female" }, id: \.name) { range in
                        HStack {
                            range.color
                                .frame(width: 24, height: 24)
                                .cornerRadius(6)
                            
                            Text(range.name)
                                .font(.body)
                                .foregroundColor(.primaryText)
                                .frame(width: 100)
                            
                            Spacer()
                            
                            Text(formatBodyFatRange(range.range))
                                .font(.body)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            }
            
            Text(NSLocalizedString("bmi.info.body.fat.note", comment: ""))
                .font(.caption)
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .cardStyle()
    }
    
    private var comprehensiveAnalysisSection: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("bmi.info.comprehensive.analysis", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                analysisCard(
                    title: NSLocalizedString("analysis.normal.bmi.normal.fat", comment: ""),
                    description: NSLocalizedString("analysis.normal.bmi.normal.fat.desc", comment: ""),
                    color: .green
                )
                
                analysisCard(
                    title: NSLocalizedString("analysis.normal.bmi.high.fat", comment: ""),
                    description: NSLocalizedString("analysis.normal.bmi.high.fat.desc", comment: ""),
                    color: .orange
                )
                
                analysisCard(
                    title: NSLocalizedString("analysis.overweight.normal.fat", comment: ""),
                    description: NSLocalizedString("analysis.overweight.normal.fat.desc", comment: ""),
                    color: .yellow
                )
                
                analysisCard(
                    title: NSLocalizedString("analysis.overweight.high.fat", comment: ""),
                    description: NSLocalizedString("analysis.overweight.high.fat.desc", comment: ""),
                    color: .red
                )
            }
        }
        .padding()
        .cardStyle()
    }
    
    private func analysisCard(title: String, description: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                color
                    .frame(width: 8, height: 24)
                    .cornerRadius(4)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
            }
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.leading, 16)
        }
    }
    
    private func referenceRangeSection(gender: UserProfile.Gender, age: Int, height: Double) -> some View {
        let idealWeightRange = calculateIdealWeightRange(height: height)
        let healthyBMI = 18.5...23.9
        let minHealthyWeight = healthyBMI.lowerBound * (height / 100.0) * (height / 100.0)
        let maxHealthyWeight = healthyBMI.upperBound * (height / 100.0) * (height / 100.0)
        
        return VStack(spacing: 12) {
            Text(NSLocalizedString("bmi.info.reference", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                referenceRow(
                    label: NSLocalizedString("reference.gender", comment: ""),
                    value: gender == .male ? NSLocalizedString("bmi.info.male", comment: "") : NSLocalizedString("bmi.info.female", comment: "")
                )
                
                referenceRow(
                    label: NSLocalizedString("reference.age", comment: ""),
                    value: "\(age) " + NSLocalizedString("reference.age.unit", comment: "")
                )
                
                referenceRow(
                    label: NSLocalizedString("reference.height", comment: ""),
                    value: String(format: "%.1f cm", height)
                )
                
                referenceRow(
                    label: NSLocalizedString("reference.ideal.weight", comment: ""),
                    value: String(format: "%.1f - %.1f kg", idealWeightRange.lowerBound, idealWeightRange.upperBound)
                )
                
                referenceRow(
                    label: NSLocalizedString("reference.healthy.weight", comment: ""),
                    value: String(format: "%.1f - %.1f kg", minHealthyWeight, maxHealthyWeight)
                )
            }
        }
        .padding()
        .cardStyle()
    }
    
    private func referenceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
        }
    }
    
    private func calculateIdealWeightRange(height: Double) -> ClosedRange<Double> {
        let baseWeight = height - 105
        return (baseWeight * 0.9)...(baseWeight * 1.1)
    }
    
    private func formatRange(_ range: ClosedRange<Double>) -> String {
        if range.upperBound == Double.infinity {
            return String(format: "%.1f+", range.lowerBound)
        }
        return String(format: "%.1f - %.1f", range.lowerBound, range.upperBound)
    }
    
    private func formatBodyFatRange(_ range: ClosedRange<Double>) -> String {
        if range.upperBound == Double.infinity {
            return String(format: "%.0f%%+", range.lowerBound)
        }
        return String(format: "%.0f%% - %.0f%%", range.lowerBound, range.upperBound)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondaryText)
            
            Text(NSLocalizedString("bmi.info.no.profile", comment: ""))
                .font(.body)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            
            Button(NSLocalizedString("action.edit", comment: "")) {
                NotificationCenter.default.post(name: .showProfileEditor, object: nil)
            }
            .foregroundColor(.primaryBlue)
            .font(.subheadline)
        }
        .frame(maxHeight: .infinity)
    }
}
