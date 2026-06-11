import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager

    @Query(sort: \WeightRecord.date, order: .reverse) private var allRecords: [WeightRecord]
    @Query private var userProfile: [UserProfile]

    @State private var weightInput = ""
    @State private var showingAddSheet = false

    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }

    private var latestWeight: Double? {
        allRecords.first?.weight
    }

    private var todayRecord: WeightRecord? {
        let today = Date().startOfDay
        return allRecords.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var latestBodyFatRecord: WeightRecord? {
        allRecords.first { $0.bodyFatPercentage != nil }
    }

    private var latestBodyFat: Double? {
        latestBodyFatRecord?.bodyFatPercentage
    }

    private var latestWaistRecord: WeightRecord? {
        allRecords.first { $0.waistCircumference != nil }
    }

    private var latestWaist: Double? {
        latestWaistRecord?.waistCircumference
    }

    private var latestHipRecord: WeightRecord? {
        allRecords.first { $0.hipCircumference != nil }
    }

    private var latestHip: Double? {
        latestHipRecord?.hipCircumference
    }

    private var latestChestRecord: WeightRecord? {
        allRecords.first { $0.chestCircumference != nil }
    }

    private var latestChest: Double? {
        latestChestRecord?.chestCircumference
    }

    private var bodyFatProgress: Double {
        guard let current = latestBodyFat else { return 0 }
        return min(current / 50.0 * 100, 100)
    }

    

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    todayWeightCard

                    bmiProgressSection

                    goalWeightCard
                    
                    goalBodyFatCard
                    
                    goalMeasurementsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        avatarImageView
                        Text(NSLocalizedString("tab.home", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingAddSheet) {
                RecordFormView(isPresented: $showingAddSheet)
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var todayWeightCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("home.today", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)

                    if let latest = latestWeight {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(unit.convertFromKg(latest).weightString)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)

                            Text(unit.shortName)
                                .font(.title2)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text("-- \(unit.shortName)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                }

                Spacer()
            }

            Button(action: { showingAddSheet = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text(NSLocalizedString("home.add.weight", comment: ""))
                }
                .primaryButtonStyle()
            }
        }
        .padding()
        .cardStyle()
    }

    private var goalWeightCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "target")
                    .foregroundColor(.primaryBlue)
                
                Text(NSLocalizedString("home.goal.weight", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                
                Spacer()
            }
            
            if let profile = profile {
                let currentWeight = latestWeight ?? 0
                let goalWeight = profile.goalWeight
                let difference = goalWeight - currentWeight
                
                // 目标体重和进度一行显示
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(NSLocalizedString("home.goal.target", comment: ""))
                        .font(.body)
                        .foregroundColor(.secondaryText)
                    
                    Text("\(unit.convertFromKg(goalWeight).weightString) \(unit.shortName)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryBlue)
                    
                    Spacer()
                    
                    // 进度提示
                    if latestWeight != nil {
                        let absDifference = abs(difference)
                        // 将差值四舍五入到一位小数后判断，避免显示"还需减重0.0kg"的情况
                        let roundedDifference = round(absDifference * 10) / 10
                        
                        if roundedDifference > 0 {
                            let isLosingWeight = currentWeight > goalWeight  // 当前体重大于目标体重，需要减重
                            HStack(spacing: 4) {
                                Image(systemName: isLosingWeight ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(isLosingWeight ? .orange : .green)
                                
                                Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                           isLosingWeight ? NSLocalizedString("home.goal.to.lose", comment: "") : NSLocalizedString("home.goal.to.gain", comment: ""),
                                           unit.convertFromKg(roundedDifference).weightString,
                                           unit.shortName))
                                    .font(.caption)
                                    .foregroundColor(isLosingWeight ? .orange : .green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                
                                Text(NSLocalizedString("home.goal.achieved", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } else {
                Text(NSLocalizedString("home.goal.no.profile", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .cardStyle()
    }

    private var goalBodyFatCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "percent")
                    .foregroundColor(.primaryBlue)
                
                Text(NSLocalizedString("home.goal.body.fat", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                
                Spacer()
            }
            
            // 只有目标体脂率和当前体脂率都为空时才展示暂无数据
            if let profile = profile, (profile.goalBodyFat != nil || latestBodyFat != nil) {
                let goalBodyFat = profile.goalBodyFat
                let currentBodyFat = latestBodyFat ?? 0
                
                VStack(spacing: 8) {
                    // 目标一行
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        Text(NSLocalizedString("home.goal.target", comment: ""))
                            .font(.body)
                            .foregroundColor(.secondaryText)
                        Text(goalBodyFat != nil ? String(format: "%.1f%%", goalBodyFat!) : "--")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(goalBodyFat != nil ? .primaryBlue : .secondaryText)
                        Spacer()
                    }
                    
                    // 当前一行（包含进度提示）
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        Text(NSLocalizedString("home.goal.current", comment: ""))
                            .font(.body)
                            .foregroundColor(.secondaryText)
                        Text(latestBodyFat != nil ? String(format: "%.1f%%", currentBodyFat) : "--")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.primaryText)
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            // 进度提示（只有当两者都有值时才显示）
                            if let goal = goalBodyFat, latestBodyFat != nil {
                                let difference = abs(goal - currentBodyFat)
                                // 将差值四舍五入到一位小数后判断，避免显示"还需降低0.0%"的情况
                                let roundedDifference = round(difference * 10) / 10
                                
                                if roundedDifference > 0 {
                                    let isReducing = currentBodyFat > goal  // 当前体脂率大于目标体脂率，需要降低
                                    HStack(spacing: 4) {
                                        Image(systemName: isReducing ? "arrow.down" : "arrow.up")
                                            .font(.caption)
                                            .foregroundColor(isReducing ? .orange : .green)
                                        
                                        Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                                   isReducing ? NSLocalizedString("home.goal.to.reduce", comment: "") : NSLocalizedString("home.goal.to.increase", comment: ""),
                                                   String(format: "%.1f", roundedDifference),
                                                   "%"))
                                            .font(.caption)
                                            .foregroundColor(isReducing ? .orange : .green)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        
                                        Text(NSLocalizedString("home.goal.achieved", comment: ""))
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                Text(NSLocalizedString("home.goal.no.data", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .cardStyle()
    }

    private var goalMeasurementsCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "ruler")
                    .foregroundColor(.primaryBlue)
                
                Text(NSLocalizedString("home.goal.measurements", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                
                Spacer()
            }
            
            if let profile = profile {
                VStack(spacing: 8) {
                    // 腰围
                    HStack {
                        Text(NSLocalizedString("home.waist", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                        
                        if let goal = profile.goalWaistCircumference {
                            Text(String(format: "%.1f cm", goal))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            
                            if let current = latestWaist {
                                let diff = goal - current
                                Text(String(format: "%+.1f", diff))
                                    .font(.caption)
                                    .foregroundColor(diff > 0 ? .orange : .green)
                            }
                        } else {
                            Text("--")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    // 臀围
                    HStack {
                        Text(NSLocalizedString("home.hip", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                        
                        if let goal = profile.goalHipCircumference {
                            Text(String(format: "%.1f cm", goal))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            
                            if let current = latestHip {
                                let diff = goal - current
                                Text(String(format: "%+.1f", diff))
                                    .font(.caption)
                                    .foregroundColor(diff > 0 ? .orange : .green)
                            }
                        } else {
                            Text("--")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    // 胸围
                    HStack {
                        Text(NSLocalizedString("home.chest", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                        
                        if let goal = profile.goalChestCircumference {
                            Text(String(format: "%.1f cm", goal))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            
                            if let current = latestChest {
                                let diff = goal - current
                                Text(String(format: "%+.1f", diff))
                                    .font(.caption)
                                    .foregroundColor(diff > 0 ? .orange : .green)
                            }
                        } else {
                            Text("--")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .cardStyle()
    }

    private var bmiCard: some View {
        if let profile = profile {
            if let latest = latestWeight {
                return AnyView(BMIProgressView(
                    currentWeight: latest,
                    height: profile.height
                ))
            } else {
                return AnyView(
                    VStack(spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("home.bmi", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                        }
                        
                        Text(NSLocalizedString("home.bmi.no.data", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .padding(.vertical, 20)
                    }
                    .padding()
                    .cardStyle()
                )
            }
        } else {
            return AnyView(
                VStack(spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("home.bmi", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("home.bmi.no.profile", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        
                        Button(NSLocalizedString("action.edit", comment: "")) {
                            NotificationCenter.default.post(name: .showProfileEditor, object: nil)
                        }
                        .foregroundColor(.primaryBlue)
                        .font(.subheadline)
                    }
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .cardStyle()
            )
        }
    }
    
    private var bmiProgressSection: some View {
        VStack(spacing: 16) {
            bmiCard
        }
    }
    

    
    @ViewBuilder
    private var avatarImageView: some View {
        if settingsManager.isLoggedIn, !settingsManager.avatarUrl.isEmpty {
            if let cachedImage = settingsManager.cachedAvatarImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .id(settingsManager.avatarCacheUpdated)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.primaryBlue)
            }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(.gray)
        }
    }
}
