import Foundation
import UIKit
import CoreData

final class DataSyncManager {
    static let shared = DataSyncManager()
    
    private init() {}
    
    @MainActor
    func syncLocalDataToCloud(context: NSManagedObjectContext) async {
        do {
            try await syncUserProfile(context: context)
            try await syncWeightRecords(context: context)
            
        } catch {
            print("数据同步失败: \(error)")
        }
    }
    
    @MainActor
    func syncFromCloud(context: NSManagedObjectContext) async -> Bool {
        do {
            let response = try await APIService.shared.fetchAllData()
            
            if response.success, let profile = response.profile, let records = response.records {
                try await mergeProfileFromCloud(profile, context: context)
                try await mergeRecordsFromCloud(records, context: context)
                print("从云端同步数据成功")
                return true
            } else {
                print("从云端同步数据失败: \(response.message ?? "未知错误")")
                return false
            }
        } catch {
            print("从云端同步数据失败: \(error)")
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
            userProfile.goalWeight = goalWeight
        }
        if let goalBodyFat = profile.goalBodyFat {
            userProfile.goalBodyFat = goalBodyFat
        }
        if let goalWaistCircumference = profile.goalWaistCircumference {
            userProfile.goalWaistCircumference = goalWaistCircumference
        }
        if let goalHipCircumference = profile.goalHipCircumference {
            userProfile.goalHipCircumference = goalHipCircumference
        }
        if let goalChestCircumference = profile.goalChestCircumference {
            userProfile.goalChestCircumference = goalChestCircumference
        }
        if let goalThighCircumference = profile.goalThighCircumference {
            userProfile.goalThighCircumference = goalThighCircumference
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
        print("个人资料从云端合并成功")
    }
    
    @MainActor
    func mergeRecordsFromCloud(_ records: [WeightRecordRequest], context: NSManagedObjectContext) async throws {
        let request = WeightRecord.fetchRequest()
        let existingRecords = try context.fetch(request)
        let existingRecordIds = Set(existingRecords.map { $0.id.uuidString })
        
        for recordRequest in records {
            if existingRecordIds.contains(recordRequest.recordId) {
                try updateRecordFromCloud(recordRequest, context: context)
            } else {
                try createRecordFromCloud(recordRequest, context: context)
            }
        }
        
        try context.save()
        print("体重记录从云端合并成功，共 \(records.count) 条")
    }
    
    private func createRecordFromCloud(_ request: WeightRecordRequest, context: NSManagedObjectContext) throws {
        let record = WeightRecord(context: context)
        record.id = UUID(uuidString: request.recordId) ?? UUID()
        record.date = Date(timeIntervalSince1970: request.date)
        record.weight = request.weight
        record.bodyFatPercentage = request.bodyFatPercentage ?? 0
        record.waistCircumference = request.waistCircumference ?? 0
        record.hipCircumference = request.hipCircumference ?? 0
        record.chestCircumference = request.chestCircumference ?? 0
        record.thighCircumference = request.thighCircumference ?? 0
        record.note = request.note
        record.imageUrl = request.imageUrl
        record.measurementTimePeriod = request.measurementTimePeriod
        record.createdAt = Date(timeIntervalSince1970: request.createdAt)
        record.updatedAt = Date(timeIntervalSince1970: request.updatedAt)
        record.syncStatus = WeightRecord.SyncStatus.synced.rawValue
    }
    
    private func updateRecordFromCloud(_ request: WeightRecordRequest, context: NSManagedObjectContext) throws {
        let fetchRequest = WeightRecord.fetchRequest()
        let uuid = UUID(uuidString: request.recordId) ?? UUID()
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        if let existingRecord = try context.fetch(fetchRequest).first {
            let localUpdatedAt = existingRecord.updatedAt.timeIntervalSince1970
            let cloudUpdatedAt = request.updatedAt
            
            if cloudUpdatedAt > localUpdatedAt {
                existingRecord.date = Date(timeIntervalSince1970: request.date)
                existingRecord.weight = request.weight
                existingRecord.bodyFatPercentage = request.bodyFatPercentage ?? 0
                existingRecord.waistCircumference = request.waistCircumference ?? 0
                existingRecord.hipCircumference = request.hipCircumference ?? 0
                existingRecord.chestCircumference = request.chestCircumference ?? 0
                existingRecord.thighCircumference = request.thighCircumference ?? 0
                existingRecord.note = request.note
                existingRecord.imageUrl = request.imageUrl
                existingRecord.measurementTimePeriod = request.measurementTimePeriod
                existingRecord.updatedAt = Date(timeIntervalSince1970: request.updatedAt)
                existingRecord.syncStatus = WeightRecord.SyncStatus.synced.rawValue
            }
        }
    }
    
    @MainActor
    private func syncUserProfile(context: NSManagedObjectContext) async throws {
        let request = UserProfile.fetchRequest()
        let allProfiles = try context.fetch(request)
        let pendingProfiles = allProfiles.filter { $0.syncStatus == UserProfile.SyncStatus.pending.rawValue }
        
        if let profile = pendingProfiles.first {
            do {
                let unit = WeightUnit(rawValue: profile.weightUnit) ?? .kg
                let goalWeightInCurrentUnit = unit.convertFromKg(profile.goalWeight)
                
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
                    print("个人资料（身高、性别、年龄、目标体重）同步成功")
                }
            } catch {
                print("个人资料同步失败: \(error)")
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
                print("删除记录同步成功，删除了 \(response.syncedCount) 条")
            }
        } catch {
            print("删除记录同步失败: \(error)")
        }
    }
    
    @MainActor
    private func syncWeightRecords(context: NSManagedObjectContext) async throws {
        let request = WeightRecord.fetchRequest()
        let allRecords = try context.fetch(request)
        let pendingRecords = allRecords.filter { $0.syncStatus == WeightRecord.SyncStatus.pending.rawValue }
        
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
        
        if !recordsWithoutImages.isEmpty {
            let requests = recordsWithoutImages.map { record in
                WeightRecordRequest(
                    recordId: record.id.uuidString,
                    weight: record.weight,
                    bodyFatPercentage: record.bodyFatPercentage == 0 ? nil : record.bodyFatPercentage,
                    waistCircumference: record.waistCircumference == 0 ? nil : record.waistCircumference,
                    hipCircumference: record.hipCircumference == 0 ? nil : record.hipCircumference,
                    chestCircumference: record.chestCircumference == 0 ? nil : record.chestCircumference,
                    thighCircumference: record.thighCircumference == 0 ? nil : record.thighCircumference,
                    note: record.note,
                    date: record.date.timeIntervalSince1970,
                    createdAt: record.createdAt.timeIntervalSince1970,
                    updatedAt: record.updatedAt.timeIntervalSince1970,
                    deleted: false,
                    imageUrl: record.imageUrl,
                    imageFileName: nil,
                    measurementTimePeriod: record.measurementTimePeriod,
                    deleteImage: record.deleteImage
                )
            }
            
            do {
                let response = try await APIService.shared.syncWeightRecords(records: requests)
                
                if response.success {
                    if let syncedIds = response.syncedRecordIds {
                        for record in recordsWithoutImages where syncedIds.contains(record.id.uuidString) {
                            record.syncStatus = WeightRecord.SyncStatus.synced.rawValue
                            record.deleteImage = false
                        }
                    }
                    try context.save()
                    print("体重记录同步成功，同步了 \(response.syncedCount) 条")
                }
            } catch {
                print("体重记录同步失败: \(error)")
            }
        }
        
        if !recordsWithLocalImages.isEmpty {
            let requests = recordsWithLocalImages.map { record in
                WeightRecordRequest(
                    recordId: record.id.uuidString,
                    weight: record.weight,
                    bodyFatPercentage: record.bodyFatPercentage == 0 ? nil : record.bodyFatPercentage,
                    waistCircumference: record.waistCircumference == 0 ? nil : record.waistCircumference,
                    hipCircumference: record.hipCircumference == 0 ? nil : record.hipCircumference,
                    chestCircumference: record.chestCircumference == 0 ? nil : record.chestCircumference,
                    thighCircumference: record.thighCircumference == 0 ? nil : record.thighCircumference,
                    note: record.note,
                    date: record.date.timeIntervalSince1970,
                    createdAt: record.createdAt.timeIntervalSince1970,
                    updatedAt: record.updatedAt.timeIntervalSince1970,
                    deleted: false,
                    imageUrl: nil,
                    imageFileName: "\(record.id.uuidString)_image.jpg",
                    measurementTimePeriod: record.measurementTimePeriod
                )
            }
            
            let images = recordsWithLocalImages.compactMap { record -> (recordId: String, image: UIImage)? in
                guard let imageUrl = record.imageUrl, ImageStorageManager.shared.isLocalImageUrl(imageUrl),
                      let image = ImageStorageManager.shared.loadImage(from: imageUrl) else { 
                    return nil 
                }
                return (record.id.uuidString, image)
            }
            
            do {
                let response = try await APIService.shared.syncWeightRecordsWithImages(records: requests, images: images)
                
                if response.success {
                    if let syncedIds = response.syncedRecordIds {
                        for record in recordsWithLocalImages where syncedIds.contains(record.id.uuidString) {
                            record.syncStatus = WeightRecord.SyncStatus.synced.rawValue
                        }
                    }
                    
                    if let syncedRecords = response.syncedRecords {
                        for syncedRecord in syncedRecords {
                            if let record = recordsWithLocalImages.first(where: { $0.id.uuidString == syncedRecord.recordId }),
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
                    print("带图片的体重记录同步成功，同步了 \(response.syncedCount) 条")
                }
            } catch {
                print("带图片的体重记录同步失败: \(error)")
            }
        }
    }
}