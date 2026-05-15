import Foundation
import Combine

class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    private let feedbacksKey = "com.litelog.feedbacks"
    
    @Published private(set) var feedbacks: [UserFeedback] = []
    
    private init() {
        loadFeedbacks()
    }
    
    func submit(_ feedback: UserFeedback) {
        feedbacks.append(feedback)
        saveFeedbacks()
    }
    
    private func loadFeedbacks() {
        guard let data = UserDefaults.standard.data(forKey: feedbacksKey) else {
            feedbacks = []
            return
        }
        
        do {
            feedbacks = try JSONDecoder().decode([UserFeedback].self, from: data)
        } catch {
            print("Failed to load feedbacks: \(error)")
            feedbacks = []
        }
    }
    
    private func saveFeedbacks() {
        do {
            let data = try JSONEncoder().encode(feedbacks)
            UserDefaults.standard.set(data, forKey: feedbacksKey)
        } catch {
            print("Failed to save feedbacks: \(error)")
        }
    }
    
    func getFeedbackStats() -> [String: Int] {
        var stats: [String: Int] = [:]
        for feedback in feedbacks {
            stats[feedback.type, default: 0] += 1
        }
        return stats
    }
    
    func clearAllFeedbacks() {
        feedbacks.removeAll()
        UserDefaults.standard.removeObject(forKey: feedbacksKey)
    }
}
