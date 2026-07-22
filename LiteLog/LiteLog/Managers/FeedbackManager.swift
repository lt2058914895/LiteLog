import Foundation
import Combine
import os

class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "FeedbackManager")
    
    private let feedbacksKey = "com.litelog.feedbacks"
    private let pendingFeedbacksKey = "com.litelog.pending_feedbacks"
    
    @Published private(set) var feedbacks: [UserFeedback] = []
    @Published private(set) var pendingFeedbacks: [UserFeedback] = []
    
    private var sendingIds: Set<UUID> = []
    private let queue = DispatchQueue(label: "com.litelog.feedbackQueue")
    private var isInitialized = false
    
    private init() {
        loadFeedbacks()
        loadPendingFeedbacks()
        Task {
            await syncPendingFeedbacks()
            isInitialized = true
        }
    }
    
    func submit(_ feedback: UserFeedback) async throws {
        feedbacks.append(feedback)
        pendingFeedbacks.append(feedback)
        saveFeedbacks()
        savePendingFeedbacks()
        
        // 确保初始化同步完成后再发送新反馈，避免重复提交
        if isInitialized {
            try await sendFeedback(feedback)
        }
        // 如果初始化未完成，新反馈会被添加到 pendingFeedbacks，由 syncPendingFeedbacks 统一发送
    }
    
    private func sendFeedback(_ feedback: UserFeedback) async throws {
        let shouldSend = try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if self.sendingIds.contains(feedback.id) {
                    #if DEBUG
                    Self.logger.debug("Feedback \(feedback.id) is already being sent, skipping")
                    #endif
                    continuation.resume(returning: false)
                    return
                }
                self.sendingIds.insert(feedback.id)
                continuation.resume(returning: true)
            }
        }
        
        guard shouldSend else {
            return
        }
        
        defer {
            queue.async {
                self.sendingIds.remove(feedback.id)
            }
        }
        
        try await APIService.shared.submitFeedback(feedback)
        
        if let index = pendingFeedbacks.firstIndex(where: { $0.id == feedback.id }) {
            pendingFeedbacks.remove(at: index)
            savePendingFeedbacks()
        }
    }
    
    private func syncPendingFeedbacks() async {
        for feedback in pendingFeedbacks {
            do {
                try await sendFeedback(feedback)
            } catch {
                Self.logger.error("Failed to sync pending feedback: \(error.localizedDescription)")
            }
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
            Self.logger.error("Failed to load feedbacks: \(error.localizedDescription)")
            feedbacks = []
        }
    }
    
    private func saveFeedbacks() {
        do {
            let data = try JSONEncoder().encode(feedbacks)
            UserDefaults.standard.set(data, forKey: feedbacksKey)
        } catch {
            Self.logger.error("Failed to save feedbacks: \(error.localizedDescription)")
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
            Self.logger.error("Failed to load pending feedbacks: \(error.localizedDescription)")
            pendingFeedbacks = []
        }
    }
    
    private func savePendingFeedbacks() {
        do {
            let data = try JSONEncoder().encode(pendingFeedbacks)
            UserDefaults.standard.set(data, forKey: pendingFeedbacksKey)
        } catch {
            Self.logger.error("Failed to save pending feedbacks: \(error.localizedDescription)")
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
