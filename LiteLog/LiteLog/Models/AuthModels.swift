import Foundation

public struct UserInfo: Codable {
    public let userId: String
    public let nickname: String?
    public let avatarUrl: String?
    public let token: String
    public let tokenType: String?
    public let expiresIn: TimeInterval?
}

public struct AuthResponse: Codable {
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

public struct LogoutResponse: Codable {
    public let success: Bool
    public let message: String?
}

public struct UpdateProfileResponse: Codable {
    public let success: Bool
    public let message: String?
    public let nickname: String?
    public let avatarUrl: String?
}

public struct AvatarUploadResponse: Codable {
    public let success: Bool
    public let message: String?
    public let avatarUrl: String?
}

public struct FeedbackSubmitResponse: Codable {
    public let success: Bool
    public let code: Int
    public let message: String?
    public let feedbackId: Int?
}

public struct ResetPasswordResponse: Codable {
    public let success: Bool
    public let message: String?
}

public struct WeightRecordRequest: Codable {
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

public struct WeightRecordSyncRequest: Codable {
    public let records: [WeightRecordRequest]
}

public struct WeightRecordSyncResponse: Codable {
    public let success: Bool
    public let message: String?
    public let syncedCount: Int
    public let syncedRecordIds: [String]?
}
