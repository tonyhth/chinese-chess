import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var greeting: String = ""
    @Published var streak: Int = 0
    @Published var totalStars: Int = 0
    @Published var totalWordsLearned: Int = 0
    @Published var wordsReviewedToday: Int = 0
    @Published var hasActiveSession: Bool = false

    private let progressRepo: ProgressRepository

    init(progressRepo: ProgressRepository) {
        self.progressRepo = progressRepo
    }

    func load() {
        updateGreeting()
        let profile = progressRepo.profile
        streak = profile.currentStreak
        totalStars = progressRepo.totalStars
        totalWordsLearned = progressRepo.totalWordsLearned
        wordsReviewedToday = progressRepo.wordsReviewedToday
        hasActiveSession = progressRepo.activeSession != nil
    }

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: greeting = "早上好！今天要背几个单词？"
        case 12..<14: greeting = "中午好！来一局轻松的？"
        case 14..<18: greeting = "下午好！保持学习节奏~"
        case 18..<22: greeting = "晚上好！今天学了多少？"
        default: greeting = "夜深了，注意休息哦~"
        }
    }
}
