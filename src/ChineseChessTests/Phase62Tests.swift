import Testing
import Foundation
@testable import ChineseChess

// MARK: - Phase 6.2 模型与引擎改造测试

struct Phase62Tests {

    // MARK: - SolutionMode 测试

    @Test("SolutionMode: effectiveMode — solution 非空时为 guided")
    func testEffectiveModeGuided() {
        let puzzle = Puzzle(
            id: "test_001", name: "测试", category: "测试",
            difficulty: 1, stars: 1, description: "测试",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1",
            solution: ["a1a2"], hints: nil, maxMoves: 10,
            solutionMode: .freePlay  // 显式设为 freePlay
        )
        // 但 solution 非空 → effectiveMode 应为 guided
        #expect(puzzle.effectiveMode == .guided)
    }

    @Test("SolutionMode: effectiveMode — solution 为空时用显式声明")
    func testEffectiveModeFreePlay() {
        let puzzle = Puzzle(
            id: "test_002", name: "测试", category: "测试",
            difficulty: 1, stars: 1, description: "测试",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1",
            solution: [], hints: nil, maxMoves: 10,
            solutionMode: .freePlay
        )
        #expect(puzzle.effectiveMode == .freePlay)
    }

    @Test("SolutionMode: effectiveMode — solution 为空且无显式声明时默认 guided")
    func testEffectiveModeDefaultGuided() {
        let puzzle = Puzzle(
            id: "test_003", name: "测试", category: "测试",
            difficulty: 1, stars: 1, description: "测试",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1",
            solution: [], hints: nil, maxMoves: 10
            // 不传 solutionMode，默认 .guided
        )
        #expect(puzzle.effectiveMode == .guided)
    }

    @Test("SolutionMode: JSON 解码兼容性 — 无 solutionMode 字段时默认 guided")
    func testJSONDecodeCompat() throws {
        let json = """
        {
            "id": "compat_001",
            "name": "兼容测试",
            "category": "测试",
            "difficulty": 1,
            "stars": 1,
            "description": "测试",
            "playerSide": "red",
            "initialFEN": "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1",
            "solution": [],
            "hints": null,
            "maxMoves": 10
        }
        """
        let data = json.data(using: .utf8)!
        let puzzle = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(puzzle.solutionMode == .guided)
        #expect(puzzle.effectiveMode == .guided)
    }

    @Test("SolutionMode: JSON 解码 — 有 solutionMode 字段")
    func testJSONDecodeWithMode() throws {
        let json = """
        {
            "id": "mode_001",
            "name": "模式测试",
            "category": "测试",
            "difficulty": 3,
            "stars": 3,
            "description": "测试",
            "playerSide": "red",
            "initialFEN": "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1",
            "solution": [],
            "hints": null,
            "maxMoves": 15,
            "solutionMode": "freePlay",
            "subcategory": "中级"
        }
        """
        let data = json.data(using: .utf8)!
        let puzzle = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(puzzle.solutionMode == .freePlay)
        #expect(puzzle.effectiveMode == .freePlay)
        #expect(puzzle.subcategory == "中级")
    }

    // MARK: - PuzzleState 新状态

    @Test("PuzzleState: draw 和 maxMovesWarning 存在")
    func testNewStates() {
        let drawState: PuzzleViewModel.PuzzleState = .draw
        let warningState: PuzzleViewModel.PuzzleState = .maxMovesWarning
        #expect(drawState == .draw)
        #expect(warningState == .maxMovesWarning)
    }

    // MARK: - PuzzleStore 新查询

    @Test("PuzzleStore: 按难度筛选")
    func testPuzzlesByDifficulty() {
        let store = PuzzleStore.shared
        let stars1 = store.puzzles(byDifficulty: 1)
        let stars5 = store.puzzles(byDifficulty: 5)
        #expect(stars1.allSatisfy { $0.stars == 1 })
        #expect(stars5.allSatisfy { $0.stars == 5 })
        #expect(stars5.count > 0)  // 适情雅趣有5星
    }

    @Test("PuzzleStore: 搜索功能")
    func testSearchPuzzles() {
        let store = PuzzleStore.shared
        // 搜索中文名
        let results = store.searchPuzzles(query: "气吞关右")
        #expect(results.count >= 1)
        #expect(results[0].name.contains("气吞关右"))

        // 搜索分类（棋子类型）
        let cheMa = store.searchPuzzles(query: "车马类")
        #expect(cheMa.count > 0)
        #expect(cheMa.allSatisfy { $0.category.contains("车马类") })

        // 空搜索返回全部
        let all = store.searchPuzzles(query: "")
        #expect(all.count == store.totalPuzzles)
    }

    @Test("PuzzleStore: 适情雅趣专用查询")
    func testShiqingyaquPuzzles() {
        let store = PuzzleStore.shared
        let sqyq = store.shiqingyaquPuzzles
        #expect(sqyq.count == 551)
        #expect(sqyq.allSatisfy { $0.source == "适情雅趣" })
        #expect(sqyq.allSatisfy { $0.id.hasPrefix("sqyq_") })
    }

    @Test("PuzzleStore: 统计数据")
    func testStoreStats() {
        let store = PuzzleStore.shared
        #expect(store.totalPuzzles == 551)
        #expect(store.completedCount >= 0)
    }

    @Test("PuzzleStore: subcategory 分布")
    func testSubcategory() {
        let store = PuzzleStore.shared
        let sqyq = store.shiqingyaquPuzzles
        let subs = Set(sqyq.compactMap { $0.subcategory })
        #expect(subs.contains("入门"))
        #expect(subs.contains("初级"))
        #expect(subs.contains("中级"))
        #expect(subs.contains("高级"))
        #expect(subs.contains("大师"))
    }

    // MARK: - 自由对弈模式初始状态

    @Test("PuzzleViewModel: freePlay 模式初始化")
    func testFreePlayInit() {
        let puzzle = Puzzle(
            id: "fp_001", name: "自由对弈", category: "车马炮类",
            difficulty: 3, stars: 3, description: "测试",
            playerSide: "red",
            initialFEN: "2bakab2/9/1cn4c1/p1p1p3p/9/2P6/P3P1PRP/2N1C1N2/9/R1BAKAB2 w - - 0 1",
            solution: [], hints: nil, maxMoves: 25,
            solutionMode: .freePlay, subcategory: "中级"
        )
        let vm = PuzzleViewModel(puzzle: puzzle)
        #expect(vm.gameState == .playing)
        #expect(vm.puzzle.effectiveMode == .freePlay)
    }
}
