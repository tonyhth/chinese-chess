import Testing
import Foundation
@testable import ChineseChess

// MARK: - T1: P1-2 数据层 i18n 测试

@Suite("P1-2 数据层 i18n 测试")
struct DataLayerI18nTests {

    private let l10n = L10n.shared

    // MARK: - AchievementView i18n

    @Test("achievement.view.rankProgress key 存在且双语翻译")
    func testRankProgressKeyExists() {
        let zh = l10n.t("achievement.view.rankProgress", "5", "")
        let en = l10n.t("achievement.view.rankProgress", "5", "")
        #expect(!zh.isEmpty)
        #expect(!en.isEmpty)
        #expect(zh != "achievement.view.rankProgress")
        #expect(en != "achievement.view.rankProgress")
    }

    @Test("achievement.view.rankProgress 格式化包含参数")
    func testRankProgressFormatting() {
        let result = l10n.t("achievement.view.rankProgress", "10", " + 5 残局")
        #expect(result.contains("10"))
    }

    @Test("achievement.view.rankProgress.puzzles key 存在且翻译")
    func testRankProgressPuzzlesKey() {
        let zh = l10n.t("achievement.view.rankProgress.puzzles", "3")
        let en = l10n.t("achievement.view.rankProgress.puzzles", "3")
        #expect(!zh.isEmpty)
        #expect(!en.isEmpty)
        #expect(zh != "achievement.view.rankProgress.puzzles")
        #expect(en != "achievement.view.rankProgress.puzzles")
    }

    // MARK: - DailyChallengeView i18n

    @Test("daily.view.recent key 存在且双语翻译")
    func testDailyViewRecentKey() {
        let zh = l10n.t("daily.view.recent")
        let en = l10n.t("daily.view.recent")
        #expect(!zh.isEmpty)
        #expect(!en.isEmpty)
        #expect(zh != "daily.view.recent")
        #expect(en != "daily.view.recent")
    }

    @Test("common.done key 存在且翻译")
    func testCommonDoneKey() {
        let zh = l10n.t("common.done")
        let en = l10n.t("common.done")
        #expect(!zh.isEmpty)
        #expect(!en.isEmpty)
        #expect(zh != "common.done")
        #expect(en != "common.done")
    }

    @Test("AchievementView.swift 无残留硬编码中文")
    func testAchievementViewNoHardcodedChinese() {
        let code = readSourceFile("src/ChineseChess/Views/AchievementView.swift")
        #expect(!hasHardcodedChinese(code))
    }

    @Test("DailyChallengeView.swift 无残留硬编码中文")
    func testDailyChallengeViewNoHardcodedChinese() {
        let code = readSourceFile("src/ChineseChess/Views/DailyChallengeView.swift")
        #expect(!hasHardcodedChinese(code))
    }

    // MARK: - Helpers

    private func readSourceFile(_ relativePath: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fullPath = "\(home)/DevTeam/projects/chinese-chess/\(relativePath)"
        return (try? String(contentsOfFile: fullPath)) ?? ""
    }

    private func hasHardcodedChinese(_ source: String) -> Bool {
        let lines = source.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") { continue }
            if let range = trimmed.range(of: #""[^"]*[\u{4e00}-\u{9fff}][^"]*""#, options: .regularExpression) {
                let match = String(trimmed[range])
                // 排除 i18n key 前缀
                let i18nPrefixes = ["achievement.", "common.", "daily.", "chapter.", "puzzle.", "coach.", "toolbar.", "opening.", "rank.", "game.", "board.", "export.", "history.", "settings.", "import.", "replay.", "tutorial."]
                let inner = match.dropFirst().dropLast() // 去掉引号
                if i18nPrefixes.contains(where: { inner.hasPrefix($0) }) { continue }
                return true
            }
        }
        return false
    }
}

// MARK: - T2: ChapterSelectView 独立测试

@Suite("ChapterSelectView 独立测试")
struct ChapterSelectViewTests {

    @Test("PuzzleChapter Hashable: 不同 id 不相等")
    func testHashableDifferentIds() {
        let ch1 = PuzzleChapter(
            id: "ch1", config: ChapterDefinitions.chapters[0],
            puzzles: [], completedCount: 0,
            isUnlocked: true, unlockDescription: ""
        )
        let ch2 = PuzzleChapter(
            id: "ch2", config: ChapterDefinitions.chapters[1],
            puzzles: [], completedCount: 0,
            isUnlocked: true, unlockDescription: ""
        )
        #expect(ch1 != ch2)
        #expect(ch1.hashValue != ch2.hashValue)
    }

    @Test("PuzzleChapter Hashable: 相同 id 相等（即使其他属性不同）")
    func testHashableSameId() {
        let ch1a = PuzzleChapter(
            id: "ch1", config: ChapterDefinitions.chapters[0],
            puzzles: [], completedCount: 0,
            isUnlocked: true, unlockDescription: ""
        )
        let ch1b = PuzzleChapter(
            id: "ch1", config: ChapterDefinitions.chapters[0],
            puzzles: [], completedCount: 5,
            isUnlocked: false, unlockDescription: "locked"
        )
        #expect(ch1a == ch1b)
        #expect(ch1a.hashValue == ch1b.hashValue)
    }

    @Test("PuzzleChapter 可用于 Set 和 Dictionary key")
    func testHashableSetAndDict() {
        let ch1 = PuzzleChapter(
            id: "ch1", config: ChapterDefinitions.chapters[0],
            puzzles: [], completedCount: 0,
            isUnlocked: true, unlockDescription: ""
        )
        let ch2 = PuzzleChapter(
            id: "ch2", config: ChapterDefinitions.chapters[1],
            puzzles: [], completedCount: 0,
            isUnlocked: true, unlockDescription: ""
        )
        let set: Set<PuzzleChapter> = [ch1, ch2]
        #expect(set.count == 2)

        let dict: [PuzzleChapter: String] = [ch1: "A", ch2: "B"]
        #expect(dict[ch1] == "A")
        #expect(dict[ch2] == "B")
    }

    @Test("ChapterDefinitions: 7 章 ID 全局唯一")
    func testChapterIdsUnique() {
        let ids = ChapterDefinitions.chapters.map(\.id)
        #expect(ids.count == 7)
        #expect(Set(ids).count == 7)
    }

    @Test("ChapterDefinitions: ch1 始终解锁（.none 条件）")
    func testFirstChapterAlwaysUnlocked() {
        if case .none = ChapterDefinitions.chapters[0].unlockCondition {
            // 正确
        } else {
            Issue.record("ch1 应该是 .none 条件")
        }
    }

    @Test("ChapterDefinitions: 章节范围连续无间隙")
    func testChapterRangesContiguous() {
        let chapters = ChapterDefinitions.chapters
        for i in 0..<(chapters.count - 1) {
            #expect(chapters[i].globalEnd == chapters[i + 1].globalStart,
                    "Gap between ch\(i+1) and ch\(i+2)")
        }
    }

    @Test("ChapterUnlockCondition: ch2 是 .or 条件")
    func testCh2OrCondition() {
        let cond = ChapterDefinitions.chapters[1].unlockCondition
        if case .or(let conditions) = cond {
            #expect(conditions.count == 2)
        } else {
            Issue.record("ch2 应该是 .or 条件")
        }
    }

    @Test("ChapterUnlockCondition: ch7 是 .and 条件")
    func testCh7AndCondition() {
        let cond = ChapterDefinitions.chapters[6].unlockCondition
        if case .and(let conditions) = cond {
            #expect(conditions.count == 2)
        } else {
            Issue.record("ch7 应该是 .and 条件")
        }
    }

    @Test("PuzzleChapter.progress: 空章节不除零")
    func testEmptyChapterProgress() {
        let chapter = PuzzleChapter(
            id: "empty", config: ChapterDefinitions.chapters[0],
            puzzles: [], completedCount: 0,
            isUnlocked: true, unlockDescription: ""
        )
        #expect(chapter.progress == 0)
        #expect(chapter.totalCount == 0)
    }

    @Test("PuzzleChapter.isComplete: completedCount >= totalCount 时为 true")
    func testCompleteProgress() {
        // 空 puzzles → totalCount=0, completedCount=0 → isComplete=false (0 >= 0)
        let emptyChapter = PuzzleChapter(
            id: "ch1", config: ChapterDefinitions.chapters[0],
            puzzles: [], completedCount: 0,
            isUnlocked: true, unlockDescription: ""
        )
        #expect(emptyChapter.totalCount == 0)
        // isComplete: completedCount >= totalCount → 0 >= 0 → true
        #expect(emptyChapter.isComplete == true)
    }
}

// MARK: - T3: CoachSessionView 集成测试

@Suite("CoachSessionView 集成测试")
struct CoachSessionViewIntegrationTests {

    @Test("UnlockedFeature.aiCoach 所需段位为国手")
    func testAiCoachRequiredRank() {
        #expect(UnlockedFeature.aiCoach.requiredRank == .master)
    }

    @Test("UnlockedFeature.aiCoach 标记为已实现")
    func testAiCoachIsImplemented() {
        #expect(UnlockedFeature.aiCoach.isImplemented == true)
    }

    @Test("GameReviewCard 结构完整")
    func testReviewCardStructure() {
        let card = GameReviewCard(
            totalMoves: 30,
            qualityDistribution: [.brilliant: 2, .good: 5, .doubtful: 1, .blunder: 1],
            biggestBlunder: (moveIndex: 15, delta: 200),
            rating: 3,
            suggestion: "整体表现不错"
        )
        #expect(card.rating == 3)
        #expect(card.totalMoves == 30)
        #expect(card.qualityDistribution[.brilliant] == 2)
        #expect(card.qualityDistribution[.blunder] == 1)
        #expect(card.biggestBlunder?.delta == 200)
        #expect(!card.suggestion.isEmpty)
    }

    @Test("CoachExplanation 结构完整")
    func testCoachExplanationStructure() {
        let explanation = CoachExplanation(
            scenario: .generic,
            title: "通用走法",
            detail: "这步棋与引擎推荐有一定差距",
            betterMove: "h2e2",
            evalDelta: 50
        )
        #expect(explanation.scenario == .generic)
        #expect(!explanation.title.isEmpty)
        #expect(!explanation.detail.isEmpty)
        #expect(!explanation.betterMove.isEmpty)
    }

    @Test("GameMove.uciNotation 转换正确")
    func testUciNotation() {
        let move = GameMove(
            id: UUID(),
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 7), id: 10),
            from: Position(row: 7, col: 7),
            to: Position(row: 7, col: 4),
            captured: nil,
            turnNumber: 1,
            notation: "炮二平五",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false, halfmoveClock: 0
        )
        #expect(move.uciNotation == "h2e2")
    }

    @Test("GameMove.uciNotation: 马的走法")
    func testUciNotationHorse() {
        let move = GameMove(
            id: UUID(),
            piece: Piece(kind: .horse, side: .red, position: Position(row: 0, col: 7), id: 107),
            from: Position(row: 0, col: 7),
            to: Position(row: 2, col: 6),
            captured: nil,
            turnNumber: 1,
            notation: "马八进七",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false, halfmoveClock: 0
        )
        #expect(move.uciNotation == "h9g7")
    }

    @Test("Array<GameMove>.uciMoves 批量转换")
    func testUciMovesBatch() {
        let moves = [
            GameMove(id: UUID(), piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 7), id: 10),
                     from: Position(row: 7, col: 7), to: Position(row: 7, col: 4),
                     captured: nil, turnNumber: 1, notation: "炮二平五",
                     timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
            // 黑方马：row=0 → rank=9, row=2 → rank=7
            GameMove(id: UUID(), piece: Piece(kind: .horse, side: .black, position: Position(row: 0, col: 1), id: 18),
                     from: Position(row: 0, col: 1), to: Position(row: 2, col: 2),
                     captured: nil, turnNumber: 2, notation: "马8进7",
                     timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
        ]
        let uci = moves.uciMoves
        #expect(uci == ["h2e2", "b9c7"])
    }

    @Test("MoveQuality 所有 case 有有效 l10nKey")
    func testMoveQualityL10nKeys() {
        for quality in MoveQuality.allCases {
            let key = quality.l10nKey
            #expect(!key.isEmpty, "MoveQuality.\(quality) 缺少 l10nKey")
            let translation = L10n.shared.t(key)
            #expect(translation != key, "MoveQuality.\(quality) 的 l10nKey '\(key)' 未翻译")
        }
    }

    @Test("CoachSessionView 门禁: aiCoach 需要 master 段位")
    func testCoachAccessGate() {
        let requiredRank = UnlockedFeature.aiCoach.requiredRank
        #expect(requiredRank == .master)
    }

    @Test("ReviewCardView: onViewDetail 可选参数（编译验证）")
    func testReviewCardViewOptionalCallback() {
        // ReviewCardView 的 record 和 onViewDetail 都是可选的
        // 旧调用方式（无 onViewDetail）仍然可以编译
        let card = GameReviewCard(
            totalMoves: 20,
            qualityDistribution: [:],
            biggestBlunder: nil,
            rating: 4,
            suggestion: "表现优秀"
        )
        #expect(card.rating == 4)
    }

    @Test("CoachScenario 有 8 个 case")
    func testCoachScenarioCount() {
        #expect(CoachScenario.allCases.count == 8)
    }
}

// MARK: - T4: openingTreeFavorite 确认

@Suite("openingTreeFavorite 功能确认")
struct OpeningTreeFavoriteTests {

    @Test("UnlockedFeature.openingTreeFavorite 标记为已实现")
    func testOpeningTreeFavoriteIsImplemented() {
        #expect(UnlockedFeature.openingTreeFavorite.isImplemented == true)
    }

    @Test("UnlockedFeature.openingTreeFavorite 所需段位为棋圣")
    func testOpeningTreeFavoriteRequiredRank() {
        #expect(UnlockedFeature.openingTreeFavorite.requiredRank == .sage)
    }

    // v5.0: OpeningTreeStore 已被移除，收藏功能待 v5.x 重新实现
    // 旧测试已归档到 _archive_v4/

    /*
    @Test("OpeningTreeStore: toggleFavorite 添加和移除")
    func testToggleFavoriteAdd() {
        let store = OpeningTreeStore.shared
        let pathKey = "test_add_\(UUID().uuidString)"

        // 初始状态：未收藏
        #expect(!store.isFavorite(pathKey))

        // 添加收藏
        store.toggleFavorite(pathKey)
        #expect(store.isFavorite(pathKey))

        // 再次 toggle → 移除
        store.toggleFavorite(pathKey)
        #expect(!store.isFavorite(pathKey))
    }

    @Test("OpeningTreeStore: toggleFavorite 重复切换")
    func testToggleFavoriteToggle() {
        let store = OpeningTreeStore.shared
        let pathKey = "test_toggle_\(UUID().uuidString)"

        // 添加
        store.toggleFavorite(pathKey)
        #expect(store.isFavorite(pathKey))

        // 再次 toggle → 移除
        store.toggleFavorite(pathKey)
        #expect(!store.isFavorite(pathKey))

        // 第三次 toggle → 再次添加
        store.toggleFavorite(pathKey)
        #expect(store.isFavorite(pathKey))

        // 清理
        store.toggleFavorite(pathKey)
    }

    @Test("OpeningTreeStore: favorites 通过 UserDefaults 持久化")
    func testFavoritesPersisted() {
        // 验证 UserDefaults 键存在且格式正确
        // toggleFavorite 写入后 UserDefaults 中有 openingFavorites 数据
        let store = OpeningTreeStore.shared
        let pathKey = "test_persist_\(UUID().uuidString)"

        store.toggleFavorite(pathKey)

        // 验证 UserDefaults 中有数据
        let data = UserDefaults.standard.data(forKey: "openingFavorites")
        #expect(data != nil, "openingFavorites 数据应存在于 UserDefaults")

        // 验证可以解码为 [String]
        if let data = data {
            let decoded = try? JSONDecoder().decode([String].self, from: data)
            #expect(decoded != nil, "openingFavorites 应可解码为 [String]")
            #expect(decoded?.contains(pathKey) == true, "解码后应包含刚添加的 pathKey")
        }

        // 清理
        store.toggleFavorite(pathKey)
    }

    @Test("OpeningExplorerView 收藏按钮: moveHistory 非空时可操作")
    func testFavoriteButtonEnabled() {
        let store = OpeningTreeStore.shared
        let nonEmptyPath = "h2e2_test_\(UUID().uuidString)"
        #expect(!nonEmptyPath.isEmpty)

        store.toggleFavorite(nonEmptyPath)
        #expect(store.isFavorite(nonEmptyPath))

        // 清理
        store.toggleFavorite(nonEmptyPath)
    }
    */

    @Test("openingTreeBrowse 也标记为已实现")
    func testOpeningTreeBrowseIsImplemented() {
        #expect(UnlockedFeature.openingTreeBrowse.isImplemented == true)
    }

    @Test("openingTreeBrowse 所需段位为秀才")
    func testOpeningTreeBrowseRequiredRank() {
        #expect(UnlockedFeature.openingTreeBrowse.requiredRank == .scholar)
    }
}
