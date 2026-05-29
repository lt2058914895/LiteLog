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
