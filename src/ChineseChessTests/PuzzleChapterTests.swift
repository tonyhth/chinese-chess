import Testing
import Foundation
@testable import ChineseChess

// MARK: - PuzzleChapter 模块单元测试

@Suite("PuzzleChapter 模块测试")
struct PuzzleChapterTests {

    // MARK: - 1. PuzzleChapter 数据模型测试

    @Test("PuzzleChapter.progress 计算正确")
    func testProgressCalculation() {
        let config = ChapterConfig(
            id: "test",
            titleKey: "chapter.ch1.title",
            subtitleKey: "chapter.ch1.subtitle",
            globalStart: 0,
            globalEnd: 10,
            unlockCondition: .none,
            reward: nil
        )
        let puzzles = (0..<10).map { i in
            Puzzle(
                id: "p\(i)", name: "test\(i)", category: "test",
                difficulty: 1, stars: 1, description: "desc",
                playerSide: "red", initialFEN: "fen",
                solution: [], hints: nil, maxMoves: 5
            )
        }
        // 5/10 完成 → progress = 0.5
        let chapter = PuzzleChapter(
            id: "test", config: config,
            puzzles: puzzles, completedCount: 5,
            isUnlocked: true, unlockDescription: ""
        )
        #expect(chapter.progress == 0.5)
    }

    @Test("PuzzleChapter.isComplete: completedCount >= totalCount 时为 true")
    func testIsComplete() {
        let config = ChapterConfig(
            id: "test", titleKey: "t", subtitleKey: "s",
            globalStart: 0, globalEnd: 3,
            unlockCondition: .none, reward: nil
        )
        let puzzles = (0..<3).map { i in
            Puzzle(id: "p\(i)", name: "n\(i)", category: "c",
                   difficulty: 1, stars: 1, description: "d",
                   playerSide: "red", initialFEN: "f",
                   solution: [], hints: nil, maxMoves: 5)
        }
        let complete = PuzzleChapter(id: "test", config: config, puzzles: puzzles,
                                     completedCount: 3, isUnlocked: true, unlockDescription: "")
        #expect(complete.isComplete)

        let incomplete = PuzzleChapter(id: "test", config: config, puzzles: puzzles,
                                       completedCount: 2, isUnlocked: true, unlockDescription: "")
        #expect(!incomplete.isComplete)
    }

    @Test("PuzzleChapter.progress: 空章节不除零")
    func testEmptyChapterProgress() {
        let config = ChapterConfig(
            id: "empty", titleKey: "t", subtitleKey: "s",
            globalStart: 0, globalEnd: 0,
            unlockCondition: .none, reward: nil
        )
        let chapter = PuzzleChapter(id: "empty", config: config, puzzles: [],
                                    completedCount: 0, isUnlocked: true, unlockDescription: "")
        #expect(chapter.progress == 0)
        #expect(chapter.totalCount == 0)
    }

    // MARK: - 2. ChapterConfig 测试

    @Test("ChapterConfig.displayNumber 从 id 正确提取")
    func testDisplayNumber() {
        let ch3 = ChapterConfig(id: "ch3", titleKey: "t", subtitleKey: "s",
                                globalStart: 0, globalEnd: 10,
                                unlockCondition: .none, reward: nil)
        #expect(ch3.displayNumber == 3)
    }

    @Test("ChapterDefinitions 包含 7 个章节")
    func testSevenChapters() {
        #expect(ChapterDefinitions.chapters.count == 7)
    }

    @Test("ChapterDefinitions 章节范围连续且覆盖所有残局")
    func testChapterRangesContinuous() {
        let chapters = ChapterDefinitions.chapters
        // 第一个章节从 0 开始
        #expect(chapters[0].globalStart == 0)
        // 范围连续：每个章节的 globalStart = 前一个的 globalEnd
        for i in 1..<chapters.count {
            #expect(chapters[i].globalStart == chapters[i - 1].globalEnd,
                    "ch\(i+1) start 应等于 ch\(i) end")
        }
    }

    @Test("ChapterDefinitions id 顺序为 ch1...ch7")
    func testChapterIds() {
        let ids = ChapterDefinitions.chapters.map(\.id)
        #expect(ids == ["ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7"])
    }

    // MARK: - 3. ChapterUnlockCondition 测试

    @Test(".none 条件始终解锁")
    func testUnlockNone() {
        // ch1 的条件是 .none，应始终解锁
        let ch1Config = ChapterDefinitions.chapters[0]
        #expect(isNoneCondition(ch1Config.unlockCondition))
    }

    @Test("ChapterUnlockCondition 级联链正确")
    func testUnlockChain() {
        let chapters = ChapterDefinitions.chapters
        // ch1 → .none（始终解锁）
        // ch2 → .or([completeChapter(ch1, 10), rank(.scholar)])
        // ch3 → .or([completeChapter(ch2, 20), rank(.juren)])
        // ...
        // ch7 → .and([completeChapter(ch6, 30), rank(.jinshi)])

        // 验证奖励链：ch1→ch2, ch2→ch3, ..., ch6→ch7, ch7→nil
        for i in 0..<6 {
            if case .unlockChapter(let targetId) = chapters[i].reward {
                #expect(targetId == chapters[i + 1].id,
                        "ch\(i+1) 奖励应解锁 \(chapters[i + 1].id)")
            } else {
                Issue.record("ch\(i+1) 奖励应为 .unlockChapter")
            }
        }
        #expect(chapters[6].reward == nil, "ch7 无后续奖励")
    }

    @Test("ChapterReward 枚举可正确匹配")
    func testChapterRewardMatching() {
        let reward = ChapterReward.unlockChapter(chapterId: "ch2")
        if case .unlockChapter(let id) = reward {
            #expect(id == "ch2")
        } else {
            Issue.record("应为 .unlockChapter")
        }

        let titleReward = ChapterReward.title("大师")
        if case .title(let t) = titleReward {
            #expect(t == "大师")
        } else {
            Issue.record("应为 .title")
        }
    }

    // MARK: - 4. Puzzle 数据模型测试

    @Test("Puzzle.effectiveMode: 有 solution → guided")
    func testPuzzleEffectiveModeGuided() {
        let puzzle = Puzzle(id: "t1", name: "test", category: "c",
                           difficulty: 1, stars: 1, description: "d",
                           playerSide: "red", initialFEN: "f",
                           solution: ["h2e2"], hints: nil, maxMoves: 5)
        #expect(puzzle.effectiveMode == .guided)
    }

    @Test("Puzzle.effectiveMode: 无 solution + freePlay → freePlay")
    func testPuzzleEffectiveModeFreePlay() {
        var puzzle = Puzzle(id: "t1", name: "test", category: "c",
                           difficulty: 1, stars: 1, description: "d",
                           playerSide: "red", initialFEN: "f",
                           solution: [], hints: nil, maxMoves: 5)
        puzzle.solutionMode = .freePlay
        #expect(puzzle.effectiveMode == .freePlay)
    }

    @Test("Puzzle.side 从 playerSide 正确映射")
    func testPuzzleSide() {
        let redPuzzle = Puzzle(id: "t1", name: "test", category: "c",
                              difficulty: 1, stars: 1, description: "d",
                              playerSide: "red", initialFEN: "f",
                              solution: [], hints: nil, maxMoves: 5)
        #expect(redPuzzle.side == .red)

        let blackPuzzle = Puzzle(id: "t2", name: "test", category: "c",
                                difficulty: 1, stars: 1, description: "d",
                                playerSide: "black", initialFEN: "f",
                                solution: [], hints: nil, maxMoves: 5)
        #expect(blackPuzzle.side == .black)
    }

    @Test("Puzzle: Codable 往返序列化正确")
    func testPuzzleCodable() throws {
        let puzzle = Puzzle(id: "c1p1", name: "测试残局", category: "杀法",
                           difficulty: 2, stars: 3, description: "红先胜",
                           playerSide: "red", initialFEN: "rnbakabnr/9/9/9/9/9/9/9/9/4K4 w - - 0 1",
                           solution: ["h2e2", "h9g7"], hints: ["注意中路"],
                           maxMoves: 10, source: "橘中秘",
                           solutionType: "checkmate", endDescription: "绝杀！",
                           solutionMode: .guided, subcategory: "中等")
        let data = try JSONEncoder().encode(puzzle)
        let decoded = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(decoded.id == puzzle.id)
        #expect(decoded.name == puzzle.name)
        #expect(decoded.stars == puzzle.stars)
        #expect(decoded.solution == puzzle.solution)
        #expect(decoded.source == puzzle.source)
        #expect(decoded.solutionType == puzzle.solutionType)
        #expect(decoded.solutionMode == puzzle.solutionMode)
        #expect(decoded.subcategory == puzzle.subcategory)
    }

    @Test("Puzzle: 向后兼容解码（缺少新字段时使用默认值）")
    func testPuzzleBackwardCompat() throws {
        // 最小 JSON，缺少 solutionType、solutionMode、subcategory
        let json = """
        {
            "id": "old1",
            "name": "旧残局",
            "category": "test",
            "difficulty": 1,
            "stars": 2,
            "description": "desc",
            "playerSide": "red",
            "initialFEN": "fen",
            "solution": [],
            "maxMoves": 5
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(decoded.id == "old1")
        #expect(decoded.solutionType == "checkmate", "默认 solutionType 应为 checkmate")
        #expect(decoded.solutionMode == .guided, "默认 solutionMode 应为 guided")
        #expect(decoded.subcategory == nil)
        #expect(decoded.source == nil)
    }

    // MARK: - 5. PuzzleProgress 测试

    @Test("PuzzleProgress: 基本属性正确")
    func testPuzzleProgress() {
        let progress = PuzzleProgress(
            puzzleId: "p1",
            isCompleted: true,
            bestMoves: 8,
            completedAt: Date(),
            bestRating: 3
        )
        #expect(progress.puzzleId == "p1")
        #expect(progress.isCompleted)
        #expect(progress.bestMoves == 8)
        #expect(progress.bestRating == 3)
    }

    @Test("PuzzleProgress: 未完成状态")
    func testPuzzleProgressIncomplete() {
        let progress = PuzzleProgress(
            puzzleId: "p2",
            isCompleted: false,
            bestMoves: nil,
            completedAt: nil,
            bestRating: nil
        )
        #expect(!progress.isCompleted)
        #expect(progress.bestMoves == nil)
    }

    // MARK: - 辅助方法

    private func isNoneCondition(_ condition: ChapterUnlockCondition) -> Bool {
        if case .none = condition { return true }
        return false
    }
}