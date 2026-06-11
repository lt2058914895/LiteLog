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

                    HStack(spacing: 16) {
                        goalWeightCard
                            .frame(maxWidth: .infinity)
                        goalBodyFatCard
                            .frame(maxWidth: .infinity)
                    }
                    
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
            
            VStack(alignment: .leading, spacing: 8) {
                if let profile = profile {
                    let currentWeight = latestWeight ?? 0
                    let goalWeight = profile.goalWeight
                    let difference = goalWeight - currentWeight
                    let differenceString = difference > 0 ? "+\(unit.convertFromKg(difference).weightString)" : unit.convertFromKg(difference).weightString
                    
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(unit.convertFromKg(goalWeight).weightString) \(unit.shortName)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primaryText)
                            
                            Text(NSLocalizedString("home.goal.target", comment: ""))
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if latestWeight != nil {
                                Text(differenceString)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(difference > 0 ? .orange : .green)
                                
                                Text(NSLocalizedString("home.goal.current", comment: ""))
                                    .font(.caption2)
                                    .foregroundColor(.secondaryText)
                            } else {
                                Text("--")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondaryText)
                                
                                Text(NSLocalizedString("home.goal.current", comment: ""))
                                    .font(.caption2)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                } else {
                    Text("-- \(unit.shortName)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.secondaryText)
                }
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
            
            VStack(alignment: .leading, spacing: 8) {
                if let profile = profile, let goalBodyFat = profile.goalBodyFat {
                    let currentBodyFat = latestBodyFat ?? 0
                    let difference = goalBodyFat - currentBodyFat
                    let differenceString = difference > 0 ? "+\(String(format: "%.1f", difference))%" : String(format: "%.1f%%", difference)
                    
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(String(format: "%.1f", goalBodyFat))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primaryText)
                                
                                Text("%")
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            Text(NSLocalizedString("home.goal.target", comment: ""))
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if latestBodyFat != nil {
                                Text(differenceString)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(difference > 0 ? .orange : .green)
                                
                                Text(NSLocalizedString("home.goal.current", comment: ""))
                                    .font(.caption2)
                                    .foregroundColor(.secondaryText)
                            } else {
                                Text("--")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondaryText)
                                
                                Text(NSLocalizedString("home.goal.current", comment: ""))
                                    .font(.caption2)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                } else {
                    Text("-- %")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.secondaryText)
                }
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