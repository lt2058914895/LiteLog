import Foundation
import Alamofire

class APIService {
    static let shared = APIService()
    
    #if DEBUG
    private let baseURL = URL(string: "http://localhost:8080")!
    #else
    private let baseURL = URL(string: "https://litelog.com.cn")!
    #endif
    
    private init() {}
    
    private var session: Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return Session(configuration: configuration)
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
            print("DEBUG: Sending request to \(endpoint)")
            session.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default)
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
    
    func uploadAvatar(image: UIImage) async throws -> AvatarUploadResponse {
        let endpoint = baseURL.appendingPathComponent("user/avatar/upload")

        return try await withCheckedThrowingContinuation { continuation in
            AF.upload(multipartFormData: { multipartFormData in
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    multipartFormData.append(imageData, withName: "file", fileName: "avatar.jpg", mimeType: "image/jpeg")
                }
            }, to: endpoint)
            .validate(statusCode: 200..<300)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoder = JSONDecoder()
                        let avatarResponse = try decoder.decode(AvatarUploadResponse.self, from: data)
                        continuation.resume(returning: avatarResponse)
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
        let endpoint = baseURL.appendingPathComponent("user/profile")

        var parameters: [String: Any] = [
            "nickname": nickname
        ]
        
        if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
            parameters["avatarUrl"] = avatarUrl
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            print("DEBUG: Sending updateProfile request to \(endpoint) with parameters: \(parameters)")
            session.request(endpoint, method: .put, parameters: parameters, encoding: JSONEncoding.default)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("DEBUG: Response data: \(responseString)")
                    }
                    do {
                        let decoder = JSONDecoder()
                        let profileResponse = try decoder.decode(UpdateProfileResponse.self, from: data)
                        continuation.resume(returning: profileResponse)
                    } catch {
                        print("DEBUG: Decoding error: \(error)")
                        continuation.resume(throwing: APIError.decodingError)
                    }
                case .failure(let error):
                    print("DEBUG: API Error: \(error)")
                    continuation.resume(throwing: APIError.invalidResponse)
                }
            }
        }
    }
    
    func updateUserProfile(height: Double, gender: Int, age: Int, goalWeight: Double, weightUnit: String) async throws -> UpdateProfileResponse {
        let endpoint = baseURL.appendingPathComponent("user/profile")

        let parameters: [String: Any] = [
            "height": height,
            "gender": gender,
            "age": age,
            "goalWeight": goalWeight,
            "weightUnit": weightUnit
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .put, parameters: parameters, encoding: JSONEncoding.default)
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
                return dict
            }
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default)
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
            }, to: endpoint)
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