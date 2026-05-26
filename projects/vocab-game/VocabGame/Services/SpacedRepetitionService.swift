import Foundation

class SpacedRepetitionService {
    /// Update word progress after answering
    static func updateProgress(_ progress: WordProgress, isCorrect: Bool) -> WordProgress {
        var p = progress
        let now = Date()

        if isCorrect {
            p.correctCount += 1
            p.consecutiveCorrect += 1

            // Schedule next review based on CURRENT mastery (before upgrade)
            switch p.mastery {
            case .new:
                p.nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: now)!
            case .learning:
                p.nextReviewDate = Calendar.current.date(byAdding: .day, value: 3, to: now)!
            case .familiar:
                p.nextReviewDate = Calendar.current.date(byAdding: .day, value: 7, to: now)!
            case .mastered:
                p.nextReviewDate = Calendar.current.date(byAdding: .day, value: 30, to: now)!
            }

            // Upgrade mastery AFTER scheduling
            if p.mastery != .mastered {
                p.mastery = MasteryLevel(rawValue: p.mastery.rawValue + 1) ?? .mastered
            }
        } else {
            p.wrongCount += 1
            p.consecutiveCorrect = 0

            // Downgrade mastery
            if p.mastery != .new {
                p.mastery = MasteryLevel(rawValue: p.mastery.rawValue - 1) ?? .new
            }

            // Review again in 4 hours
            p.nextReviewDate = Calendar.current.date(byAdding: .hour, value: 4, to: now)!
        }

        p.lastReviewed = now
        return p
    }
}
