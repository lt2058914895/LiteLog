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
                                .foregroundColor(.primaryBlue)

                            Text(unit.shortName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryBlue)
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
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(unit.convertFromKg(goalWeight).weightString)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primaryText)

                        Text(unit.shortName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primaryText)
                    }
                    
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
                            .foregroundColor(goalBodyFat != nil ? .primaryText : .secondaryText)
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
            if let profile = profile {
                VStack(spacing: 20) {
                    // 腰围
                    measurementRow(title: NSLocalizedString("home.waist", comment: ""),
                                   goal: profile.goalWaistCircumference,
                                   current: latestWaist)
                    
                    // 臀围
                    measurementRow(title: NSLocalizedString("home.hip", comment: ""),
                                   goal: profile.goalHipCircumference,
                                   current: latestHip)
                    
                    // 胸围
                    measurementRow(title: NSLocalizedString("home.chest", comment: ""),
                                   goal: profile.goalChestCircumference,
                                   current: latestChest)
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
    
    private func measurementRow(title: String, goal: Double?, current: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：图标 + 标题
            HStack(spacing: 8) {
                Image(systemName: iconForMeasurement(title))
                    .font(.system(size: 18))
                    .foregroundColor(.primaryBlue)
                
                Text("目标\(title)")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            
            // 第二行：目标
            HStack(spacing: 8) {
                Text("目标:")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                
                if let goal = goal {
                    Text(String(format: "%.1fcm", goal))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                } else {
                    Text("--")
                        .font(.body)
                        .foregroundColor(.secondaryText)
                }
            }
            
            // 第三行：当前 + 进度提示
            HStack(spacing: 8) {
                Text("当前:")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                
                if let current = current {
                    Text(String(format: "%.1fcm", current))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                    
                    Spacer()

                    // 进度提示 - 只有当目标和当前都有值时才显示
                    if let goal = goal {
                        let difference = abs(goal - current)
                        let roundedDifference = round(difference * 10) / 10
                        
                        if roundedDifference > 0 {
                            let isDecreasing = current > goal  // 当前大于目标，需要减小围度
                            HStack(spacing: 4) {
                                Image(systemName: isDecreasing ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(isDecreasing ? .orange : .green)
                                
                                // 围度使用"减小/增加"更合适
                                Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                           isDecreasing ? NSLocalizedString("home.goal.to.decrease", comment: "") : NSLocalizedString("home.goal.to.add", comment: ""),
                                           String(format: "%.1f", roundedDifference),
                                           "cm"))
                                    .font(.caption)
                                    .foregroundColor(isDecreasing ? .orange : .green)
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
                } else {
                    Text("--")
                        .font(.body)
                        .foregroundColor(.secondaryText)
                    Spacer()
                }
            }
        }
    }
    
    private func iconForMeasurement(_ title: String) -> String {
        switch title {
        case "腰围":
            return "figure.walk"
        case "臀围":
            return "figure.stand"
        case "胸围":
            return "heart.fill"
        default:
            return "ruler"
        }
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
