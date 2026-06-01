import Foundation

struct PlayerProfile: Codable {
    var totalStars: Int = 0
    var totalWordsLearned: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var lastPlayDate: Date? = nil
    var totalPlayTime: TimeInterval = 0
    var coins: Int = 0

    // Phase 4: Achievement progress
    var achievementProgress: [String: AchievementSaveEntry] = [:]

    // Phase 4: Daily goal
    var dailyGoalTarget: Int = 10
    var dailyGoalCompletedCount: Int = 0
    var dailyGoalLastResetDate: Date? = nil
    var dailyGoalConsecutiveDays: Int = 0
    var dailyGoalBonusClaimed: Bool = false
}
