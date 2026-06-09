import Foundation
import UIKit
import SwiftData

final class DataSyncManager {
    static let shared = DataSyncManager()
    
    private init() {}
    
    @MainActor
    func syncLocalDataToCloud(modelContext: ModelContext) async {
        guard SettingsManager.shared.isLoggedIn else {
            return
        }
        
        do {
            // 同步个人资料
            try await syncUserProfile(modelContext: modelContext)
            
            // 同步体重记录
            try await syncWeightRecords(modelContext: modelContext)
            
        } catch {
            print("数据同步失败: \(error)")
        }
    }
    
    @MainActor
    private func syncUserProfile(modelContext: ModelContext) async throws {
        let allProfiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        let pendingProfiles = allProfiles.filter { $0.syncStatus == .pending }
        
        if let profile = pendingProfiles.first {
            do {
                // 将目标体重转换为当前单位后再同步到云数据库
                // 例如：70kg 在 kg 单位下发送 70，在 lb 单位下发送 154.32
                let unit = WeightUnit(rawValue: profile.weightUnit) ?? .kg
                let goalWeightInCurrentUnit = unit.convertFromKg(profile.goalWeight)
                
                let response = try await APIService.shared.updateUserProfile(
                    height: profile.height,
                    gender: profile.gender.rawValue,
                    age: profile.age,
                    goalWeight: goalWeightInCurrentUnit,
                    weightUnit: profile.weightUnit
                )
                
                if response.success {
                    profile.syncStatus = .synced
                    try modelContext.save()
                    print("个人资料（身高、性别、年龄、目标体重）同步成功")
                }
            } catch {
                print("个人资料同步失败: \(error)")
                // 保持 pending 状态，下次冷启动会重试
            }
        }
    }
    
    @MainActor
    func triggerProfileSync(modelContext: ModelContext) {
        // 将个人资料标记为待同步
        let profiles = try? modelContext.fetch(FetchDescriptor<UserProfile>())
        if let profile = profiles?.first {
            profile.syncStatus = .pending
            try? modelContext.save()
            
            // 异步触发同步
            Task {
                await syncLocalDataToCloud(modelContext: modelContext)
            }
        }
    }
    
    @MainActor
    func triggerWeightRecordSync(modelContext: ModelContext) {
        // 异步触发同步（记录已经标记为 pending）
        Task {
            await syncLocalDataToCloud(modelContext: modelContext)
        }
    }
    
    @MainActor
    func syncDeletedRecords(recordIds: [String]) async {
        guard SettingsManager.shared.isLoggedIn else {
            return
        }
        
        do {
            let response = try await APIService.shared.deleteWeightRecords(recordIds: recordIds)
            if response.success {
                print("删除记录同步成功，删除了 \(response.syncedCount) 条")
            }
        } catch {
            print("删除记录同步失败: \(error)")
        }
    }
    
    @MainActor
    private func syncWeightRecords(modelContext: ModelContext) async throws {
        let allRecords = try modelContext.fetch(FetchDescriptor<WeightRecord>())
        let pendingRecords = allRecords.filter { $0.syncStatus == .pending }
        
        if pendingRecords.isEmpty {
            return
        }
        
        // 分离有图片和无图片的记录
        let recordsWithImages = pendingRecords.filter { $0.selectedImage != nil }
        let recordsWithoutImages = pendingRecords.filter { $0.selectedImage == nil }
        
        // 先同步无图片的记录
        if !recordsWithoutImages.isEmpty {
            let requests = recordsWithoutImages.map { record in
                WeightRecordRequest(
                    recordId: record.id.uuidString,
                    weight: record.weight,
                    bodyFatPercentage: record.bodyFatPercentage,
                    waistCircumference: record.waistCircumference,
                    note: record.note,
                    date: record.date.timeIntervalSince1970,
                    createdAt: record.createdAt.timeIntervalSince1970,
                    updatedAt: record.updatedAt.timeIntervalSince1970,
                    deleted: false,
                    imageUrl: record.imageUrl,
                    imageFileName: nil
                )
            }
            
            do {
                let response = try await APIService.shared.syncWeightRecords(records: requests)
                
                if response.success {
                    if let syncedIds = response.syncedRecordIds {
                        for record in recordsWithoutImages where syncedIds.contains(record.id.uuidString) {
                            record.syncStatus = .synced
                        }
                    }
                    try modelContext.save()
                    print("体重记录同步成功，同步了 \(response.syncedCount) 条")
                }
            } catch {
                print("体重记录同步失败: \(error)")
            }
        }
        
        // 同步有图片的记录
        if !recordsWithImages.isEmpty {
            let requests = recordsWithImages.map { record in
                WeightRecordRequest(
                    recordId: record.id.uuidString,
                    weight: record.weight,
                    bodyFatPercentage: record.bodyFatPercentage,
                    waistCircumference: record.waistCircumference,
                    note: record.note,
                    date: record.date.timeIntervalSince1970,
                    createdAt: record.createdAt.timeIntervalSince1970,
                    updatedAt: record.updatedAt.timeIntervalSince1970,
                    deleted: false,
                    imageUrl: nil,
                    imageFileName: "\(record.id.uuidString)_image.jpg"
                )
            }
            
            let images = recordsWithImages.compactMap { record -> (recordId: String, image: UIImage)? in
                guard let image = record.selectedImage else { return nil }
                return (record.id.uuidString, image)
            }
            
            do {
                let response = try await APIService.shared.syncWeightRecordsWithImages(records: requests, images: images)
                
                if response.success {
                    if let syncedIds = response.syncedRecordIds {
                        for record in recordsWithImages where syncedIds.contains(record.id.uuidString) {
                            record.syncStatus = .synced
                            record.selectedImage = nil  // 清除临时图片
                        }
                    }
                    try modelContext.save()
                    print("带图片的体重记录同步成功，同步了 \(response.syncedCount) 条")
                }
            } catch {
                print("带图片的体重记录同步失败: \(error)")
            }
        }
    }
}
