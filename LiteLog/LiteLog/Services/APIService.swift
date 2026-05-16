import Foundation
import Alamofire

class APIService {
    static let shared = APIService()
    
    private let baseURL = URL(string: "https://litelog.com")!
    
    private init() {}
    
    func submitFeedback(_ feedback: UserFeedback) async throws {
        let endpoint = baseURL.appending(path: "/feedback")
        
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
    
    func sendSMSCode(phone: String, type: String = "login") async throws -> Bool {
        let endpoint = baseURL.appending(path: "/login/sms/send")
        
        let parameters: [String: Any] = [
            "phone": phone,
            "type": type
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .validate(statusCode: 200..<300)
                .response { response in
                    switch response.result {
                    case .success:
                        if let data = response.data,
                           let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let success = result["success"] as? Bool {
                            continuation.resume(returning: success)
                        } else {
                            continuation.resume(returning: true)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.networkError)
                    }
                }
        }
    }
    
    func loginWithPassword(phone: String, password: String) async throws -> LoginResponse {
        let endpoint = baseURL.appending(path: "/login/password")
        
        let parameters: [String: Any] = [
            "phone": phone,
            "password": password
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let decoder = JSONDecoder()
                            let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                            continuation.resume(returning: loginResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
                    }
                }
        }
    }
    
    func loginWithSMSCode(phone: String, code: String) async throws -> LoginResponse {
        let endpoint = baseURL.appending(path: "/login/sms")
        
        let parameters: [String: Any] = [
            "phone": phone,
            "code": code
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let decoder = JSONDecoder()
                            let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                            continuation.resume(returning: loginResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
                    }
                }
        }
    }
    
    func register(phone: String, code: String, password: String) async throws -> LoginResponse {
        let endpoint = baseURL.appending(path: "/register")
        
        let parameters: [String: Any] = [
            "phone": phone,
            "code": code,
            "password": password
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let decoder = JSONDecoder()
                            let registerResponse = try decoder.decode(LoginResponse.self, from: data)
                            continuation.resume(returning: registerResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
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

@frozen
public struct LoginResponse: Codable, Sendable {
    public let success: Bool
    public let token: String?
    public let userId: String?
    public let message: String?
}