import Foundation

/// Static level definition, compiled into Bundle JSON.
struct LevelDefinition: Identifiable, Codable {
    let id: Int          // 1-25
    let name: String
    let wordGroup: Int   // maps to Word.group
}

/// Runtime level state, persisted in progress.json.
struct LevelProgress: Codable {
    let levelId: Int
    var isCompleted: Bool
    var stars: Int       // 0-3
    var bestScore: Int

    static func initial(levelId: Int) -> LevelProgress {
        LevelProgress(levelId: levelId, isCompleted: false, stars: 0, bestScore: 0)
    }
}

// MARK: - Level Definitions (25 levels)

extension LevelDefinition {
    static let allLevels: [LevelDefinition] = [
        LevelDefinition(id: 1, name: "新手村庄", wordGroup: 1),
        LevelDefinition(id: 2, name: "语言花园", wordGroup: 2),
        LevelDefinition(id: 3, name: "认知森林", wordGroup: 3),
        LevelDefinition(id: 4, name: "科学小镇", wordGroup: 4),
        LevelDefinition(id: 5, name: "自然溪谷", wordGroup: 5),
        LevelDefinition(id: 6, name: "知识草原", wordGroup: 6),
        LevelDefinition(id: 7, name: "记忆湖泊", wordGroup: 7),
        LevelDefinition(id: 8, name: "逻辑山峰", wordGroup: 8),
        LevelDefinition(id: 9, name: "词汇峡谷", wordGroup: 9),
        LevelDefinition(id: 10, name: "语法沙漠", wordGroup: 10),
        LevelDefinition(id: 11, name: "阅读海洋", wordGroup: 11),
        LevelDefinition(id: 12, name: "听力瀑布", wordGroup: 12),
        LevelDefinition(id: 13, name: "写作冰川", wordGroup: 13),
        LevelDefinition(id: 14, name: "口语火山", wordGroup: 14),
        LevelDefinition(id: 15, name: "翻译平原", wordGroup: 15),
        LevelDefinition(id: 16, name: "文化丛林", wordGroup: 16),
        LevelDefinition(id: 17, name: "科技要塞", wordGroup: 17),
        LevelDefinition(id: 18, name: "历史遗迹", wordGroup: 18),
        LevelDefinition(id: 19, name: "艺术殿堂", wordGroup: 19),
        LevelDefinition(id: 20, name: "哲学迷宫", wordGroup: 20),
        LevelDefinition(id: 21, name: "天文台", wordGroup: 21),
        LevelDefinition(id: 22, name: "实验室", wordGroup: 22),
        LevelDefinition(id: 23, name: "图书馆", wordGroup: 23),
        LevelDefinition(id: 24, name: "竞技场", wordGroup: 24),
        LevelDefinition(id: 25, name: "终极城堡", wordGroup: 25),
    ]
}
