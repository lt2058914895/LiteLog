import Foundation
import Alamofire

@MainActor
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
        let endpoint = baseURL.appending(path: "/auth/login/password")
        
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
    
    func resetPassword(phone: String, code: String, newPassword: String) async throws -> ResetPasswordResponse {
        let endpoint = baseURL.appending(path: "/auth/password/reset")
        
        let parameters: [String: Any] = [
            "phone": phone,
            "code": code,
            "newPassword": newPassword
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let decoder = JSONDecoder()
                            let resetResponse = try decoder.decode(ResetPasswordResponse.self, from: data)
                            continuation.resume(returning: resetResponse)
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
    
    func updateUserProfile(height: Double, gender: Int, age: Int, goalWeight: Double, weightUnit: String) async throws -> UpdateProfileResponse {
        let endpoint = baseURL.appending(path: "/user/profile")
        
        let parameters: [String: Any] = [
            "height": height,
            "gender": gender,
            "age": age,
            "goalWeight": goalWeight,
            "weightUnit": weightUnit
        ]
        
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
            .responseData { response in
                if let data = response.data {
                    do {
                        let decoder = JSONDecoder()
                            let uploadResponse = try decoder.decode(AvatarUploadResponse.self, from: data)
                        continuation.resume(returning: uploadResponse)
                    } catch {
                        continuation.resume(throwing: APIError.decodingError)
                    }
                } else {
                    continuation.resume(throwing: APIError.invalidResponse)
                }
            }
        }
    }
    
    func deleteWeightRecords(recordIds: [String]) async throws -> WeightRecordSyncResponse {
        // 创建标记为已删除的记录请求
        let records = recordIds.map { recordId in
            WeightRecordRequest(
                recordId: recordId,
                weight: 0.0,
                bodyFatPercentage: nil,
                waistCircumference: nil,
                hipCircumference: nil,
                chestCircumference: nil,
                thighCircumference: nil,
                note: nil,
                date: Date().timeIntervalSince1970,
                createdAt: Date().timeIntervalSince1970,
                updatedAt: Date().timeIntervalSince1970,
                deleted: true,
                imageUrl: nil,
                imageFileName: nil,
                measurementTimePeriod: nil
            )
        }
        
        return try await syncWeightRecords(records: records)
    }
    
    func syncWeightRecords(records: [WeightRecordRequest]) async throws -> WeightRecordSyncResponse {
        let endpoint = baseURL.appending(path: "/weight/sync")
        
        let token = SettingsManager.shared.token
        
        // 将记录转换为字典数组
        let parameters: [String: Any] = [
            "records": records.map { record in
                var dict: [String: Any] = [
                    "recordId": record.recordId,
                    "weight": record.weight,
                    "bodyFatPercentage": record.bodyFatPercentage as Any,
                    "waistCircumference": record.waistCircumference as Any,
                    "hipCircumference": record.hipCircumference as Any,
                    "chestCircumference": record.chestCircumference as Any,
                    "thighCircumference": record.thighCircumference as Any,
                    "measurementTimePeriod": record.measurementTimePeriod as Any,
                    "note": record.note as Any,
                    "date": record.date,
                    "createdAt": record.createdAt,
                    "updatedAt": record.updatedAt
                ]
                if let deleted = record.deleted {
                    dict["deleted"] = deleted
                }
                if let imageUrl = record.imageUrl {
                    dict["imageUrl"] = imageUrl
                }
                if let imageFileName = record.imageFileName {
                    dict["imageFileName"] = imageFileName
                }
                return dict
            }
        ]
        
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
                            let syncResponse = try decoder.decode(WeightRecordSyncResponse.self, from: data)
                            continuation.resume(returning: syncResponse)
                        } catch {
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure:
                        continuation.resume(throwing: APIError.invalidResponse)
                    }
                }
        }
    }
    
    func syncWeightRecordsWithImages(records: [WeightRecordRequest], images: [(recordId: String, image: UIImage)]) async throws -> WeightRecordSyncResponse {
        let endpoint = baseURL.appending(path: "/weight/sync-with-images")
        
        let token = SettingsManager.shared.token
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WeightRecordSyncResponse, Error>) in
            var headers: HTTPHeaders = [:]
            if let token = token {
                headers["Authorization"] = "Bearer \(token)"
            }
            
            let encoder = JSONEncoder()
            var recordsJson: String
            do {
                let recordsData = try encoder.encode(WeightRecordSyncRequest(records: records))
                recordsJson = String(data: recordsData, encoding: .utf8) ?? "[]"
            } catch {
                continuation.resume(throwing: APIError.decodingError)
                return
            }
            
            AF.upload(multipartFormData: { multipartFormData in
                if let jsonData = recordsJson.data(using: .utf8) {
                    multipartFormData.append(jsonData, withName: "records")
                }
                
                for (recordId, image) in images {
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        let fileName = "\(recordId)_image.jpg"
                        multipartFormData.append(imageData, withName: "files", fileName: fileName, mimeType: "image/jpeg")
                    }
                }
            }, to: endpoint, headers: headers)
            .validate(statusCode: 200..<300)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoder = JSONDecoder()
                            let syncResponse = try decoder.decode(WeightRecordSyncResponse.self, from: data)
                        continuation.resume(returning: syncResponse)
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

enum APIError: Error, LocalizedError, Equatable {
    case invalidResponse
    case networkError
    case decodingError
    case serverError(String)
    case serverErrorWithCode(Int, String)
    case notLoggedIn
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return NSLocalizedString("error.invalid_response", comment: "")
        case .networkError: return NSLocalizedString("error.network_error", comment: "")
        case .decodingError: return NSLocalizedString("error.decoding_error", comment: "")
        case .serverError(let message): return message
        case .serverErrorWithCode(let code, let message):
            return localizedErrorMessage(for: code, message: message)
        case .notLoggedIn: return NSLocalizedString("error.not_logged_in", comment: "")
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
