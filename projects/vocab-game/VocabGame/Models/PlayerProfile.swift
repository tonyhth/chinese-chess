import Foundation

struct PlayerProfile: Codable {
    var totalStars: Int = 0
    var totalWordsLearned: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var lastPlayDate: Date? = nil
    var totalPlayTime: TimeInterval = 0
    var coins: Int = 0
}
