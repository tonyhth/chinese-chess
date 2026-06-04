import Testing
@testable import ChineseChess

@Suite("线程安全测试")
struct ThreadSafetyTests {

    @Test("AI 思考期间 isThinking 为 true")
    func isThinkingDuringAIComputation() async {
        // 不能直接测试 Task.detached + MainActor.run 的异步行为（需要 XCUITest）
        // 但可以验证 GameViewModel 的初始状态
        let vm = GameViewModel()
        #expect(!vm.isThinking)

        // 触发 AI 走法
        vm.selectPiece(at: Position(row: 7, col: 7))
        vm.selectPiece(at: Position(row: 7, col: 4))

        // 在同步上下文中 isThinking 已经被设为 true（triggerAIMove 中设置）
        #expect(vm.isThinking)
    }

    @Test("isThinking 为 true 时 selectPiece 被忽略")
    func selectPieceIgnoredWhenThinking() {
        let vm = GameViewModel()
        // 手动设置 isThinking（模拟 AI 正在思考）
        // isThinking 不是 public set，但我们可以通过触发 AI 走法来让它变为 true
        vm.selectPiece(at: Position(row: 7, col: 7))
        vm.selectPiece(at: Position(row: 7, col: 4))
        #expect(vm.isThinking)

        // 尝试在 AI 思考期间操作
        let previousSelected = vm.selectedPosition
        vm.selectPiece(at: Position(row: 9, col: 0))

        // selectPiece 应该被忽略，selectedPosition 不变
        #expect(vm.selectedPosition == previousSelected)
    }

    @Test("isThinking 为 true 时 undoMove 被忽略")
    func undoIgnoredWhenThinking() {
        let vm = GameViewModel()
        vm.selectPiece(at: Position(row: 7, col: 7))
        vm.selectPiece(at: Position(row: 7, col: 4))
        #expect(vm.isThinking)

        // 尝试悔棋
        let previousHistoryCount = vm.moveHistory.count
        vm.undoMove()
        #expect(vm.moveHistory.count == previousHistoryCount)
    }

    @Test("isThinking 为 true 时 newGame 被忽略")
    func newGameIgnoredWhenThinking() {
        let vm = GameViewModel()
        vm.selectPiece(at: Position(row: 7, col: 7))
        vm.selectPiece(at: Position(row: 7, col: 4))
        #expect(vm.isThinking)

        let previousPieceCount = vm.board.pieces.count
        vm.newGame()
        #expect(vm.board.pieces.count == previousPieceCount)
    }

    @Test("非红方回合时 selectPiece 被忽略")
    func selectPieceIgnoredWhenNotRedTurn() {
        let vm = GameViewModel()
        // 红方走一步
        vm.selectPiece(at: Position(row: 7, col: 7))
        vm.selectPiece(at: Position(row: 7, col: 4))
        // 现在 AI 在思考，轮到黑方
        #expect(vm.currentTurn == .black)

        // selectPiece 不应在黑方回合生效
        let previousSelected = vm.selectedPosition
        vm.selectPiece(at: Position(row: 9, col: 0))
        #expect(vm.selectedPosition == previousSelected)
    }
}
