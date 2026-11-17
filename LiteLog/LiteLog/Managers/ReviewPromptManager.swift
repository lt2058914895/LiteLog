import CoreData
import StoreKit
import UIKit

@MainActor
final class ReviewPromptManager {
    static let shared = ReviewPromptManager()

    private let lastPromptKey = "review.lastPromptDate"
    private let minimumRecordCount = 7
    private let minimumDaysSinceFirstRecord = 3
    private let minimumDaysBetweenPrompts = 120

    private init() {}

    func considerPrompt(context: NSManagedObjectContext) {
        let request = WeightRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: true)]

        guard let records = try? context.fetch(request),
              records.count >= minimumRecordCount,
              let firstRecordDate = records.first?.date,
              Date().timeIntervalSince(firstRecordDate) >= TimeInterval(minimumDaysSinceFirstRecord * 86_400) else {
            return
        }

        if let lastPromptDate = UserDefaults.standard.object(forKey: lastPromptKey) as? Date,
           Date().timeIntervalSince(lastPromptDate) < TimeInterval(minimumDaysBetweenPrompts * 86_400) {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.requestReviewIfPossible()
        }
    }

    private func requestReviewIfPossible() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        AppStore.requestReview(in: scene)
    }
}
