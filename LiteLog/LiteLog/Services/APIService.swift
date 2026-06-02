import Foundation
import Alamofire

class APIService {
    static let shared = APIService()
    
    #if DEBUG
    private let baseURL = URL(string: "http://10.226.12.52:8080")!
    #else
    private let baseURL = URL(string: "https://litelog.com.cn")!
    #endif
    
    private init() {}
    
    func submitFeedback(_ feedback: UserFeedback) async throws {
        let endpoint = baseURL.appending(path: "/feedback/submit")
        
        let parameters: [String: Any] = [
            "type": feedback.type,
            "message": feedback.message,
            "email": feedback.email ?? "",
            "appVersion": feedback.appVersion,
            "deviceInfo": feedback.deviceInfo
        ]
        
        let token = SettingsManager.shared.token
        
        return try await withCheckedThrowingContinuation { continuation in
            var headers: HTTPHeaders = [:]
            if let token = token {
                headers["Authorization"] = "Bearer \(token)"
            }
            
            AF.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let decoder = JSONDecoder()
                            let response = try decoder.decode(FeedbackSubmitResponse.self, from: data)
                            
                            if !response.success {
                                continuation.resume(throwing: APIError.serverErrorWithCode(response.code, response.message ?? "unknown_error"))
                            } else {
                                continuation.resume()
                            }
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    func sendSMSCode(phone: String, type: String = "login") async throws -> Bool {
        let endpoint = baseURL.appending(path: "/auth/sms/send")
        
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
    
    func login(phone: String, password: String) async throws -> AuthResponse {
        let endpoint = baseURL.appending(path: "/auth/login")
        
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
                            let authResponse = try decoder.decode(AuthResponse.self, from: data)
                            continuation.resume(returning: authResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
                    }
                }
        }
    }
    
    func loginWithSMSCode(phone: String, code: String) async throws -> AuthResponse {
        let endpoint = baseURL.appending(path: "/auth/login/sms")
        
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
                            let authResponse = try decoder.decode(AuthResponse.self, from: data)
                            continuation.resume(returning: authResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
                    }
                }
        }
    }
    
    func register(phone: String, code: String, password: String) async throws -> AuthResponse {
        let endpoint = baseURL.appending(path: "/auth/register")
        
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
                            let authResponse = try decoder.decode(AuthResponse.self, from: data)
                            continuation.resume(returning: authResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
                    }
                }
        }
    }
    
    func logout(token: String?) async throws -> LogoutResponse {
        let endpoint = baseURL.appending(path: "/auth/logout")
        
        var headers: HTTPHeaders = [:]
        if let token = token {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .get, headers: headers)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let decoder = JSONDecoder()
                            let logoutResponse = try decoder.decode(LogoutResponse.self, from: data)
                            continuation.resume(returning: logoutResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
                    }
                }
        }
    }
    
    func updateProfile(nickname: String, avatarUrl: String?) async throws -> UpdateProfileResponse {
        let endpoint = baseURL.appending(path: "/user/profile")
        
        var parameters: [String: Any] = [
            "nickname": nickname
        ]
        
        if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
            parameters["avatarUrl"] = avatarUrl
        }
        
        let token = SettingsManager.shared.token
        
        return try await withCheckedThrowingContinuation { continuation in
            var headers: HTTPHeaders = [:]
            if let token = token {
                headers["Authorization"] = "Bearer \(token)"
            }
            
            AF.request(endpoint, method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let decoder = JSONDecoder()
                            let profileResponse = try decoder.decode(UpdateProfileResponse.self, from: data)
                            continuation.resume(returning: profileResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
                    }
                }
        }
    }
    
    func uploadAvatar(image: UIImage) async throws -> AvatarUploadResponse {
        let endpoint = baseURL.appending(path: "/user/avatar/upload")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.serverError("图片转换失败")
        }
        
        let token = SettingsManager.shared.token
        
        return try await withCheckedThrowingContinuation { continuation in
            var headers: HTTPHeaders = [:]
            if let token = token {
                headers["Authorization"] = "Bearer \(token)"
            }
            
            AF.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(imageData, withName: "file", fileName: "avatar.jpg", mimeType: "image/jpeg")
            }, to: endpoint, headers: headers)
            .validate(statusCode: 200..<300)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoder = JSONDecoder()
                        let uploadResponse = try decoder.decode(AvatarUploadResponse.self, from: data)
                        continuation.resume(returning: uploadResponse)
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
    case serverErrorWithCode(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return NSLocalizedString("error.invalid_response", comment: "")
        case .networkError: return NSLocalizedString("error.network_error", comment: "")
        case .decodingError: return NSLocalizedString("error.decoding_error", comment: "")
        case .serverError(let message): return message
        case .serverErrorWithCode(let code, let message):
            return localizedErrorMessage(for: code, message: message)
        }
    }
    
    private func localizedErrorMessage(for code: Int, message: String) -> String {
        switch code {
        case 20000:
            return NSLocalizedString("error.success", comment: "")
        case 40000:
            return NSLocalizedString("error.param_error", comment: "")
        case 40001:
            return NSLocalizedString("error.feedback_type_invalid", comment: "")
        case 40002:
            return NSLocalizedString("error.feedback_message_empty", comment: "")
        case 40003:
            return NSLocalizedString("error.feedback_message_too_long", comment: "")
        case 40100:
            return NSLocalizedString("error.unauthorized", comment: "")
        case 50000:
            return NSLocalizedString("error.server_failure", comment: "")
        default:
            return NSLocalizedString("error.unknown", comment: "")
        }
    }
}
