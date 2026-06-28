import Foundation

// MARK: - 章节管理器

/// 章节管理器：按全局排序把 551 局分配到 7 个章节，并计算解锁状态。
/// 两遍构建：Pass 1 算 puzzles + completedCount，Pass 2 算 isUnlocked。
final class ChapterStore: ObservableObject {
    static let shared = ChapterStore()

    @Published private(set) var chapters: [PuzzleChapter] = []

    private init() {
        rebuildChapters()
    }

    // MARK: - 全局排序列表

    /// 全局排序后的 puzzle 列表（按 stars 升序 + id 升序）
    private var globalSorted: [Puzzle] {
        PuzzleStore.shared.puzzles.sorted { a, b in
            if a.stars != b.stars { return a.stars < b.stars }
            return a.id < b.id
        }
    }

    // MARK: - 两遍构建

    func rebuildChapters() {
        let sorted = globalSorted
        assert(!sorted.isEmpty, "ChapterStore: PuzzleStore has no puzzles loaded")
        let progress = PuzzleStore.shared.progressMap

        // Pass 1: 构建 puzzle 列表 + completedCount（isUnlocked 暂设 false）
        var built: [PuzzleChapter] = ChapterDefinitions.chapters.map { config in
            let startIndex = config.globalStart
            let endIndex = min(config.globalEnd, globalSorted.count)
            let puzzles = Array(sorted[startIndex..<endIndex])
            let completedCount = puzzles.filter { progress[$0.id]?.isCompleted == true }.count
            return PuzzleChapter(
                id: config.id,
                config: config,
                puzzles: puzzles,
                completedCount: completedCount,
                isUnlocked: false,
                unlockDescription: unlockDescription(for: config.unlockCondition)
            )
        }

        // Pass 2: 根据已构建的 completedCount 计算解锁状态
        let profile = PlayerProfileStore.shared.profile
        for i in built.indices {
            built[i].isUnlocked = checkUnlock(
                built[i].config.unlockCondition,
                profile: profile,
                builtChapters: built
            )
        }
        chapters = built
    }

    // MARK: - 解锁检查

    private func checkUnlock(
        _ condition: ChapterUnlockCondition,
        profile: PlayerProfile,
        builtChapters: [PuzzleChapter]
    ) -> Bool {
        switch condition {
        case .none:
            return true
        case .completeChapter(let chId, let count):
            let chapter = builtChapters.first { $0.id == chId }
            return (chapter?.completedCount ?? 0) >= count
        case .rank(let rank):
            // Q4 P2: bonusChapter7EarlyUnlock — day70 奖励，跳过段位检查
            if profile.bonusChapter7EarlyUnlock {
                return true
            }
            return profile.rank >= rank
        case .and(let conditions):
            return conditions.allSatisfy { checkUnlock($0, profile: profile, builtChapters: builtChapters) }
        case .or(let conditions):
            return conditions.contains { checkUnlock($0, profile: profile, builtChapters: builtChapters) }
        }
    }

    private func unlockDescription(for condition: ChapterUnlockCondition) -> String {
        let l = L10n.shared
        switch condition {
        case .none:
            return ""
        case .completeChapter(let chId, let count):
            let chapterTitle = ChapterDefinitions.chapters.first { $0.id == chId }?.titleKey ?? chId
            return String(format: l.t("chapter.unlock.completePrev"),
                          l.t(chapterTitle), count)
        case .rank(let rank):
            return String(format: l.t("chapter.unlock.rank"), rank.localizedTitle)
        case .and(let conditions):
            return conditions.map { unlockDescription(for: $0) }.joined(separator: " + ")
        case .or(let conditions):
            return conditions.map { unlockDescription(for: $0) }.joined(separator: " / ")
        }
    }

    // MARK: - 查询

    func chapter(byId id: String) -> PuzzleChapter? {
        chapters.first { $0.id == id }
    }

    /// 刷新章节状态（残局完成、段位升级后调用）
    func refresh() {
        rebuildChapters()
    }

    /// 总通关数
    var totalCompleted: Int {
        chapters.reduce(0) { $0 + $1.completedCount }
    }

    /// 总残局数
    var totalPuzzles: Int {
        chapters.reduce(0) { $0 + $1.totalCount }
    }
}
