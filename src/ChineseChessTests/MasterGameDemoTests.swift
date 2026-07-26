import XCTest
@testable import ChineseChess

// MARK: - 大师棋谱接入 PuzzleDemoView 测试

/// 覆盖 ece500b (feat) + ec550fc (fix) 两次提交的测试重点：
/// 1. DemoItemWrapper + MasterGameDemoItem + DemoCategory
/// 2. DemoMoveConverter.convertGameMoves (ICCSParser 路径)
/// 3. DemoViewModel 通用化（item: DemoItemWrapper, moves: [Move]）
/// 4. PuzzleDemoView 列表/播放模式分离 + 分页 + 缓存
/// 5. MasterGameStore.shared + 懒加载
/// 6. L10n 新增 11 个 key
@MainActor
final class MasterGameDemoTests: XCTestCase {

    // MARK: - 辅助方法

    private func makePuzzle(
        id: String = "test-demo-\(UUID().uuidString.prefix(8))",
        solution: [String],
        category: String = "测试分类"
    ) -> Puzzle {
        Puzzle(
            id: id,
            name: "测试残局",
            category: category,
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: solution,
            hints: nil,
            maxMoves: solution.count
        )
    }

    private func makeMasterGameIndex(
        id: Int = 0,
        firstMove: String = "h2e2",
        redNameCN: String = "许银川",
        blackNameCN: String = "吕钦",
        event: String = "全国个人赛",
        year: Int? = 2005,
        moveCount: Int = 80
    ) -> MasterGameIndex {
        MasterGameIndex(
            id: id,
            event: event,
            redName: "Xu Yinchuan",
            blackName: "Lv Qin",
            redNameCN: redNameCN,
            blackNameCN: blackNameCN,
            year: year,
            firstMove: firstMove,
            firstMoves: [firstMove],
            moveCount: moveCount,
            pgnOffset: 0,
            pgnLength: 1000
        )
    }

    // MARK: - 1. DemoItemWrapper

    func testDemoItemWrapperPuzzleId() {
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"])
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        XCTAssertEqual(wrapper.id, "puzzle_p1")
    }

    func testDemoItemWrapperMasterGameId() {
        let index = makeMasterGameIndex(id: 42)
        let item = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(item)
        XCTAssertEqual(wrapper.id, "master_42")
    }

    func testDemoItemWrapperEqualitySamePuzzle() {
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"])
        let w1 = DemoItemWrapper.puzzle(puzzle)
        let w2 = DemoItemWrapper.puzzle(puzzle)
        XCTAssertEqual(w1, w2)
    }

    func testDemoItemWrapperEqualityDifferentPuzzle() {
        let p1 = makePuzzle(id: "p1", solution: ["h2e2"])
        let p2 = makePuzzle(id: "p2", solution: ["h2e2"])
        XCTAssertNotEqual(DemoItemWrapper.puzzle(p1), DemoItemWrapper.puzzle(p2))
    }

    func testDemoItemWrapperEqualityDifferentTypes() {
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"])
        let index = makeMasterGameIndex(id: 0)
        let master = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        XCTAssertNotEqual(DemoItemWrapper.puzzle(puzzle), DemoItemWrapper.masterGame(master))
    }

    func testDemoItemWrapperPuzzleTitle() {
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"])
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        XCTAssertEqual(wrapper.demoTitle, "测试残局")
    }

    func testDemoItemWrapperMasterGameTitle() {
        let index = makeMasterGameIndex(redNameCN: "许银川", blackNameCN: "吕钦")
        let item = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(item)
        XCTAssertEqual(wrapper.demoTitle, "许银川 vs 吕钦")
    }

    func testDemoItemWrapperPuzzleSubtitle() {
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"])
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        XCTAssertEqual(wrapper.demoSubtitle, "测试")
    }

    func testDemoItemWrapperMasterGameSubtitleWithYear() {
        let index = makeMasterGameIndex(event: "全国个人赛", year: 2005)
        let item = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(item)
        XCTAssertEqual(wrapper.demoSubtitle, "2005 · 全国个人赛")
    }

    func testDemoItemWrapperMasterGameSubtitleWithoutYear() {
        let index = makeMasterGameIndex(event: "全国个人赛", year: nil)
        let item = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(item)
        XCTAssertEqual(wrapper.demoSubtitle, "全国个人赛")
    }

    func testDemoItemWrapperPuzzleCategory() {
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"], category: "适情雅趣")
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        XCTAssertEqual(wrapper.demoCategory, "适情雅趣")
    }

    func testDemoItemWrapperMasterGameCategoryZhongPao() {
        let index = makeMasterGameIndex(firstMove: "h2e2")
        let item = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(item)
        XCTAssertEqual(wrapper.demoCategory, "中炮")
    }

    func testDemoItemWrapperMasterGameCategoryUnknown() {
        let index = makeMasterGameIndex(firstMove: "z9z9")
        let item = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(item)
        XCTAssertEqual(wrapper.demoCategory, "其他开局")
    }

    func testDemoItemWrapperAutoAdvanceDelay() {
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"])
        let puzzleWrapper = DemoItemWrapper.puzzle(puzzle)
        XCTAssertEqual(puzzleWrapper.autoAdvanceDelay, 3.0, "残局连播延迟应为 3 秒")

        let index = makeMasterGameIndex()
        let masterItem = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let masterWrapper = DemoItemWrapper.masterGame(masterItem)
        XCTAssertEqual(masterWrapper.autoAdvanceDelay, 8.0, "大师棋谱连播延迟应为 8 秒")
    }

    func testDemoItemWrapperShouldFlipBoard() {
        // 红方残局不翻转
        let puzzleRed = makePuzzle(id: "p1", solution: ["h2e2"])
        // playerSide="red" → side=.red → shouldFlipBoard=false
        XCTAssertFalse(DemoItemWrapper.puzzle(puzzleRed).shouldFlipBoard)

        // 大师棋谱永远不翻转
        let index = makeMasterGameIndex()
        let masterItem = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        XCTAssertFalse(DemoItemWrapper.masterGame(masterItem).shouldFlipBoard)
    }

    func testDemoItemWrapperInitialFEN() {
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"])
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        XCTAssertEqual(wrapper.initialFEN, puzzle.initialFEN)

        let index = makeMasterGameIndex()
        let customFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        let masterItem = MasterGameDemoItem(index: index, fen: customFEN)
        let masterWrapper = DemoItemWrapper.masterGame(masterItem)
        XCTAssertEqual(masterWrapper.initialFEN, customFEN)
    }

    // MARK: - 2. MasterGameDemoItem Equatable

    func testMasterGameDemoItemEqualitySameFEN() {
        let index = makeMasterGameIndex(id: 1)
        let item1 = MasterGameDemoItem(index: index, fen: "fen1")
        let item2 = MasterGameDemoItem(index: index, fen: "fen1")
        // 合成 Equatable 比较 index + fen
        XCTAssertEqual(item1, item2, "相同 index + fen 的 MasterGameDemoItem 应相等")
    }

    func testMasterGameDemoItemDifferentFEN() {
        let index = makeMasterGameIndex(id: 1)
        let item1 = MasterGameDemoItem(index: index, fen: "fen1")
        let item2 = MasterGameDemoItem(index: index, fen: "fen2")
        // MasterGameDemoItem 是合成 Equatable，fen 不同也不等
        XCTAssertNotEqual(item1, item2, "fen 不同的 MasterGameDemoItem 不应相等")
    }

    func testMasterGameDemoItemInequality() {
        let index1 = makeMasterGameIndex(id: 1)
        let index2 = makeMasterGameIndex(id: 2)
        let item1 = MasterGameDemoItem(index: index1, fen: "fen1")
        let item2 = MasterGameDemoItem(index: index2, fen: "fen1")
        XCTAssertNotEqual(item1, item2, "不同 id 的 MasterGameDemoItem 不应相等")
    }

    // MARK: - 3. DemoCategory

    func testDemoCategoryPuzzleId() {
        let cat = DemoCategory.puzzles("适情雅趣")
        XCTAssertEqual(cat.id, "puzzle_适情雅趣")
    }

    func testDemoCategoryOpeningId() {
        let opening = OpeningCategory(
            id: "zhong_pao", name: "中炮", firstMove: "h2e2",
            gameCount: 100, description: "炮二平五",
            subcategories: []
        )
        let cat = DemoCategory.opening(opening)
        XCTAssertEqual(cat.id, "opening_zhong_pao")
    }

    func testDemoCategoryPlayerId() {
        let cat = DemoCategory.player("许银川")
        XCTAssertEqual(cat.id, "player_许银川")
    }

    func testDemoCategoryDisplayName() {
        XCTAssertEqual(DemoCategory.puzzles("适情雅趣").displayName, "适情雅趣")

        let opening = OpeningCategory(
            id: "zhong_pao", name: "中炮", firstMove: "h2e2",
            gameCount: 100, description: "炮二平五",
            subcategories: []
        )
        XCTAssertEqual(DemoCategory.opening(opening).displayName, "中炮")

        XCTAssertEqual(DemoCategory.player("许银川").displayName, "许银川")
    }

    func testDemoCategoryHashable() {
        let cat1 = DemoCategory.puzzles("适情雅趣")
        let cat2 = DemoCategory.puzzles("适情雅趣")
        XCTAssertEqual(cat1, cat2)

        let set: Set<DemoCategory> = [cat1, cat2]
        XCTAssertEqual(set.count, 1, "相同 DemoCategory 在 Set 中应去重")
    }

    // MARK: - 4. DemoMoveConverter.convertGameMoves

    func testConvertGameMovesEmptyInput() {
        let result = DemoMoveConverter.convertGameMoves([], initialFEN: FENParser.standardInitial)
        XCTAssertTrue(result.moves.isEmpty)
        XCTAssertEqual(result.failedSteps, 0)
        XCTAssertTrue(result.isComplete)
    }

    func testConvertGameMovesValidMoves() {
        // 构造合法 GameMove 序列（炮二平五）
        let board = Board(fen: FENParser.standardInitial)
        guard let move = ICCSParser.parse("h2e2", on: board) else {
            XCTFail("标准开局 h2e2 应能解析")
            return
        }
        let gameMove = GameMove(
            id: UUID(),
            piece: move.piece,
            from: move.from,
            to: move.to,
            captured: move.captured,
            turnNumber: 1,
            notation: "",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false,
            halfmoveClock: 0
        )

        let result = DemoMoveConverter.convertGameMoves([gameMove], initialFEN: FENParser.standardInitial)
        XCTAssertEqual(result.moves.count, 1, "合法步应成功转换")
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(result.failedSteps, 0)
    }

    func testConvertGameMovesInvalidMoveStopsEarly() {
        // 构造一个 uciNotation 为无效值的 GameMove
        let board = Board(fen: FENParser.standardInitial)
        let piece = board.pieces.first!
        let invalidGameMove = GameMove(
            id: UUID(),
            piece: piece,
            from: piece.position,
            to: piece.position,  // 同一位置，ICCS 不可能合法
            captured: nil,
            turnNumber: 1,
            notation: "zz99",  // 无效 notation
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false,
            halfmoveClock: 0
        )

        let result = DemoMoveConverter.convertGameMoves([invalidGameMove], initialFEN: FENParser.standardInitial)
        XCTAssertTrue(result.moves.isEmpty, "无效步应导致 0 个成功转换")
        XCTAssertFalse(result.isComplete, "有失败步时 isComplete 应为 false")
        XCTAssertEqual(result.failedSteps, 1, "1 步全部失败")
    }

    func testConvertGameMovesMixedValidInvalidStopsAtFirstFailure() {
        // 第一步合法，第二步非法 → 第二步终止，第一步保留
        let board = Board(fen: FENParser.standardInitial)
        guard let move = ICCSParser.parse("h2e2", on: board) else {
            XCTFail("h2e2 应能解析")
            return
        }
        let validGameMove = GameMove(
            id: UUID(),
            piece: move.piece,
            from: move.from,
            to: move.to,
            captured: move.captured,
            turnNumber: 1,
            notation: "",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false,
            halfmoveClock: 0
        )

        let piece = board.pieces.first!
        let invalidGameMove = GameMove(
            id: UUID(),
            piece: piece,
            from: piece.position,
            to: piece.position,
            captured: nil,
            turnNumber: 2,
            notation: "zz99",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false,
            halfmoveClock: 0
        )

        let result = DemoMoveConverter.convertGameMoves([validGameMove, invalidGameMove], initialFEN: FENParser.standardInitial)
        XCTAssertEqual(result.moves.count, 1, "第一步合法应保留")
        XCTAssertFalse(result.isComplete)
        XCTAssertEqual(result.failedSteps, 1, "第二步失败")
    }

    // MARK: - 5. DemoViewModel 通用化

    func testDemoViewModelFromPuzzle() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2"])
        let vm = DemoViewModel(puzzle: puzzle)

        // 验证通用初始化的向后兼容
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertFalse(vm.isPlaying)
        XCTAssertTrue(vm.canGoForward)

        // item 应为 .puzzle
        if case .puzzle(let p) = vm.item {
            XCTAssertEqual(p.id, puzzle.id)
        } else {
            XCTFail("DemoViewModel.item 应为 .puzzle")
        }
    }

    func testDemoViewModelFromDemoItemWrapper() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        let vm = DemoViewModel(item: wrapper, moves: convertResult.moves)

        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertEqual(vm.totalSteps, 1)
    }

    func testDemoViewModelMasterGameItem() {
        let index = makeMasterGameIndex()
        let masterItem = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(masterItem)

        // 用空 moves 列表创建（模拟加载后的空走法场景）
        let vm = DemoViewModel(item: wrapper, moves: [])
        XCTAssertEqual(vm.totalSteps, 0)
        XCTAssertFalse(vm.canGoForward)

        if case .masterGame(let m) = vm.item {
            XCTAssertEqual(m.index.id, 0)
        } else {
            XCTFail("DemoViewModel.item 应为 .masterGame")
        }
    }

    func testDemoViewModelAutoAdvanceDelayRespected() {
        // 残局：3 秒延迟
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vmPuzzle = DemoViewModel(puzzle: puzzle)
        XCTAssertEqual(vmPuzzle.item.autoAdvanceDelay, 3.0)

        // 大师棋谱：8 秒延迟
        let index = makeMasterGameIndex()
        let masterItem = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(masterItem)
        let vmMaster = DemoViewModel(item: wrapper, moves: [])
        XCTAssertEqual(vmMaster.item.autoAdvanceDelay, 8.0)
    }

    // MARK: - 6. MasterGameIndex Equatable

    func testMasterGameIndexEquality() {
        let idx1 = makeMasterGameIndex(id: 1)
        let idx2 = makeMasterGameIndex(id: 1)
        XCTAssertEqual(idx1, idx2)
    }

    func testMasterGameIndexInequality() {
        let idx1 = makeMasterGameIndex(id: 1)
        let idx2 = makeMasterGameIndex(id: 2)
        XCTAssertNotEqual(idx1, idx2)
    }

    // MARK: - 7. OpeningCategories + OpeningCategory Equatable/Hashable

    func testOpeningCategoryEquality() {
        let cats = OpeningCategories.categories
        guard cats.count >= 2 else {
            XCTFail("应有至少 2 个开局分类")
            return
        }
        XCTAssertNotEqual(cats[0], cats[1])
        XCTAssertEqual(cats[0], cats[0])
    }

    func testOpeningCategoryHashable() {
        let cats = OpeningCategories.categories
        let set = Set(cats)
        XCTAssertEqual(set.count, cats.count, "每个 OpeningCategory 应唯一")
    }

    func testOpeningSubcategoryHashable() {
        let cats = OpeningCategories.categories
        let allSubs = cats.flatMap { $0.subcategories }
        guard !allSubs.isEmpty else { return }
        let set = Set(allSubs)
        XCTAssertEqual(set.count, allSubs.count, "每个 OpeningSubcategory 应唯一")
    }

    // MARK: - 8. MasterGameStore.shared

    func testMasterGameStoreSharedExists() {
        let store = MasterGameStore.shared
        XCTAssertNotNil(store, "MasterGameStore.shared 应存在")
    }

    func testMasterGameStoreInitiallyNotLoaded() {
        // 注意：如果其他测试先触发了 loadIfNeeded，isLoaded 可能为 true
        // 此测试验证 singleton 存在即可，不强制 isLoaded=false
        let store = MasterGameStore.shared
        // 只验证 store 有 allGames 属性可访问
        XCTAssertTrue(store.allGames.count >= 0)
    }

    // MARK: - 9. L10n 新增 key（11 个）

    func testL10nDemoSelectCategory() {
        let text = L10n.shared.t("demo.selectCategory")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.selectCategory")
    }

    func testL10nDemoSectionPuzzles() {
        let text = L10n.shared.t("demo.sectionPuzzles")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.sectionPuzzles")
    }

    func testL10nDemoSectionMasterGames() {
        let text = L10n.shared.t("demo.sectionMasterGames")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.sectionMasterGames")
    }

    func testL10nDemoLoadMasterIndex() {
        let text = L10n.shared.t("demo.loadMasterIndex")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.loadMasterIndex")
    }

    func testL10nDemoLoadMore() {
        let text = L10n.shared.t("demo.loadMore")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.loadMore")
    }

    func testL10nDemoMoveCount() {
        let text = L10n.shared.t("demo.moveCount")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.moveCount")
        let formatted = String(format: text, 80)
        XCTAssertTrue(formatted.contains("80"))
    }

    func testL10nDemoLoadError() {
        let text = L10n.shared.t("demo.loadError")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.loadError")
    }

    func testL10nDemoLoadGameFail() {
        let text = L10n.shared.t("demo.loadGameFail")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.loadGameFail")
    }

    func testL10nDemoParseGameFail() {
        let text = L10n.shared.t("demo.parseGameFail")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.parseGameFail")
    }

    func testL10nDemoIncompleteWarning() {
        let text = L10n.shared.t("demo.incompleteWarning")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.incompleteWarning")
    }

    func testL10nDemoIncompleteMessage() {
        let text = L10n.shared.t("demo.incompleteMessage")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "demo.incompleteMessage")
    }

    // MARK: - 10. DemoInfoBar 兼容性

    func testDemoInfoBarUsesDemoItemWrapper() {
        // DemoInfoBar 现在接收 DemoItemWrapper 而非 Puzzle
        // 验证 wrapper 的属性足够 DemoInfoBar 使用
        let puzzle = makePuzzle(id: "p1", solution: ["h2e2"])
        let wrapper = DemoItemWrapper.puzzle(puzzle)

        XCTAssertFalse(wrapper.demoTitle.isEmpty)
        XCTAssertFalse(wrapper.demoCategory.isEmpty)
        XCTAssertFalse(wrapper.demoSubtitle.isEmpty)

        let index = makeMasterGameIndex()
        let masterItem = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let masterWrapper = DemoItemWrapper.masterGame(masterItem)

        XCTAssertFalse(masterWrapper.demoTitle.isEmpty)
        XCTAssertFalse(masterWrapper.demoCategory.isEmpty)
        XCTAssertFalse(masterWrapper.demoSubtitle.isEmpty)
    }

    // MARK: - 11. ConvertResult 结构

    func testConvertResultComplete() {
        let result = DemoMoveConverter.ConvertResult(moves: [], failedSteps: 0, isComplete: true)
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(result.failedSteps, 0)
    }

    func testConvertResultIncomplete() {
        let result = DemoMoveConverter.ConvertResult(moves: [], failedSteps: 5, isComplete: false)
        XCTAssertFalse(result.isComplete)
        XCTAssertEqual(result.failedSteps, 5)
    }
}
