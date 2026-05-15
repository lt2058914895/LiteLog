import Foundation

struct UserFeedback: Codable {
    let id: UUID
    let type: String
    let message: String
    let email: String?
    let createdAt: Date
    let appVersion: String
    let deviceInfo: String
    
    init(type: String, message: String, email: String?, appVersion: String, deviceInfo: String) {
        self.id = UUID()
        self.type = type
        self.message = message
        self.email = email
        self.createdAt = Date()
        self.appVersion = appVersion
        self.deviceInfo = deviceInfo
    }
}
