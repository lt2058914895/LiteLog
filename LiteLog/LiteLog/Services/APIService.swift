import Foundation
import Alamofire

class APIService {
    static let shared = APIService()
    
    #if DEBUG
    public let baseURL = URL(string: "http://10.226.220.119:8080")!
    #else
    public let baseURL = URL(string: "https://litelog.com.cn")!
    #endif
    
    private init() {}
    
    private let session: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return Session(configuration: configuration)
    }()
    
    private func defaultHeaders() -> HTTPHeaders {
        let identifierHeaders = UserIdentifierManager.shared.getIdentifierHeader()
        var headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        for (key, value) in identifierHeaders {
            headers.add(name: key, value: value)
        }
        return headers
    }
    
    func submitFeedback(_ feedback: UserFeedback) async throws {
        let endpoint = baseURL.appendingPathComponent("feedback/submit")

        let parameters: [String: Any] = [
            "type": feedback.type,
            "message": feedback.message,
            "email": feedback.email ?? "",
            "appVersion": feedback.appVersion,
            "deviceInfo": feedback.deviceInfo
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            print("DEBUG: submitFeedback - URL: \(endpoint)")
            print("DEBUG: submitFeedback - Parameters: \(parameters)")
            
            session.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: defaultHeaders())
                .validate(statusCode: 200..<300)
                .responseData { response in
                    print("DEBUG: submitFeedback - Response status code: \(response.response?.statusCode ?? -1)")
                    print("DEBUG: submitFeedback - Response headers: \(response.response?.headers ?? HTTPHeaders())")
                    
                    switch response.result {
                    case .success(let data):
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("DEBUG: submitFeedback - Response data: \(responseString)")
                        }
                        do {
                            let decoder = JSONDecoder()
                            let feedbackResponse = try decoder.decode(FeedbackSubmitResponse.self, from: data)
                            
                            if !feedbackResponse.success {
                                print("DEBUG: submitFeedback - Response success is false")
                                continuation.resume(throwing: APIError.serverErrorWithCode(feedbackResponse.code, feedbackResponse.message ?? "unknown_error"))
                            } else {
                                continuation.resume()
                            }
                        } catch {
                            print("DEBUG: submitFeedback - Decoding error: \(error)")
                            continuation.resume(throwing: APIError.decodingError)
                        }
                    case .failure(let error):
                        print("DEBUG: submitFeedback - API Error: \(error)")
                        
                        if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                            print("DEBUG: submitFeedback - Error response data: \(responseString)")
                            
                            do {
                                let decoder = JSONDecoder()
                                let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
                                continuation.resume(throwing: APIError.serverErrorWithCode(errorResponse.status ?? -1, errorResponse.message ?? "未知错误"))
                            } catch {
                                print("DEBUG: submitFeedback - Failed to decode ErrorResponse: \(error)")
                                continuation.resume(throwing: APIError.serverError(responseString))
                            }
                        } else {
                            continuation.resume(throwing: APIError.serverError("网络请求失败，请检查网络连接"))
                        }
                    }
                }
        }
    }
    
    func uploadAvatar(image: UIImage) async throws -> AvatarUploadResponse {
        let endpoint = baseURL.appendingPathComponent("user/avatar/upload")
        let userId = UserIdentifierManager.shared.deviceId
        let safeUserId = userId.replacingOccurrences(of: "-", with: "")
        
        return try await withCheckedThrowingContinuation { continuation in
            print("DEBUG: uploadAvatar - URL: \(endpoint)")
            
            session.upload(multipartFormData: { multipartFormData in
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    multipartFormData.append(imageData, withName: "file", fileName: "\(safeUserId).jpg", mimeType: "image/jpeg")
                }
            }, to: endpoint, headers: defaultHeaders())
            .validate(statusCode: 200..<300)
            .responseData { response in
                self.handleResponse(response, debugTag: "uploadAvatar", continuation: continuation)
            }
        }
    }
    
    func updateProfile(nickname: String?, avatarUrl: String?) async throws -> UpdateProfileResponse {
        var parameters: [String: Any] = [:]
        
        if let nickname = nickname, !nickname.isEmpty {
            parameters["nickname"] = nickname
        }
        
        if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
            parameters["avatarUrl"] = avatarUrl
        }
        
        return try await performProfileUpdate(parameters: parameters)
    }
    
    func updateUserProfile(height: Double, gender: Int, age: Int, goalWeight: Double, weightUnit: String) async throws -> UpdateProfileResponse {
        let parameters: [String: Any] = [
            "height": height,
            "gender": gender,
            "age": age,
            "goalWeight": goalWeight,
            "weightUnit": weightUnit
        ]
        
        return try await performProfileUpdate(parameters: parameters)
    }
    
    private func performProfileUpdate(parameters: [String: Any]) async throws -> UpdateProfileResponse {
        let endpoint = baseURL.appendingPathComponent("user/profile")
        
        return try await withCheckedThrowingContinuation { continuation in
            print("DEBUG: updateProfile - URL: \(endpoint)")
            print("DEBUG: updateProfile - Parameters: \(parameters)")
            
            session.request(endpoint, method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: defaultHeaders())
                .validate(statusCode: 200..<300)
                .responseData { response in
                    self.handleResponse(response, debugTag: "updateProfile", continuation: continuation)
                }
        }
    }
    
    private func handleResponse<T: Decodable>(_ response: AFDataResponse<Data>, debugTag: String, continuation: CheckedContinuation<T, Error>) {
        print("DEBUG: \(debugTag) - Response status code: \(response.response?.statusCode ?? -1)")
        print("DEBUG: \(debugTag) - Response headers: \(response.response?.headers ?? HTTPHeaders())")
        
        switch response.result {
        case .success(let data):
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG: \(debugTag) - Response data: \(responseString)")
            }
            do {
                let decoder = JSONDecoder()
                let decodedResponse = try decoder.decode(T.self, from: data)
                continuation.resume(returning: decodedResponse)
            } catch {
                print("DEBUG: \(debugTag) - Decoding error: \(error)")
                continuation.resume(throwing: APIError.decodingError)
            }
        case .failure(let error):
            print("DEBUG: \(debugTag) - API Error: \(error)")
            
            if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG: \(debugTag) - Error response data: \(responseString)")
                
                do {
                    let decoder = JSONDecoder()
                    let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
                    continuation.resume(throwing: APIError.serverErrorWithCode(errorResponse.status ?? -1, errorResponse.message ?? "未知错误"))
                } catch {
                    print("DEBUG: \(debugTag) - Failed to decode ErrorResponse: \(error)")
                    continuation.resume(throwing: APIError.serverError(responseString))
                }
            } else {
                continuation.resume(throwing: APIError.serverError("网络请求失败，请检查网络连接"))
            }
        }
    }
    
    func deleteWeightRecords(recordIds: [String]) async throws -> WeightRecordSyncResponse {
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
        let endpoint = baseURL.appendingPathComponent("weight/sync")

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
                if let deleteImage = record.deleteImage {
                    dict["deleteImage"] = deleteImage
                }
                return dict
            }
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            print("DEBUG: syncWeightRecords - URL: \(endpoint)")
            
            session.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: defaultHeaders())
                .validate(statusCode: 200..<300)
                .responseData { response in
                    self.handleResponse(response, debugTag: "syncWeightRecords", continuation: continuation)
                }
        }
    }
    
    func syncWeightRecordsWithImages(records: [WeightRecordRequest], images: [(recordId: String, image: UIImage)]) async throws -> WeightRecordSyncResponse {
        let endpoint = baseURL.appendingPathComponent("weight/sync-with-images")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WeightRecordSyncResponse, Error>) in
            let encoder = JSONEncoder()
            var recordsJson: String
            do {
                let recordsData = try encoder.encode(WeightRecordSyncRequest(records: records))
                recordsJson = String(data: recordsData, encoding: .utf8) ?? "[]"
            } catch {
                continuation.resume(throwing: APIError.decodingError)
                return
            }
            
            print("DEBUG: syncWeightRecordsWithImages - URL: \(endpoint)")
            
            session.upload(multipartFormData: { multipartFormData in
                if let jsonData = recordsJson.data(using: .utf8) {
                    multipartFormData.append(jsonData, withName: "records")
                }
                
                for (recordId, image) in images {
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        let fileName = "\(recordId)_image.jpg"
                        multipartFormData.append(imageData, withName: "files", fileName: fileName, mimeType: "image/jpeg")
                    }
                }
            }, to: endpoint, headers: defaultHeaders())
            .validate(statusCode: 200..<300)
            .responseData { response in
                self.handleResponse(response, debugTag: "syncWeightRecordsWithImages", continuation: continuation)
            }
        }
    }
    
    func fetchAllData() async throws -> FetchAllDataResponse {
        let endpoint = baseURL.appendingPathComponent("user/fetch-all-data")
        
        return try await withCheckedThrowingContinuation { continuation in
            print("DEBUG: fetchAllData - URL: \(endpoint)")
            
            session.request(endpoint, method: .get, headers: defaultHeaders())
                .validate(statusCode: 200..<300)
                .responseData { response in
                    self.handleResponse(response, debugTag: "fetchAllData", continuation: continuation)
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

public struct FetchAllDataResponse: Sendable, Decodable {
    public let success: Bool
    public let message: String?
    public let profile: UpdateProfileResponse?
    public let records: [WeightRecordRequest]?
}