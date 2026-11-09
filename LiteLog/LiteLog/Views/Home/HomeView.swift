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

    private var trendEntries: [TrendEntry] {
        TrendAnalytics.entries(from: Array(records))
    }

    private var allDailyEntries: [TrendEntry] {
        TrendAnalytics.dailyEntries(from: trendEntries, scope: .all)
    }

    private var periodChanges: [PeriodChange] {
        [7, 30, 90].map { days in
            PeriodChange(days: days, change: weightChange(lastDays: days))
        }
    }

    private var goalEstimate: WeightGoalEstimate? {
        guard let target = profile?.goalWeightValue else { return nil }
        return TrendAnalytics.estimateWeightGoal(
            from: allDailyEntries,
            targetWeight: target
        )
    }

    private var earliestWeight: Double? {
        allDailyEntries.first?.weight
    }

    private var earliestBodyFat: Double? {
        records.filter { $0.bodyFatPercentageValue != nil }.last?.bodyFatPercentageValue
    }

    private var earliestWaist: Double? {
        records.filter { $0.waistCircumferenceValue != nil }.last?.waistCircumferenceValue
    }

    private var earliestHip: Double? {
        records.filter { $0.hipCircumferenceValue != nil }.last?.hipCircumferenceValue
    }

    private var earliestChest: Double? {
        records.filter { $0.chestCircumferenceValue != nil }.last?.chestCircumferenceValue
    }

    private var earliestThigh: Double? {
        records.filter { $0.thighCircumferenceValue != nil }.last?.thighCircumferenceValue
    }

    private func computeCachedData() {
        latestWeight = records.first?.weight
        
        let today = Date().startOfDay
        todayRecord = records.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        
        let bodyFatRecord = records.first { $0.bodyFatPercentageValue != nil }
        latestBodyFat = bodyFatRecord?.bodyFatPercentageValue
        
        let waistRecord = records.first { $0.waistCircumferenceValue != nil }
        latestWaist = waistRecord?.waistCircumferenceValue
        
        let hipRecord = records.first { $0.hipCircumferenceValue != nil }
        latestHip = hipRecord?.hipCircumferenceValue
        
        let chestRecord = records.first { $0.chestCircumferenceValue != nil }
        latestChest = chestRecord?.chestCircumferenceValue
        
        let thighRecord = records.first { $0.thighCircumferenceValue != nil }
        latestThigh = thighRecord?.thighCircumferenceValue
        
        bodyFatProgress = latestBodyFat.map { min($0 / 50.0 * 100, 100) } ?? 0
    }


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    todayWeightCard

                    periodChangesCard

                    goalWeightCard

                    goalBodyFatCard

                    goalMeasurementsCard
                }
                .padding()
            }
            .refreshable {
                isLoading = true
                computeCachedData()
                isLoading = false
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ProfileToolbarChip {
                        showingProfileEditor = true
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

            Divider()

            bmiInlineRow

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

    @ViewBuilder
    private var bmiInlineRow: some View {
        if let profile, profile.height > 0, let latestWeight {
            BMIProgressView(
                currentWeight: latestWeight,
                height: profile.height,
                onInfoTapped: { showingBMIInfo = true }
            )
        } else if let profile, profile.height > 0 {
            bmiUnavailableRow(
                message: NSLocalizedString("home.bmi.needs.weight", comment: "")
            )
        } else {
            Button(action: { showingProfileEditor = true }) {
                HStack(spacing: 10) {
                    Text(NSLocalizedString("home.bmi", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)

                    Text("--")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.secondaryText)

                    Spacer()

                    Text(NSLocalizedString("home.bmi.needs.profile", comment: ""))
                        .font(.caption)
                        .foregroundColor(.primaryBlue)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primaryBlue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func bmiUnavailableRow(message: String) -> some View {
        HStack(spacing: 10) {
            Text(NSLocalizedString("home.bmi", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)

            Text("--")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.secondaryText)

            Spacer()

            Text(message)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }

    private var achievedGoalLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundColor(.green)

            Text(NSLocalizedString("home.goal.achieved", comment: ""))
                .font(.caption)
                .foregroundColor(.green)
        }
    }

    private var goalWeightCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "target")
                    .foregroundColor(.primaryBlue)
                
                Text(NSLocalizedString("goal.weight", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            if let profile = profile, let goalWeight = profile.goalWeightValue {
                let currentWeight = latestWeight ?? 0
                
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
                        let direction = GoalDirection.infer(
                            target: goalWeight,
                            baseline: earliestWeight,
                            current: currentWeight
                        )

                        if direction.isAchieved(current: currentWeight, target: goalWeight) {
                            achievedGoalLabel
                        } else {
                            let remaining = direction.remaining(
                                current: currentWeight,
                                target: goalWeight
                            )
                            HStack(spacing: 4) {
                                Image(systemName: direction == .decrease ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                           direction == .decrease ? NSLocalizedString("home.goal.to.lose", comment: "") : NSLocalizedString("home.goal.to.gain", comment: ""),
                                           unit.convertFromKg(remaining).smartFormatted,
                                           unit.shortName))
                                    .font(.caption)
                                    .foregroundColor(.orange)
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

    private var periodChangesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.primaryBlue)

                    Text(NSLocalizedString("home.trend.title", comment: ""))
                        .font(.headline)
                        .foregroundColor(.primaryText)
                }

                Spacer()
            }

            if periodChanges.allSatisfy({ $0.change == nil }) {
                Text(NSLocalizedString("home.trend.empty", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            } else {
                HStack(spacing: 10) {
                    ForEach(periodChanges) { item in
                        trendMetric(
                            title: String(
                                format: NSLocalizedString("home.trend.days", comment: ""),
                                item.days
                            ),
                            value: formattedWeightChange(item.change),
                            color: periodChangeColor(item.change)
                        )
                    }
                }

            }

            if let estimate = goalEstimate {
                Divider()

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "scope")
                        .font(.caption)
                        .foregroundColor(.primaryBlue)

                    Text(estimate.summaryText)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding()
        .cardStyle()
    }

    private struct PeriodChange: Identifiable {
        let days: Int
        let change: Double?

        var id: Int { days }
    }

    private func trendMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondaryText)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primaryBlue.opacity(0.05))
        .cornerRadius(10)
    }

    private func weightChange(lastDays days: Int) -> Double? {
        let entries = TrendAnalytics.entries(
            from: allDailyEntries,
            lastDays: days
        )
        guard entries.count >= 2,
              let first = entries.first?.weight,
              let last = entries.last?.weight else {
            return nil
        }
        return last - first
    }

    private func formattedWeightChange(_ change: Double?) -> String {
        guard let change else { return "--" }
        let converted = unit.convertFromKg(change)
        let sign = converted > 0 ? "+" : ""
        return "\(sign)\(converted.smartFormatted) \(unit.shortName)"
    }

    private func periodChangeColor(_ change: Double?) -> Color {
        guard let change,
              abs(unit.convertFromKg(change)) >= 0.005 else {
            return .secondaryText
        }
        return change > 0 ? .red : .green
    }

    private var goalBodyFatCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "percent")
                    .foregroundColor(.primaryBlue)
                
                Text(NSLocalizedString("goal.body.fat", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            // 只有目标体脂率和当前体脂率都为空时才展示暂无数据
            if let profile = profile, (profile.goalBodyFatPercentage != nil || latestBodyFat != nil) {
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
                            if let goal = goalBodyFat, let bodyFat = latestBodyFat {
                                let direction = GoalDirection.infer(
                                    target: goal,
                                    baseline: earliestBodyFat,
                                    current: bodyFat
                                )

                                if direction.isAchieved(current: bodyFat, target: goal) {
                                    achievedGoalLabel
                                } else {
                                    let remaining = direction.remaining(
                                        current: bodyFat,
                                        target: goal
                                    )
                                    HStack(spacing: 4) {
                                        Image(systemName: direction == .decrease ? "arrow.down" : "arrow.up")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        
                                        Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                                   direction == .decrease ? NSLocalizedString("home.goal.to.reduce", comment: "") : NSLocalizedString("home.goal.to.increase", comment: ""),
                                                   remaining.smartFormatted,
                                                   "%"))
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                Text(NSLocalizedString("common.no.data", comment: ""))
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
                
                Text(NSLocalizedString("goal.measurements", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            // 内容区域
            if let profile = profile {
                let hasWaistData = profile.goalWaistCircumferenceValue != nil || latestWaist != nil
                let hasHipData = profile.goalHipCircumferenceValue != nil || latestHip != nil
                let hasChestData = profile.goalChestCircumferenceValue != nil || latestChest != nil
                let hasThighData = profile.goalThighCircumferenceValue != nil || latestThigh != nil
                
                if hasWaistData || hasHipData || hasChestData || hasThighData {
                    VStack(spacing: 20) {
                        // 腰围
                        measurementRow(title: NSLocalizedString("measure.waist", comment: ""),
                                       goal: profile.goalWaistCircumferenceValue,
                                       current: latestWaist,
                                       baseline: earliestWaist)
                        
                        // 臀围
                        measurementRow(title: NSLocalizedString("measure.hip", comment: ""),
                                       goal: profile.goalHipCircumferenceValue,
                                       current: latestHip,
                                       baseline: earliestHip)
                        
                        // 胸围
                        measurementRow(title: NSLocalizedString("measure.chest", comment: ""),
                                       goal: profile.goalChestCircumferenceValue,
                                       current: latestChest,
                                       baseline: earliestChest)
                        
                        // 大腿围
                        measurementRow(title: NSLocalizedString("measure.thigh", comment: ""),
                                       goal: profile.goalThighCircumferenceValue,
                                       current: latestThigh,
                                       baseline: earliestThigh)
                    }
                } else {
                    Text(NSLocalizedString("common.no.data", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            } else {
                Text(NSLocalizedString("common.no.data", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .cardStyle()
    }
    
    private func measurementRow(
        title: String,
        goal: Double?,
        current: Double?,
        baseline: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：标题（无图标，无前缀）
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primaryText)
            
            // 第二行：目标
            HStack(spacing: 8) {
                Text(NSLocalizedString("home.goal.label", comment: ""))
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
                Text(NSLocalizedString("home.current.label", comment: ""))
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
                        let direction = GoalDirection.infer(
                            target: goal,
                            baseline: baseline,
                            current: current
                        )

                        if direction.isAchieved(current: current, target: goal) {
                            achievedGoalLabel
                        } else {
                            let remaining = direction.remaining(
                                current: current,
                                target: goal
                            )
                            HStack(spacing: 4) {
                                Image(systemName: direction == .decrease ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                // 围度使用"减小/增加"更合适
                                Text(String(format: NSLocalizedString("home.goal.progress", comment: ""), 
                                           direction == .decrease ? NSLocalizedString("home.goal.to.decrease", comment: "") : NSLocalizedString("home.goal.to.add", comment: ""),
                                           remaining.smartFormatted,
                                           "cm"))
                                    .font(.caption)
                                    .foregroundColor(.orange)
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
    


}
