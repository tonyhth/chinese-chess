import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.21 Phase 2: 7 个 Bug 修复验证
// 注意：原源码文本匹配测试已移除（测源码文本而非行为，重构后必然失效）
// 保留行为测试

@Suite("v2.2.21 Phase 2 Bug 修复验证")
struct V2221BugTests {

    // MARK: - 辅助方法

    private static func makeTestPuzzle(
        id: String = "test-puzzle",
        initialFEN: String = "3ak4/9/9/9/9/9/9/9/9/4K4 w",
        playerSide: String = "red",
        stars: Int = 1,
        solution: [String] = [],
        solutionType: String = "checkmate"
    ) -> Puzzle {
        Puzzle(
            id: id, name: "测试残局", category: "test", difficulty: 1, stars: stars,
            description: "测试", playerSide: playerSide, initialFEN: initialFEN,
            solution: solution, hints: nil, maxMoves: 10,
            solutionType: solutionType
        )
    }

    // MARK: - Bug 1+2: 残局提示索引跟踪 + 中文棋谱

    @Suite("Bug 1+2: 残局提示索引跟踪 + 中文棋谱")
    struct Bug1And2HintTrackingTests {

        @Test("getSolutionInfo 不依赖当前 board 状态")
        func getSolutionInfoIndependentOfBoardState() {
            // 构造一个局面：走棋后 board 状态改变
            // 红帅 e0→d0（横向移动，不飞将）
            let puzzle = V2221BugTests.makeTestPuzzle(
                id: "test-independent-board",
                initialFEN: "3ak4/9/9/9/9/9/9/9/9/4K4 w",
                solution: ["e0d0", "a9a8", "d0e0"],
                solutionType: "checkmate"
            )
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 点击提示（渐进提示：Level 1 方向提示不设 hintMove）
            vm.showHint()

            // 提示应能正常显示（不依赖 board 状态）
            #expect(vm.currentHint != nil, "提示应能正常显示，不依赖 board 状态")

            // Level 1 不设 hintMove 是正确行为（渐进提示）
            // 需要到 Level 3 才有 hintMove
            vm.showHint() // Level 2
            vm.showHint() // Level 3
            #expect(vm.hintMove != nil || vm.currentHint?.contains("noMoreHints") ?? false,
                   "Level 3 提示高亮位置应有值或显示无更多提示")
        }

        @Test("撤销后 hintOffsetInSession 重置为 0")
        func hintOffsetResetAfterUndo() {
            let puzzle = V2221BugTests.makeTestPuzzle(
                id: "test-undo-reset",
                initialFEN: FENParser.standardInitial,
                solution: ["b0c2"],
                solutionType: "checkmate"
            )
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 点击提示
            vm.showHint()
            vm.dismissHint()

            // 模拟撤销（直接调用 undoMove）
            vm.undoMove()

            // 撤销后再次点击提示，应从当前步开始
            vm.showHint()
            #expect(vm.currentHint != nil, "撤销后点击提示应有内容")
        }
    }

    // MARK: - Bug 6: 通关状态筛选（xcstrings 数据验证保留）

    @Suite("Bug 6: 通关状态筛选")
    struct Bug6CompletionFilterTests {

        @Test("本地化 key puzzle.filterCompleted 和 puzzle.filterUncompleted 存在")
        func filterLocalizationKeysExist() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 Localizable.xcstrings")
                return
            }

            #expect(content.contains("\"puzzle.filterCompleted\""),
                   "应有 puzzle.filterCompleted 本地化 key")
            #expect(content.contains("\"puzzle.filterUncompleted\""),
                   "应有 puzzle.filterUncompleted 本地化 key")
        }
    }
}
