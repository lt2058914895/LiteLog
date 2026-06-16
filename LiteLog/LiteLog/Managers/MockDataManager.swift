import Foundation
import SwiftData

class MockDataManager {
    static let shared = MockDataManager()
    
    private init() {}
    
    func populateMockData(modelContext: ModelContext) {
        let calendar = Calendar.current
        
        // 检查是否已有用户配置
        let profileFetch = FetchDescriptor<UserProfile>()
        if (try? modelContext.fetch(profileFetch))?.isEmpty ?? true {
            createMockProfile(modelContext: modelContext)
        }
        
        // 检查是否已有体重记录
        let recordFetch = FetchDescriptor<WeightRecord>()
        if (try? modelContext.fetch(recordFetch))?.isEmpty ?? true {
            createMockRecords(modelContext: modelContext, calendar: calendar)
        }
    }
    
    private func createMockProfile(modelContext: ModelContext) {
        let profile = UserProfile(
            height: 175.0,
            gender: .male,
            age: 28,
            goalWeight: 70.0,
            goalBodyFat: 15.0,
            goalWaistCircumference: 78.0,
            goalHipCircumference: 92.0,
            goalChestCircumference: 98.0,
            goalThighCircumference: 54.0,
            weightUnit: WeightUnit.kg.rawValue,
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            updatedAt: Date(),
            syncStatus: UserProfileSyncStatus.synced
        )
        modelContext.insert(profile)
    }
    
    private func createMockRecords(modelContext: ModelContext, calendar: Calendar) {
        var records: [WeightRecord] = []
        
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
            let bodyFatPercentage = Bool.random() ? 18.0 + Double.random(in: 0...3) : nil
            
            // 随机添加围度数据（70%概率有值）
            let waistCircumference = Bool.random() ? 80.0 + Double.random(in: 0...5) : nil
            let hipCircumference = Bool.random() ? 90.0 + Double.random(in: 0...5) : nil
            let chestCircumference = Bool.random() ? 95.0 + Double.random(in: 0...5) : nil
            let thighCircumference = Bool.random() ? 55.0 + Double.random(in: 0...3) : nil
            
            // 随机选择测量时段
            let measurementTimePeriod = MeasurementTimePeriod.allCases.randomElement()?.rawValue ?? MeasurementTimePeriod.random.rawValue
            
            // 随机添加备注
            let note: String?
            if dayOffset % 7 == 0 {
                note = ["Good progress!", "Keep going!", "Great job!", "Steady decline!"].randomElement()
            } else {
                note = Bool.random() ? nil : ["Morning weigh-in", "After workout", "Before dinner"].randomElement()
            }
            
            let record = WeightRecord(
                date: date,
                weight: weight,
                bodyFatPercentage: bodyFatPercentage,
                waistCircumference: waistCircumference,
                hipCircumference: hipCircumference,
                chestCircumference: chestCircumference,
                thighCircumference: thighCircumference,
                note: note,
                measurementTimePeriod: measurementTimePeriod,
                createdAt: date,
                updatedAt: date,
                syncStatus: WeightRecordSyncStatus.synced
            )
            
            records.append(record)
            
            // 每天减少一点体重
            currentWeight -= dailyDecrease
        }
        
        records.forEach { modelContext.insert($0) }
    }
    
    func clearAllData(modelContext: ModelContext) {
        let recordFetch = FetchDescriptor<WeightRecord>()
        if let records = try? modelContext.fetch(recordFetch) {
            records.forEach { modelContext.delete($0) }
        }
        
        let profileFetch = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(profileFetch) {
            profiles.forEach { modelContext.delete($0) }
        }
    }
}