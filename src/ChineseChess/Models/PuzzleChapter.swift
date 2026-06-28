import Foundation

// MARK: - 章节解锁条件

/// 章节解锁条件（enum，支持递归组合）
enum ChapterUnlockCondition {
    case none                                           // 无前置（第一章）
    case completeChapter(chapterId: String, count: Int) // 通关前一章 N 局
    case rank(Rank)                                     // 达到段位
    case and([ChapterUnlockCondition])                  // 全部满足
    case or([ChapterUnlockCondition])                   // 任一满足
}

// MARK: - 章节通关奖励

/// 章节通关奖励
enum ChapterReward {
    case unlockChapter(chapterId: String)
    case title(String)
}

// MARK: - 章节静态配置

/// 章节静态配置（编译期确定，不持久化）
struct ChapterConfig {
    let id: String                    // "ch1"..."ch7"
    let titleKey: String              // L10n key
    let subtitleKey: String           // L10n key
    let globalStart: Int              // 在全局排序列表中的起始索引
    let globalEnd: Int                // 结束索引（exclusive）
    let unlockCondition: ChapterUnlockCondition
    let reward: ChapterReward?

    /// 章节显示编号（1-7）
    var displayNumber: Int {
        Int(id.replacingOccurrences(of: "ch", with: "")) ?? 0
    }
}

// MARK: - 章节定义（7 章静态配置）

enum ChapterDefinitions {
    static let chapters: [ChapterConfig] = [
        // ch1: 1★全部（57局）- 和局+简单杀法
        ChapterConfig(id: "ch1", titleKey: "chapter.ch1.title", subtitleKey: "chapter.ch1.subtitle",
                      globalStart: 0,   globalEnd: 57,
                      unlockCondition: .none,
                      reward: .unlockChapter(chapterId: "ch2")),
        // ch2: 2★+3★前段 = 90局
        ChapterConfig(id: "ch2", titleKey: "chapter.ch2.title", subtitleKey: "chapter.ch2.subtitle",
                      globalStart: 57,  globalEnd: 147,
                      unlockCondition: .or([.completeChapter(chapterId: "ch1", count: 10), .rank(.scholar)]),
                      reward: .unlockChapter(chapterId: "ch3")),
        // ch3: 3★主体 = 110局
        ChapterConfig(id: "ch3", titleKey: "chapter.ch3.title", subtitleKey: "chapter.ch3.subtitle",
                      globalStart: 147, globalEnd: 257,
                      unlockCondition: .or([.completeChapter(chapterId: "ch2", count: 20), .rank(.juren)]),
                      reward: .unlockChapter(chapterId: "ch4")),
        // ch4: 3★中段 = 100局
        ChapterConfig(id: "ch4", titleKey: "chapter.ch4.title", subtitleKey: "chapter.ch4.subtitle",
                      globalStart: 257, globalEnd: 357,
                      unlockCondition: .completeChapter(chapterId: "ch3", count: 30),
                      reward: .unlockChapter(chapterId: "ch5")),
        // ch5: 3★末+4★前 = 100局
        ChapterConfig(id: "ch5", titleKey: "chapter.ch5.title", subtitleKey: "chapter.ch5.subtitle",
                      globalStart: 357, globalEnd: 457,
                      unlockCondition: .completeChapter(chapterId: "ch4", count: 40),
                      reward: .unlockChapter(chapterId: "ch6")),
        // ch6: 4★主体 = 72局
        ChapterConfig(id: "ch6", titleKey: "chapter.ch6.title", subtitleKey: "chapter.ch6.subtitle",
                      globalStart: 457, globalEnd: 529,
                      unlockCondition: .completeChapter(chapterId: "ch5", count: 50),
                      reward: .unlockChapter(chapterId: "ch7")),
        // ch7: 5★全部 = 22局（终极挑战）
        ChapterConfig(id: "ch7", titleKey: "chapter.ch7.title", subtitleKey: "chapter.ch7.subtitle",
                      globalStart: 529, globalEnd: 551,
                      unlockCondition: .and([
                          .completeChapter(chapterId: "ch6", count: 30),
                          .rank(.jinshi)
                      ]),
                      reward: nil),
    ]
}

// MARK: - 章节运行时数据

/// 章节运行时状态（每次打开章节列表时计算，不持久化）
struct PuzzleChapter: Identifiable {
    let id: String
    let config: ChapterConfig
    let puzzles: [Puzzle]              // 本章包含的残局列表
    let completedCount: Int            // 已通关数（从 PuzzleProgress 推导）
    var isUnlocked: Bool               // 是否已解锁（两遍构建中 Pass 2 修改）
    let unlockDescription: String      // 解锁条件描述（未解锁时显示）

    var title: String { L10n.shared.t(config.titleKey) }
    var subtitle: String { L10n.shared.t(config.subtitleKey) }
    var totalCount: Int { puzzles.count }
    var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }
    var isComplete: Bool {
        completedCount >= totalCount
    }
}
