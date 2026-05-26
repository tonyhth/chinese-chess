import Foundation
import Combine

class ProfileViewModel: ObservableObject {
    @Published var totalStars: Int = 0
    @Published var totalWordsLearned: Int = 0
    @Published var totalWordsMastered: Int = 0
    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var mistakeCount: Int = 0

    private let progressRepo: ProgressRepository

    init(progressRepo: ProgressRepository) {
        self.progressRepo = progressRepo
    }

    func load() {
        let profile = progressRepo.profile
        totalStars = progressRepo.totalStars
        totalWordsLearned = progressRepo.totalWordsLearned
        totalWordsMastered = progressRepo.wordProgress.values.filter { $0.mastery == .mastered }.count
        currentStreak = profile.currentStreak
        bestStreak = profile.bestStreak
        mistakeCount = progressRepo.mistakeWords().count
    }
}
