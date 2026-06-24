import Foundation

// Mark response models as nonisolated for Swift 6 compatibility
public struct UpdateProfileResponse: Sendable {
    public let success: Bool
    public let message: String?
    public let nickname: String?
    public let avatarUrl: String?
    
    public init(success: Bool, message: String?, nickname: String?, avatarUrl: String?) {
        self.success = success
        self.message = message
        self.nickname = nickname
        self.avatarUrl = avatarUrl
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message, nickname, avatarUrl
    }
}

extension UpdateProfileResponse: Decodable {
    nonisolated
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }
}

extension UpdateProfileResponse: Encodable {
    nonisolated
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
    }
}

public struct AvatarUploadResponse: Sendable {
    public let success: Bool
    public let message: String?
    public let avatarUrl: String?
    
    public init(success: Bool, message: String?, avatarUrl: String?) {
        self.success = success
        self.message = message
        self.avatarUrl = avatarUrl
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message, avatarUrl
    }
}

extension AvatarUploadResponse: Decodable {
    nonisolated
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }
}

extension AvatarUploadResponse: Encodable {
    nonisolated
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
    }
}

public struct FeedbackSubmitResponse: Sendable {
    public let success: Bool
    public let code: Int
    public let message: String?
    public let feedbackId: Int?
    
    public init(success: Bool, code: Int, message: String?, feedbackId: Int?) {
        self.success = success
        self.code = code
        self.message = message
        self.feedbackId = feedbackId
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, code, message, feedbackId
    }
}

extension FeedbackSubmitResponse: Decodable {
    nonisolated
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        code = try container.decode(Int.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        feedbackId = try container.decodeIfPresent(Int.self, forKey: .feedbackId)
    }
}

extension FeedbackSubmitResponse: Encodable {
    nonisolated
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(code, forKey: .code)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(feedbackId, forKey: .feedbackId)
    }
}

public struct WeightRecordRequest: Sendable {
    public let recordId: String
    public let weight: Double
    public let bodyFatPercentage: Double?
    public let waistCircumference: Double?
    public let hipCircumference: Double?
    public let chestCircumference: Double?
    public let thighCircumference: Double?
    public let note: String?
    public let date: TimeInterval
    public let createdAt: TimeInterval
    public let updatedAt: TimeInterval
    public let deleted: Bool?
    public let imageUrl: String?
    public let imageFileName: String?
    public let measurementTimePeriod: String?
    
    public init(recordId: String, weight: Double, bodyFatPercentage: Double?, waistCircumference: Double?, hipCircumference: Double?, chestCircumference: Double?, thighCircumference: Double?, note: String?, date: TimeInterval, createdAt: TimeInterval, updatedAt: TimeInterval, deleted: Bool?, imageUrl: String?, imageFileName: String?, measurementTimePeriod: String?) {
        self.recordId = recordId
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.waistCircumference = waistCircumference
        self.hipCircumference = hipCircumference
        self.chestCircumference = chestCircumference
        self.thighCircumference = thighCircumference
        self.note = note
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deleted = deleted
        self.imageUrl = imageUrl
        self.imageFileName = imageFileName
        self.measurementTimePeriod = measurementTimePeriod
    }
    
    private enum CodingKeys: String, CodingKey {
        case recordId, weight, bodyFatPercentage, waistCircumference, hipCircumference, chestCircumference, thighCircumference, note, date, createdAt, updatedAt, deleted, imageUrl, imageFileName, measurementTimePeriod
    }
}

extension WeightRecordRequest: Decodable {
    nonisolated
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordId = try container.decode(String.self, forKey: .recordId)
        weight = try container.decode(Double.self, forKey: .weight)
        bodyFatPercentage = try container.decodeIfPresent(Double.self, forKey: .bodyFatPercentage)
        waistCircumference = try container.decodeIfPresent(Double.self, forKey: .waistCircumference)
        hipCircumference = try container.decodeIfPresent(Double.self, forKey: .hipCircumference)
        chestCircumference = try container.decodeIfPresent(Double.self, forKey: .chestCircumference)
        thighCircumference = try container.decodeIfPresent(Double.self, forKey: .thighCircumference)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        date = try container.decode(TimeInterval.self, forKey: .date)
        createdAt = try container.decode(TimeInterval.self, forKey: .createdAt)
        updatedAt = try container.decode(TimeInterval.self, forKey: .updatedAt)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        measurementTimePeriod = try container.decodeIfPresent(String.self, forKey: .measurementTimePeriod)
    }
}

extension WeightRecordRequest: Encodable {
    nonisolated
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordId, forKey: .recordId)
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(bodyFatPercentage, forKey: .bodyFatPercentage)
        try container.encodeIfPresent(waistCircumference, forKey: .waistCircumference)
        try container.encodeIfPresent(hipCircumference, forKey: .hipCircumference)
        try container.encodeIfPresent(chestCircumference, forKey: .chestCircumference)
        try container.encodeIfPresent(thighCircumference, forKey: .thighCircumference)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(date, forKey: .date)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deleted, forKey: .deleted)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(measurementTimePeriod, forKey: .measurementTimePeriod)
    }
}

public struct WeightRecordSyncRequest: Sendable {
    public let records: [WeightRecordRequest]
    
    public init(records: [WeightRecordRequest]) {
        self.records = records
    }
    
    private enum CodingKeys: String, CodingKey {
        case records
    }
}

extension WeightRecordSyncRequest: Decodable {
    nonisolated
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        records = try container.decode([WeightRecordRequest].self, forKey: .records)
    }
}

extension WeightRecordSyncRequest: Encodable {
    nonisolated
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(records, forKey: .records)
    }
}

public struct WeightRecordSyncResponse: Sendable {
    public let success: Bool
    public let message: String?
    public let syncedCount: Int
    public let syncedRecordIds: [String]?
    
    public init(success: Bool, message: String?, syncedCount: Int, syncedRecordIds: [String]?) {
        self.success = success
        self.message = message
        self.syncedCount = syncedCount
        self.syncedRecordIds = syncedRecordIds
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message, syncedCount, syncedRecordIds
    }
}

extension WeightRecordSyncResponse: Decodable {
    nonisolated
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        syncedCount = try container.decode(Int.self, forKey: .syncedCount)
        syncedRecordIds = try container.decodeIfPresent([String].self, forKey: .syncedRecordIds)
    }
}

extension WeightRecordSyncResponse: Encodable {
    nonisolated
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encode(syncedCount, forKey: .syncedCount)
        try container.encodeIfPresent(syncedRecordIds, forKey: .syncedRecordIds)
    }
}
