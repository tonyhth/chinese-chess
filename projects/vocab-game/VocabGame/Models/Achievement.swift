import Foundation

enum AchievementCategory: String, Codable, CaseIterable {
    case learning = "学习"
    case streak = "坚持"
    case combo = "连击"
    case pet = "蛋仔"
    case game = "游戏"
    case collection = "收集"
}

struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let requirement: Int
    let reward: Int
    var progress: Int = 0
    var isUnlocked: Bool = false
    var unlockedAt: Date? = nil

    // MARK: - Catalog

    static let catalog: [Achievement] = [
        Achievement(id: "first_word", name: "第一个单词", description: "学会 1 个单词", icon: "🌱", category: .learning, requirement: 1, reward: 10),
        Achievement(id: "word_master_50", name: "词汇达人", description: "掌握 50 个单词", icon: "📚", category: .learning, requirement: 50, reward: 30),
        Achievement(id: "streak_7", name: "坚持一周", description: "连续打卡 7 天", icon: "🔥", category: .streak, requirement: 7, reward: 20),
        Achievement(id: "combo_10", name: "超级连击", description: "达成 10 连击", icon: "⚡", category: .combo, requirement: 10, reward: 15),
        Achievement(id: "pet_max", name: "满级蛋仔", description: "蛋仔升到 Lv.5", icon: "👑", category: .pet, requirement: 5, reward: 50),
        Achievement(id: "collector_10", name: "收藏家", description: "拥有 10 件商品", icon: "💎", category: .collection, requirement: 10, reward: 30),
        Achievement(id: "speed_demon", name: "速度之星", description: "配对游戏 30 秒内完成", icon: "🚀", category: .game, requirement: 1, reward: 25),
    ]
}

/// Lightweight save entry stored in PlayerProfile
struct AchievementSaveEntry: Codable {
    let progress: Int
    let isUnlocked: Bool
    let unlockedAt: Date?
}
