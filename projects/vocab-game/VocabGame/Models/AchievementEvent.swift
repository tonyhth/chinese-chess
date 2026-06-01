import Foundation

/// Events emitted by ViewModels — consumed by AchievementRepository
enum AchievementEvent {
    case wordLearned(totalCount: Int)
    case wordMastered(totalCount: Int)
    case streakDay(count: Int)
    case comboReached(count: Int)
    case petLevelUp(level: Int)
    case itemCollected(totalCount: Int)
    case matchCompleted(remainingSeconds: Int)
    case levelCompleted(levelId: Int, stars: Int)
    case dailyChallengeCompleted(streak: Int)
    case gamePlayed(totalGames: Int)
}
