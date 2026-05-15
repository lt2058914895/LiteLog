import Foundation
import Alamofire

class APIService {
    static let shared = APIService()
    
    private let baseURL = URL(string: "https://api.litelog.app")!
    
    private init() {}
    
    func submitFeedback(_ feedback: UserFeedback) async throws {
        let endpoint = baseURL.appending(path: "/api/feedback")
        
        let parameters: [String: Any] = [
            "id": feedback.id.uuidString,
            "type": feedback.type,
            "message": feedback.message,
            "email": feedback.email ?? "",
            "appVersion": feedback.appVersion,
            "deviceInfo": feedback.deviceInfo,
            "createdAt": ISO8601DateFormatter().string(from: feedback.createdAt)
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .validate(statusCode: 200..<300)
                .response { response in
                    switch response.result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case networkError
    case decodingError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "无效的响应"
        case .networkError: return "网络错误，请检查网络连接"
        case .decodingError: return "数据解析错误"
        case .serverError(let message): return message
        }
    }
}