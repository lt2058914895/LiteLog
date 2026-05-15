import Foundation
import Combine

class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    private let feedbacksKey = "com.litelog.feedbacks"
    private let pendingFeedbacksKey = "com.litelog.pending_feedbacks"
    
    @Published private(set) var feedbacks: [UserFeedback] = []
    @Published private(set) var pendingFeedbacks: [UserFeedback] = []
    
    private init() {
        loadFeedbacks()
        loadPendingFeedbacks()
        Task { await syncPendingFeedbacks() }
    }
    
    func submit(_ feedback: UserFeedback) {
        feedbacks.append(feedback)
        pendingFeedbacks.append(feedback)
        saveFeedbacks()
        savePendingFeedbacks()
        
        Task { await sendFeedback(feedback) }
    }
    
    private func sendFeedback(_ feedback: UserFeedback) async {
        do {
            try await APIService.shared.submitFeedback(feedback)
            
            if let index = pendingFeedbacks.firstIndex(where: { $0.id == feedback.id }) {
                pendingFeedbacks.remove(at: index)
                savePendingFeedbacks()
            }
        } catch {
            print("Failed to send feedback: \(error.localizedDescription)")
        }
    }
    
    private func syncPendingFeedbacks() async {
        for feedback in pendingFeedbacks {
            await sendFeedback(feedback)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
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
    
    private func loadPendingFeedbacks() {
        guard let data = UserDefaults.standard.data(forKey: pendingFeedbacksKey) else {
            pendingFeedbacks = []
            return
        }
        
        do {
            pendingFeedbacks = try JSONDecoder().decode([UserFeedback].self, from: data)
        } catch {
            print("Failed to load pending feedbacks: \(error)")
            pendingFeedbacks = []
        }
    }
    
    private func savePendingFeedbacks() {
        do {
            let data = try JSONEncoder().encode(pendingFeedbacks)
            UserDefaults.standard.set(data, forKey: pendingFeedbacksKey)
        } catch {
            print("Failed to save pending feedbacks: \(error)")
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
        pendingFeedbacks.removeAll()
        UserDefaults.standard.removeObject(forKey: feedbacksKey)
        UserDefaults.standard.removeObject(forKey: pendingFeedbacksKey)
    }
}
