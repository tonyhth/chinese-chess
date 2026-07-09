import Foundation
import Testing
@testable import ChineseChess

// MARK: - v4.0 Phase 3 #7 残局三级渐进提示测试

@Suite("v4.0 Phase 3 三级渐进提示", .serialized)
struct V40Phase3HintTests {

    // MARK: - 辅助：构造测试 Puzzle

    /// 红车一步将杀
    /// ICCS d1d9 = col 3, row 9-1=8 → col 3, row 9-9=0
    /// 所以车在 (8,3)，黑将在 (0,3)
    private func makeCheckmatePuzzle() -> Puzzle {
        Puzzle(
            id: "test_hint_001",
            name: "测试-红车将杀",
            category: "elementary",
            difficulty: 1,
            stars: 1,
            description: "红车一步将杀",
            playerSide: "red",
            initialFEN: "3k5/9/9/9/9/9/9/9/3R5/4K4 w - - 0 1",
            solution: ["d1d9"],
            hints: nil,
            maxMoves: 3
        )
    }

    /// 带 hints 的残局（车在 row 8）
    private func makePuzzleWithHints() -> Puzzle {
        Puzzle(
            id: "test_hint_003",
            name: "测试-带提示残局",
            category: "elementary",
            difficulty: 1,
            stars: 1,
            description: "有预设提示",
            playerSide: "red",
            initialFEN: "3k5/9/9/9/9/9/9/9/3R5/4K4 w - - 0 1",
            solution: ["d1d9"],
            hints: ["先发制人，直逼黑将", "用红车进攻"],
            maxMoves: 3
        )
    }

    /// hint 类型残局
    private func makeHintTypePuzzle() -> Puzzle {
        Puzzle(
            id: "test_hint_004",
            name: "测试-hint类型残局",
            category: "elementary",
            difficulty: 1,
            stars: 1,
            description: "自由对弈提示局",
            playerSide: "red",
            initialFEN: FENParser.standardInitial,
            solution: [],
            hints: ["自由对弈，尝试不同走法"],
            maxMoves: 999,
            solutionType: "hint"
        )
    }

    /// 红炮残局
    /// ICCS e1e0 = col 4, row 9-1=8 → col 4, row 9-0=9
    /// 但我们需要炮从 row 8 打到 row 0（将军）
    /// ICCS e1e9 = col 4, row 8 → col 4, row 0
    private func makeCannonPuzzle() -> Puzzle {
        Puzzle(
            id: "test_hint_005",
            name: "测试-红炮残局",
            category: "elementary",
            difficulty: 1,
            stars: 1,
            description: "红炮进攻",
            playerSide: "red",
            initialFEN: "3k5/9/9/9/9/9/9/9/4C4/4K4 w - - 0 1",
            solution: ["e1e9"],
            hints: nil,
            maxMoves: 3
        )
    }

    // MARK: - 测试组 1: 三级渐进递增

    @MainActor
    @Test("连续点击提示：hintLevel 0→1→2→3，到 3 后不再升级")
    func hintLevelProgression() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        #expect(vm.hintLevel == 0, "初始 hintLevel 应为 0")

        vm.showHint()
        #expect(vm.hintLevel == 1, "第一次提示后 hintLevel 应为 1")
        #expect(vm.hintMove == nil, "Level 1 不应设置 hintMove")
        #expect(vm.currentHint != nil, "Level 1 应有提示文字")

        vm.showHint()
        #expect(vm.hintLevel == 2, "第二次提示后 hintLevel 应为 2")
        #expect(vm.hintMove == nil, "Level 2 不应设置 hintMove")
        #expect(vm.currentHint != nil, "Level 2 应有提示文字")

        vm.showHint()
        #expect(vm.hintLevel == 3, "第三次提示后 hintLevel 应为 3")

        vm.showHint()
        #expect(vm.hintLevel == 3, "第四次提示 hintLevel 仍应为 3（不再升级）")
    }

    // MARK: - 测试组 2: 走棋后重置

    @MainActor
    @Test("走对一步后 hintLevel 重置为 0")
    func hintLevelResetAfterCorrectMove() {
        let puzzle = makeCheckmatePuzzle()
        let vm = PuzzleViewModel(puzzle: puzzle)

        vm.showHint()
        vm.showHint()
        #expect(vm.hintLevel == 2)

        // 先关闭提示状态（gameState 回到 playing）
        vm.dismissHint()

        // d1d9 = ICCS: col 3 row 8 → col 3 row 0
        vm.movePiece(from: Position(row: 8, col: 3), to: Position(row: 0, col: 3))

        #expect(vm.hintLevel == 0, "走对一步后 hintLevel 应重置为 0")
    }

    // MARK: - 测试组 3: 悔棋后重置

    @MainActor
    @Test("悔棋后 hintLevel 重置为 0")
    func hintLevelResetAfterUndo() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        vm.showHint()
        vm.showHint()
        vm.showHint()
        #expect(vm.hintLevel == 3)

        vm.undoMove()

        #expect(vm.hintLevel == 0, "悔棋后 hintLevel 应重置为 0")
    }

    // MARK: - 测试组 4: resetPuzzle 重置

    @MainActor
    @Test("resetPuzzle 后 hintLevel 重置为 0")
    func hintLevelResetAfterResetPuzzle() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        vm.showHint()
        vm.showHint()
        vm.showHint()
        #expect(vm.hintLevel == 3)

        vm.resetPuzzle()

        #expect(vm.hintLevel == 0, "resetPuzzle 后 hintLevel 应为 0")
    }

    // MARK: - 测试组 5: 错误走棋后重置

    @MainActor
    @Test("走错一步后 hintLevel 重置为 0")
    func hintLevelResetAfterWrongMove() async {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        vm.showHint()
        vm.showHint()
        #expect(vm.hintLevel == 2)

        // 先关闭提示状态
        vm.dismissHint()

        // 错误走法：车从 (8,3) 到 (7,3)（不是 solution）
        vm.movePiece(from: Position(row: 8, col: 3), to: Position(row: 7, col: 3))

        try? await Task.sleep(nanoseconds: 1_500_000_000)

        #expect(vm.hintLevel == 0, "走错一步后 hintLevel 应重置为 0")
    }

    // MARK: - 测试组 6: Level 1 方向提示

    @MainActor
    @Test("Level 1 方向提示：将军走法显示提示")
    func directionHintShowsCheck() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        vm.showHint()

        #expect(vm.currentHint != nil, "Level 1 应有提示")
        let hint = vm.currentHint ?? ""
        #expect(!hint.isEmpty, "提示文字不应为空")
    }

    @MainActor
    @Test("Level 1 方向提示：hints[0] 优先")
    func directionHintPrefersPuzzleHints() {
        let vm = PuzzleViewModel(puzzle: makePuzzleWithHints())

        vm.showHint()

        #expect(vm.currentHint == "先发制人，直逼黑将", "Level 1 应使用 hints[0]")
    }

    // MARK: - 测试组 7: Level 2 棋子提示

    @MainActor
    @Test("Level 2 棋子提示：车走法有提示")
    func pieceHintShowsChariot() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        vm.showHint()
        vm.showHint()

        #expect(vm.currentHint != nil, "Level 2 应有提示")
    }

    @MainActor
    @Test("Level 2 棋子提示：炮走法有提示")
    func pieceHintShowsCannon() {
        let vm = PuzzleViewModel(puzzle: makeCannonPuzzle())

        vm.showHint()
        vm.showHint()

        #expect(vm.currentHint != nil, "Level 2 应有提示")
    }

    @MainActor
    @Test("Level 2 棋子提示：hints[1] 优先")
    func pieceHintPrefersPuzzleHints() {
        let vm = PuzzleViewModel(puzzle: makePuzzleWithHints())

        vm.showHint() // Level 1 → hints[0]
        vm.showHint() // Level 2 → hints[1]

        #expect(vm.currentHint == "用红车进攻", "Level 2 应使用 hints[1]")
    }

    // MARK: - 测试组 8: Level 3 完整走法

    @MainActor
    @Test("Level 3：设置 hintMove 和提示文字")
    func level3FullHintSetsMove() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        vm.showHint()
        vm.showHint()
        vm.showHint()

        #expect(vm.hintMove != nil, "Level 3 应设置 hintMove")
        #expect(vm.currentHint != nil, "Level 3 应有提示文字")
    }

    @MainActor
    @Test("Level 3：hintMove from/to 正确")
    func level3HintMoveCorrectness() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        vm.showHint()
        vm.showHint()
        vm.showHint()

        // solution[0] = "d1d9" → ICCS: col d(3) row 1(=8) → col d(3) row 9(=0)
        // 所以 from = (8, 3), to = (0, 3)
        #expect(vm.hintMove != nil)
        if let hm = vm.hintMove {
            #expect(hm.from.row == 8 && hm.from.col == 3, "hintMove.from 应为 (8,3)")
            #expect(hm.to.row == 0 && hm.to.col == 3, "hintMove.to 应为 (0,3)")
        }
    }

    // MARK: - 测试组 9: hint 类型残局不受影响

    @MainActor
    @Test("hint 类型残局不受三级渐进影响")
    func hintTypePuzzleUnaffected() {
        let vm = PuzzleViewModel(puzzle: makeHintTypePuzzle())

        vm.showHint()
        #expect(vm.hintLevel == 0, "hint 类型残局不应升级 hintLevel")
        #expect(vm.currentHint == "自由对弈，尝试不同走法", "应显示 hints[0]")

        vm.showHint()
        #expect(vm.hintLevel == 0, "hint 类型残局第二次提示后 hintLevel 仍应为 0")
    }

    // MARK: - 测试组 10: Level 1/2 无 hintMove

    @MainActor
    @Test("Level 1 和 Level 2 不设置 hintMove")
    func level1And2NoHintMove() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        vm.showHint()
        #expect(vm.hintMove == nil, "Level 1 不应有 hintMove")

        vm.showHint()
        #expect(vm.hintMove == nil, "Level 2 不应有 hintMove")

        vm.showHint()
        #expect(vm.hintMove != nil, "Level 3 应有 hintMove")
    }

    // MARK: - 测试组 11: gameState 切换

    @MainActor
    @Test("showHint 后 gameState 变为 showingHint")
    func gameStateAfterShowHint() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        #expect(vm.gameState == .playing)

        vm.showHint()
        #expect(vm.gameState == .showingHint, "提示后 gameState 应为 showingHint")
    }

    // MARK: - 测试组 12: 边界情况

    @MainActor
    @Test("solution 为空的非 hint 残局：Level 3 显示无提示信息")
    func emptySolutionLevel3() {
        let puzzle = Puzzle(
            id: "test_empty_sol",
            name: "空解法",
            category: "elementary",
            difficulty: 1,
            stars: 1,
            description: "无解法",
            playerSide: "red",
            initialFEN: "3k5/9/9/9/9/9/9/9/3R5/4K4 w - - 0 1",
            solution: [],
            hints: nil,
            maxMoves: 3,
            solutionType: "checkmate"
        )
        let vm = PuzzleViewModel(puzzle: puzzle)

        vm.showHint() // Level 1
        vm.showHint() // Level 2
        vm.showHint() // Level 3

        #expect(vm.currentHint != nil, "即使无解法，也应有提示文字")
    }

    @MainActor
    @Test("多次重复 showHint 不 crash 且 hintLevel 不超过 3")
    func repeatedShowHintNoCrash() {
        let vm = PuzzleViewModel(puzzle: makeCheckmatePuzzle())

        for _ in 0..<10 {
            vm.showHint()
        }

        #expect(vm.hintLevel == 3, "多次调用后 hintLevel 应稳定在 3")
    }
}
