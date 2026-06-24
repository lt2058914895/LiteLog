import Foundation
import CoreData

class MockDataManager {
    static let shared = MockDataManager()
    
    private init() {}
    
    func populateMockData(context: NSManagedObjectContext) {
        let calendar = Calendar.current
        
        // 检查是否已有用户配置
        let profileFetch = UserProfile.fetchRequest()
        if (try? context.fetch(profileFetch))?.isEmpty ?? true {
            createMockProfile(context: context)
        }
        
        // 检查是否已有体重记录
        let recordFetch = WeightRecord.fetchRequest()
        if (try? context.fetch(recordFetch))?.isEmpty ?? true {
            createMockRecords(context: context, calendar: calendar)
        }
    }
    
    private func createMockProfile(context: NSManagedObjectContext) {
        let profile = UserProfile.create(in: context)
        profile.height = 175.0
        profile.gender = UserProfile.Gender.male.rawValue
        profile.age = 28
        profile.goalWeight = 70.0
        profile.goalBodyFat = 15.0
        profile.goalWaistCircumference = 78.0
        profile.goalHipCircumference = 92.0
        profile.goalChestCircumference = 98.0
        profile.goalThighCircumference = 54.0
        profile.weightUnit = WeightUnit.kg.rawValue
        profile.createdAt = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        profile.updatedAt = Date()
        profile.syncStatus = UserProfile.SyncStatus.synced.rawValue
    }
    
    private func createMockRecords(context: NSManagedObjectContext, calendar: Calendar) {
        // 生成过去30天的体重记录
        let startDate = calendar.date(byAdding: .day, value: -29, to: Date()) ?? Date()
        
        // 模拟体重变化趋势：从75kg逐渐下降到71.5kg
        var currentWeight = 75.0
        let targetWeight = 71.5
        let totalDays = 30
        let dailyDecrease = (75.0 - targetWeight) / Double(totalDays)
        
        for dayOffset in 0..<totalDays {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) ?? Date()
            
            // 添加一些波动，使数据更真实
            let fluctuation = Double.random(in: -0.3...0.3)
            let weight = currentWeight + fluctuation
            
            // 随机添加体脂率
            let bodyFatPercentage = Bool.random() ? 18.0 + Double.random(in: 0...3) : 0
            
            // 随机添加围度数据（70%概率有值）
            let waistCircumference = Bool.random() ? 80.0 + Double.random(in: 0...5) : 0
            let hipCircumference = Bool.random() ? 90.0 + Double.random(in: 0...5) : 0
            let chestCircumference = Bool.random() ? 95.0 + Double.random(in: 0...5) : 0
            let thighCircumference = Bool.random() ? 55.0 + Double.random(in: 0...3) : 0
            
            // 随机选择测量时段
            let measurementTimePeriod = MeasurementTimePeriod.allCases.randomElement()?.rawValue ?? MeasurementTimePeriod.random.rawValue
            
            // 随机添加备注
            let note: String?
            if dayOffset % 7 == 0 {
                note = ["Good progress!", "Keep going!", "Great job!", "Steady decline!"].randomElement()
            } else {
                note = Bool.random() ? nil : ["Morning weigh-in", "After workout", "Before dinner"].randomElement()
            }
            
            let record = WeightRecord.create(in: context, weight: weight)
            record.date = date
            record.bodyFatPercentage = bodyFatPercentage
            record.waistCircumference = waistCircumference
            record.hipCircumference = hipCircumference
            record.chestCircumference = chestCircumference
            record.thighCircumference = thighCircumference
            record.note = note
            record.measurementTimePeriod = measurementTimePeriod
            record.createdAt = date
            record.updatedAt = date
            record.syncStatus = WeightRecord.SyncStatus.synced.rawValue
            
            // 每天减少一点体重
            currentWeight -= dailyDecrease
        }
    }
    
    func clearAllData(context: NSManagedObjectContext) {
        let recordFetch = WeightRecord.fetchRequest()
        if let records = try? context.fetch(recordFetch) {
            records.forEach { context.delete($0) }
        }
        
        let profileFetch = UserProfile.fetchRequest()
        if let profiles = try? context.fetch(profileFetch) {
            profiles.forEach { context.delete($0) }
        }
    }
}