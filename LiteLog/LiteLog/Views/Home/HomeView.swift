import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.id, ascending: true)]) 
    private var userProfile: FetchedResults<UserProfile>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]) 
    private var records: FetchedResults<WeightRecord>

    @State private var weightInput = ""
    @State private var showingAddSheet = false

    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingProfileEditor = false
    @State private var showingBMIInfo = false
    
    @State private var latestWeight: Double?
    @State private var todayRecord: WeightRecord?
    @State private var latestBodyFat: Double?
    @State private var latestWaist: Double?
    @State private var latestHip: Double?
    @State private var latestChest: Double?
    @State private var latestThigh: Double?
    @State private var bodyFatProgress: Double = 0

    private var profile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }
    private var displayName: String {
        !settingsManager.nickname.isEmpty ? settingsManager.nickname : NSLocalizedString("tab.home", comment: "")
    }
    
    private func computeCachedData() {
        latestWeight = records.first?.weight
        
        let today = Date().startOfDay
        todayRecord = records.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        
        let bodyFatRecord = records.first { $0.bodyFatPercentage != 0 }
        latestBodyFat = bodyFatRecord?.bodyFatPercentageValue
        
        let waistRecord = records.first { $0.waistCircumference != 0 }
        latestWaist = waistRecord?.waistCircumferenceValue
        
        let hipRecord = records.first { $0.hipCircumference != 0 }
        latestHip = hipRecord?.hipCircumferenceValue
        
        let chestRecord = records.first { $0.chestCircumference != 0 }
        latestChest = chestRecord?.chestCircumferenceValue
        
        let thighRecord = records.first { $0.thighCircumference != 0 }
        latestThigh = thighRecord?.thighCircumferenceValue
        
        bodyFatProgress = latestBodyFat.map { min($0 / 50.0 * 100, 100) } ?? 0
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
            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 800 : 600, alignment: .center)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingProfileEditor = true
                    }) {
                        HStack(spacing: 12) {
                            avatarImageView
                            Text(displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingAddSheet) {
                RecordFormView(isPresented: $showingAddSheet)
            }
            .navigationDestination(isPresented: $showingProfileEditor) {
                UserInfoEditorView()
            }
            .navigationDestination(isPresented: $showingBMIInfo) {
                BMIInfoView(isPresented: $showingBMIInfo)
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                computeCachedData()
            }
            .onChange(of: records.count) { _ in
                computeCachedData()
            }
        }
    }

    private var todayWeightCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("home.today", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.primaryText)

                    if let latest = latestWeight {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(unit.convertFromKg(latest).smartFormatted)
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
                    .foregroundColor(.primaryText)
                
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
                        Text(unit.convertFromKg(goalWeight).smartFormatted)
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
                        // 将差值四舍五入到两位小数后判断，避免显示"还需减重0.0kg"的情况
                        let roundedDifference = round(absDifference * 100) / 100
                        
                        if roundedDifference > 0 {
                            let isLosingWeight = currentWeight > goalWeight  // 当前体重大于目标体重，需要减重
                            HStack(spacing: 4) {
                                Image(systemName: isLosingWeight ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(isLosingWeight ? .orange : .green)
                                
                                Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                           isLosingWeight ? NSLocalizedString("home.goal.to.lose", comment: "") : NSLocalizedString("home.goal.to.gain", comment: ""),
                                           unit.convertFromKg(roundedDifference).smartFormatted,
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
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            // 只有目标体脂率和当前体脂率都为空时才展示暂无数据
            if let profile = profile, (profile.goalBodyFat != 0 || latestBodyFat != nil) {
                let goalBodyFat = profile.goalBodyFatPercentage
                let currentBodyFat = latestBodyFat ?? 0
                
                VStack(spacing: 8) {
                    // 目标一行
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(NSLocalizedString("home.goal.target", comment: ""))
                            .font(.body)
                            .foregroundColor(.secondaryText)
                        
                        if let goal = goalBodyFat {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(goal.smartFormatted)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primaryText)
                                Text("%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.primaryText)
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.secondaryText)
                        }
                        Spacer()
                    }
                    
                    // 当前一行（包含进度提示）
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(NSLocalizedString("home.goal.current", comment: ""))
                            .font(.body)
                            .foregroundColor(.secondaryText)
                        
                        if latestBodyFat != nil {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(currentBodyFat.smartFormatted)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primaryBlue)
                                Text("%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.primaryBlue)
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            // 进度提示（只有当两者都有值时才显示）
                            if let goal = goalBodyFat, latestBodyFat != nil {
                                let difference = abs(goal - currentBodyFat)
                                // 将差值四舍五入到两位小数后判断，避免显示"还需降低0.0%"的情况
                                let roundedDifference = round(difference * 100) / 100
                                
                                if roundedDifference > 0 {
                                    let isReducing = currentBodyFat > goal  // 当前体脂率大于目标体脂率，需要降低
                                    HStack(spacing: 4) {
                                        Image(systemName: isReducing ? "arrow.down" : "arrow.up")
                                            .font(.caption)
                                            .foregroundColor(isReducing ? .orange : .green)
                                        
                                        Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                                   isReducing ? NSLocalizedString("home.goal.to.reduce", comment: "") : NSLocalizedString("home.goal.to.increase", comment: ""),
                                                   roundedDifference.smartFormatted,
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
            // 始终显示图标+标题行
            HStack(spacing: 8) {
                Image(systemName: "ruler")
                    .font(.title)
                    .foregroundColor(.primaryBlue)
                
                Text(NSLocalizedString("home.goal.measurements", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            // 内容区域
            if let profile = profile {
                let hasWaistData = profile.goalWaistCircumference != 0 || latestWaist != nil
                let hasHipData = profile.goalHipCircumference != 0 || latestHip != nil
                let hasChestData = profile.goalChestCircumference != 0 || latestChest != nil
                let hasThighData = profile.goalThighCircumference != 0 || latestThigh != nil
                
                if hasWaistData || hasHipData || hasChestData || hasThighData {
                    VStack(spacing: 20) {
                        // 腰围
                        measurementRow(title: NSLocalizedString("home.waist", comment: ""),
                                       goal: profile.goalWaistCircumferenceValue,
                                       current: latestWaist)
                        
                        // 臀围
                        measurementRow(title: NSLocalizedString("home.hip", comment: ""),
                                       goal: profile.goalHipCircumferenceValue,
                                       current: latestHip)
                        
                        // 胸围
                        measurementRow(title: NSLocalizedString("home.chest", comment: ""),
                                       goal: profile.goalChestCircumferenceValue,
                                       current: latestChest)
                        
                        // 大腿围
                        measurementRow(title: NSLocalizedString("home.thigh", comment: ""),
                                       goal: profile.goalThighCircumferenceValue,
                                       current: latestThigh)
                    }
                } else {
                    Text(NSLocalizedString("home.goal.no.data", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
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
    
    private func measurementRow(title: String, goal: Double?, current: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：标题（无图标，无前缀）
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primaryText)
            
            // 第二行：目标
            HStack(spacing: 8) {
                Text("目标:")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                
                if let goal = goal {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(goal.smartFormatted)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primaryText)
                        Text("cm")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primaryText)
                    }
                } else {
                    Text("--")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.secondaryText)
                }
            }
            
            // 第三行：当前 + 进度提示
            HStack(spacing: 8) {
                Text("当前:")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                
                if let current = current {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(current.smartFormatted)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primaryBlue)
                        Text("cm")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primaryBlue)
                    }
                    
                    Spacer()

                    // 进度提示 - 只有当目标和当前都有值时才显示
                    if let goal = goal {
                        let difference = abs(goal - current)
                        // 将差值四舍五入到两位小数后判断
                        let roundedDifference = round(difference * 100) / 100
                        
                        if roundedDifference > 0 {
                            let isDecreasing = current > goal  // 当前大于目标，需要减小围度
                            HStack(spacing: 4) {
                                Image(systemName: isDecreasing ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(isDecreasing ? .orange : .green)
                                
                                // 围度使用"减小/增加"更合适
                                Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                           isDecreasing ? NSLocalizedString("home.goal.to.decrease", comment: "") : NSLocalizedString("home.goal.to.add", comment: ""),
                                           roundedDifference.smartFormatted,
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
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.secondaryText)
                    Spacer()
                }
            }
        }
    }
    
    private var bmiCard: some View {
        if let profile = profile {
            if let latest = latestWeight {
                return AnyView(BMIProgressView(
                    currentWeight: latest,
                    height: profile.height,
                    onInfoTapped: { showingBMIInfo = true }
                ))
            } else {
                return AnyView(
                    VStack(spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("home.bmi", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
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
                            .foregroundColor(.primaryText)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("home.bmi.no.profile", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        
                        Button(NSLocalizedString("action.edit", comment: "")) {
                            showingProfileEditor = true
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
        if !settingsManager.avatarUrl.isEmpty {
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
