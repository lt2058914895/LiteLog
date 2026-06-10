import Foundation

@frozen
public struct UserInfo: Codable, Sendable {
    public let userId: String
    public let nickname: String?
    public let avatarUrl: String?
    public let token: String
    public let tokenType: String?
    public let expiresIn: TimeInterval?
}

@frozen
public struct AuthResponse: Codable, Sendable {
    public let success: Bool
    public let userId: String?
    public let nickname: String?
    public let avatarUrl: String?
    public let token: String?
    public let tokenType: String?
    public let expiresIn: TimeInterval?
    public let message: String?
    
    public var userInfo: UserInfo? {
        guard let userId = userId, let token = token else { return nil }
        return UserInfo(
            userId: userId,
            nickname: nickname,
            avatarUrl: avatarUrl,
            token: token,
            tokenType: tokenType,
            expiresIn: expiresIn
        )
    }
}

@frozen
public struct LogoutResponse: Codable, Sendable {
    public let success: Bool
    public let message: String?
}

@frozen
public struct UpdateProfileResponse: Codable, Sendable {
    public let success: Bool
    public let message: String?
    public let nickname: String?
    public let avatarUrl: String?
}

@frozen
public struct AvatarUploadResponse: Codable, Sendable {
    public let success: Bool
    public let message: String?
    public let avatarUrl: String?
}

@frozen
public struct FeedbackSubmitResponse: Codable, Sendable {
    public let success: Bool
    public let code: Int
    public let message: String?
    public let feedbackId: Int?
}

@frozen
public struct ResetPasswordResponse: Codable, Sendable {
    public let success: Bool
    public let message: String?
}

@frozen
public struct WeightRecordRequest: Codable, Sendable {
    public let recordId: String
    public let weight: Double
    public let bodyFatPercentage: Double?
    public let waistCircumference: Double?
    public let hipCircumference: Double?
    public let thighCircumference: Double?
    public let note: String?
    public let date: TimeInterval
    public let createdAt: TimeInterval
    public let updatedAt: TimeInterval
    public let deleted: Bool?
    public let imageUrl: String?
    public let imageFileName: String?
    public let measurementTimePeriod: String?
}

@frozen
public struct WeightRecordSyncRequest: Codable, Sendable {
    public let records: [WeightRecordRequest]
}

@frozen
public struct WeightRecordSyncResponse: Codable, Sendable {
    public let success: Bool
    public let message: String?
    public let syncedCount: Int
    public let syncedRecordIds: [String]?
}
