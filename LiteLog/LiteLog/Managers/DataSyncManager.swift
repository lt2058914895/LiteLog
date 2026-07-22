import Foundation
import UIKit
import CoreData
import os

final class DataSyncManager {
    static let shared = DataSyncManager()
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "DataSyncManager")
    
    private init() {}
    
    @MainActor
    func syncLocalDataToCloud(context: NSManagedObjectContext) async {
        do {
            try await syncUserProfile(context: context)
            try await syncWeightRecords(context: context)
            
        } catch {
            Self.logger.error("数据同步失败: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func syncFromCloud(context: NSManagedObjectContext) async -> Bool {
        do {
            let response = try await APIService.shared.fetchAllData()
            
            if response.success, let profile = response.profile, let records = response.records {
                try await mergeProfileFromCloud(profile, context: context)
                try await mergeRecordsFromCloud(records, context: context)
                Self.logger.info("从云端同步数据成功")
                return true
            } else {
                Self.logger.error("从云端同步数据失败: \(response.message ?? "未知错误")")
                return false
            }
        } catch {
            Self.logger.error("从云端同步数据失败: \(error.localizedDescription)")
            return false
        }
    }
    
    @MainActor
    func mergeProfileFromCloud(_ profile: UpdateProfileResponse, context: NSManagedObjectContext) async throws {
        let request = UserProfile.fetchRequest()
        let profiles = try context.fetch(request)
        
        let userProfile: UserProfile
        if let existingProfile = profiles.first {
            userProfile = existingProfile
        } else {
            userProfile = UserProfile.create(in: context)
        }
        
        if let nickname = profile.nickname {
            SettingsManager.shared.nickname = nickname
        }
        if let avatarUrl = profile.avatarUrl {
            SettingsManager.shared.avatarUrl = avatarUrl
        }
        
        if let height = profile.height {
            userProfile.height = height
        }
        if let gender = profile.gender {
            userProfile.gender = Int16(gender)
        }
        if let age = profile.age {
            userProfile.age = Int16(age)
        }
        if let goalWeight = profile.goalWeight {
            userProfile.goalWeightValue = goalWeight
        }
        if let goalBodyFat = profile.goalBodyFat {
            userProfile.goalBodyFatPercentage = goalBodyFat
        }
        if let goalWaistCircumference = profile.goalWaistCircumference {
            userProfile.goalWaistCircumferenceValue = goalWaistCircumference
        }
        if let goalHipCircumference = profile.goalHipCircumference {
            userProfile.goalHipCircumferenceValue = goalHipCircumference
        }
        if let goalChestCircumference = profile.goalChestCircumference {
            userProfile.goalChestCircumferenceValue = goalChestCircumference
        }
        if let goalThighCircumference = profile.goalThighCircumference {
            userProfile.goalThighCircumferenceValue = goalThighCircumference
        }
        if let weightUnit = profile.weightUnit {
            userProfile.weightUnit = weightUnit
            if let unit = WeightUnit(rawValue: weightUnit) {
                SettingsManager.shared.weightUnit = unit
            }
        }
        
        userProfile.updatedAt = Date()
        userProfile.syncStatus = UserProfile.SyncStatus.synced.rawValue
        
        try context.save()
        Self.logger.info("个人资料从云端合并成功")
    }
    
    @MainActor
    func mergeRecordsFromCloud(_ records: [WeightRecordRequest], context: NSManagedObjectContext) async throws {
        // 批量查询：一次获取所有本地记录，构建字典用于O(1)查找，避免N+1查询
        let request = WeightRecord.fetchRequest()
        request.fetchBatchSize = 50
        request.returnsObjectsAsFaults = false
        let existingRecords = try context.fetch(request)
        var existingRecordMap: [String: WeightRecord] = [:]
        for record in existingRecords {
            existingRecordMap[record.id.uuidString] = record
        }
        
        for recordRequest in records {
            if let existingRecord = existingRecordMap[recordRequest.recordId] {
                // 云端更新时间更晚才更新本地记录
                let localUpdatedAt = existingRecord.updatedAt.timeIntervalSince1970
                let cloudUpdatedAt = recordRequest.updatedAt
                
                if cloudUpdatedAt > localUpdatedAt {
                    existingRecord.date = Date(timeIntervalSince1970: recordRequest.date)
                    existingRecord.weight = recordRequest.weight
                    existingRecord.bodyFatPercentageValue = recordRequest.bodyFatPercentage
                    existingRecord.waistCircumferenceValue = recordRequest.waistCircumference
                    existingRecord.hipCircumferenceValue = recordRequest.hipCircumference
                    existingRecord.chestCircumferenceValue = recordRequest.chestCircumference
                    existingRecord.thighCircumferenceValue = recordRequest.thighCircumference
                    existingRecord.note = recordRequest.note
                    existingRecord.imageUrl = recordRequest.imageUrl
                    existingRecord.measurementTimePeriod = recordRequest.measurementTimePeriod
                    existingRecord.updatedAt = Date(timeIntervalSince1970: recordRequest.updatedAt)
                    existingRecord.syncStatus = WeightRecord.SyncStatus.synced.rawValue
                }
            } else {
                try createRecordFromCloud(recordRequest, context: context)
            }
        }
        
        try context.save()
        Self.logger.info("体重记录从云端合并成功，共 \(records.count) 条")
    }
    
    private func createRecordFromCloud(_ request: WeightRecordRequest, context: NSManagedObjectContext) throws {
        let record = WeightRecord(context: context)
        record.id = UUID(uuidString: request.recordId) ?? UUID()
        record.date = Date(timeIntervalSince1970: request.date)
        record.weight = request.weight
        record.bodyFatPercentageValue = request.bodyFatPercentage
        record.waistCircumferenceValue = request.waistCircumference
        record.hipCircumferenceValue = request.hipCircumference
        record.chestCircumferenceValue = request.chestCircumference
        record.thighCircumferenceValue = request.thighCircumference
        record.note = request.note
        record.imageUrl = request.imageUrl
        record.measurementTimePeriod = request.measurementTimePeriod
        record.createdAt = Date(timeIntervalSince1970: request.createdAt)
        record.updatedAt = Date(timeIntervalSince1970: request.updatedAt)
        record.syncStatus = WeightRecord.SyncStatus.synced.rawValue
    }
    
    @MainActor
    private func syncUserProfile(context: NSManagedObjectContext) async throws {
        let request = UserProfile.fetchRequest()
        let allProfiles = try context.fetch(request)
        let pendingProfiles = allProfiles.filter { $0.syncStatus == UserProfile.SyncStatus.pending.rawValue }
        
        if let profile = pendingProfiles.first {
            do {
                let unit = WeightUnit(rawValue: profile.weightUnit) ?? .kg
                let goalWeightInCurrentUnit = profile.goalWeightValue.map { unit.convertFromKg($0) } ?? 0
                
                let response = try await APIService.shared.updateUserProfile(
                    height: profile.height,
                    gender: Int(profile.gender),
                    age: Int(profile.age),
                    goalWeight: goalWeightInCurrentUnit,
                    weightUnit: profile.weightUnit
                )
                
                if response.success {
                    profile.syncStatus = UserProfile.SyncStatus.synced.rawValue
                    try context.save()
                    Self.logger.info("个人资料同步成功")
                }
            } catch {
                Self.logger.error("个人资料同步失败: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    func triggerProfileSync(context: NSManagedObjectContext) {
        let request = UserProfile.fetchRequest()
        let profiles = try? context.fetch(request)
        if let profile = profiles?.first {
            profile.syncStatus = UserProfile.SyncStatus.pending.rawValue
            try? context.save()
            
            Task {
                await syncLocalDataToCloud(context: context)
            }
        }
    }
    
    @MainActor
    func triggerWeightRecordSync(context: NSManagedObjectContext) {
        Task {
            await syncLocalDataToCloud(context: context)
        }
    }
    
    @MainActor
    func syncDeletedRecords(recordIds: [String]) async {
        do {
            let response = try await APIService.shared.deleteWeightRecords(recordIds: recordIds)
            if response.success {
                Self.logger.info("删除记录同步成功，删除了 \(response.syncedCount) 条")
            }
        } catch {
            Self.logger.error("删除记录同步失败: \(error.localizedDescription)")
        }
    }
    
    /// 同步批量大小限制
    private static let syncBatchSize = 50
    
    /// 最大重试次数
    private static let maxRetryCount = 3
    
    /// 重试基础延迟（秒），指数退避：1s, 2s, 4s
    private static let retryBaseDelay: UInt64 = 1_000_000_000
    
    @MainActor
    private func syncWeightRecords(context: NSManagedObjectContext) async throws {
        let request = WeightRecord.fetchRequest()
        let allRecords = try context.fetch(request)
        // 包含 failed 状态的记录以便重试
        let pendingRecords = allRecords.filter { 
            $0.syncStatus == WeightRecord.SyncStatus.pending.rawValue 
            || $0.syncStatus == WeightRecord.SyncStatus.failed.rawValue 
        }
        
        if pendingRecords.isEmpty {
            return
        }
        
        let recordsWithLocalImages = pendingRecords.filter { 
            guard let url = $0.imageUrl else { return false }
            return ImageStorageManager.shared.isLocalImageUrl(url)
        }
        let recordsWithoutImages = pendingRecords.filter { 
            $0.imageUrl == nil || !ImageStorageManager.shared.isLocalImageUrl($0.imageUrl!)
        }
        
        // 分批同步无图片记录
        if !recordsWithoutImages.isEmpty {
            let batches = recordsWithoutImages.chunked(into: Self.syncBatchSize)
            for batch in batches {
                let requests = batch.map { record in
                    record.toRequest(imageUrl: record.imageUrl, deleteImage: record.deleteImage)
                }
                
                do {
                    let response = try await syncWithRetry {
                        try await APIService.shared.syncWeightRecords(records: requests)
                    }
                    
                    if response.success {
                        if let syncedIds = response.syncedRecordIds {
                            for record in batch where syncedIds.contains(record.id.uuidString) {
                                record.syncStatus = WeightRecord.SyncStatus.synced.rawValue
                                record.deleteImage = false
                            }
                        }
                        try context.save()
                        Self.logger.info("体重记录同步成功，本批 \(batch.count) 条")
                    }
                } catch {
                    // 标记本批记录为失败状态，下次同步时会重试
                    for record in batch {
                        record.syncStatus = WeightRecord.SyncStatus.failed.rawValue
                    }
                    try? context.save()
                    Self.logger.error("体重记录同步失败（已标记为failed等待重试）: \(error.localizedDescription)")
                }
            }
        }
        
        // 分批同步带图片记录（每批更小，避免内存溢出）
        if !recordsWithLocalImages.isEmpty {
            let imageBatchSize = 10 // 图片记录每批更小
            let batches = recordsWithLocalImages.chunked(into: imageBatchSize)
            for batch in batches {
                let requests = batch.map { record in
                    record.toRequest(imageFileName: "\(record.id.uuidString)_image.jpg")
                }
                
                let images = batch.compactMap { record -> (recordId: String, image: UIImage)? in
                    guard let imageUrl = record.imageUrl, ImageStorageManager.shared.isLocalImageUrl(imageUrl),
                          let image = ImageStorageManager.shared.loadImage(from: imageUrl) else { 
                        return nil 
                    }
                    return (record.id.uuidString, image)
                }
                
                do {
                    let response = try await syncWithRetry {
                        try await APIService.shared.syncWeightRecordsWithImages(records: requests, images: images)
                    }
                    
                    if response.success {
                        if let syncedIds = response.syncedRecordIds {
                            for record in batch where syncedIds.contains(record.id.uuidString) {
                                record.syncStatus = WeightRecord.SyncStatus.synced.rawValue
                            }
                        }
                        
                        if let syncedRecords = response.syncedRecords {
                            for syncedRecord in syncedRecords {
                                if let record = batch.first(where: { $0.id.uuidString == syncedRecord.recordId }),
                                   let imageUrl = syncedRecord.imageUrl {
                                    let oldLocalUrl = record.imageUrl
                                    record.imageUrl = imageUrl
                                    if let oldLocalUrl = oldLocalUrl, ImageStorageManager.shared.isLocalImageUrl(oldLocalUrl) {
                                        ImageStorageManager.shared.deleteImage(from: oldLocalUrl)
                                    }
                                }
                            }
                        }
                        
                        try context.save()
                        Self.logger.info("带图片的体重记录同步成功，本批 \(batch.count) 条")
                    }
                } catch {
                    // 标记本批记录为失败状态，下次同步时会重试
                    for record in batch {
                        record.syncStatus = WeightRecord.SyncStatus.failed.rawValue
                    }
                    try? context.save()
                    Self.logger.error("带图片的体重记录同步失败（已标记为failed等待重试）: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 带指数退避重试的同步方法
    private func syncWithRetry<T>(maxRetries: Int = maxRetryCount, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    // 指数退避：1s, 2s, 4s
                    let delay = Self.retryBaseDelay * UInt64(1 << attempt)
                    Self.logger.warning("同步失败，\(delay / 1_000_000_000)秒后重试（第\(attempt + 1)次）: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }
        
        throw lastError!
    }
}

// MARK: - Array 分批扩展
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}