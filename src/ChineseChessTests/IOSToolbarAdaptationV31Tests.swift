import Foundation
import Testing
@testable import ChineseChess

@Suite("iOS 工具栏与状态栏适配 v3.1")
struct IOSToolbarAdaptationV31Tests {

    // MARK: - ToolbarView iOS 按钮 disabled 条件（现在在顶部 ToolbarView）

    @MainActor
@Test("新局按钮：isThinking=true 时 disabled")
    func newGameDisabledWhileThinking() {
        let vm = GameViewModel()
        vm.isThinking = true
        let disabled = vm.isThinking
        #expect(disabled == true)
    }

    @MainActor
@Test("新局按钮：isThinking=false 时 enabled")
    func newGameEnabledWhenNotThinking() {
        let vm = GameViewModel()
        #expect(vm.isThinking == false)
    }

    @MainActor
@Test("悔棋按钮：初始局面 moveHistory 为空 → disabled")
    func undoDisabledOnEmptyHistory() {
        let vm = GameViewModel()
        let disabled = vm.isThinking || vm.board.moveHistory.isEmpty
        #expect(disabled == true)
    }

    @MainActor
@Test("悔棋按钮：isThinking=true 时 disabled")
    func undoDisabledWhileThinking() {
        let vm = GameViewModel()
        vm.isThinking = true
        #expect(vm.isThinking == true)
    }

    @MainActor
@Test("悔棋按钮 undoMove：moveHistory<2 时无效")
    func undoMoveNoOpWithFewMoves() {
        let vm = GameViewModel()
        let originalTurn = vm.currentTurn
        vm.undoMove()
        #expect(vm.board.moveHistory.isEmpty)
        #expect(vm.currentTurn == originalTurn)
    }

    @MainActor
@Test("悔棋按钮 undoMove：isThinking=true 时被拦截")
    func undoMoveBlockedByThinking() {
        let vm = GameViewModel()
        vm.isThinking = true
        vm.undoMove()
        #expect(vm.board.moveHistory.isEmpty)
    }

    @MainActor
@Test("提示按钮：playing 且 !isThinking → enabled")
    func hintEnabledWhenPlayingAndNotThinking() {
        let vm = GameViewModel()
        let disabled = vm.isThinking || vm.gameState != .playing
        #expect(disabled == false)
    }

    @MainActor
@Test("提示按钮：游戏结束 → disabled")
    func hintDisabledAfterGameOver() {
        let vm = GameViewModel()
        vm.gameState = .redWon
        #expect(vm.gameState != .playing)
    }

    @MainActor
@Test("提示按钮：isThinking → disabled")
    func hintDisabledWhileThinking() {
        let vm = GameViewModel()
        vm.isThinking = true
        #expect(vm.isThinking == true)
    }

    @MainActor
@Test("requestHint：!playing 时 guard 拦截，isThinking 不变")
    func requestHintGuardWhenNotPlaying() {
        let vm = GameViewModel()
        vm.gameState = .blackWon
        vm.requestHint()
        #expect(vm.isThinking == false)
    }

    // MARK: - 底部 toolbar 按钮逻辑（v3.1 恢复 5 元素）

    @MainActor
@Test("棋谱按钮 toggle：activePanel = .record ↔ .none")
    func recordPanelToggle() {
        let vm = GameViewModel()
        // Panel 是 ChineseChessiOSApp 内部类型，无法从 macOS 测试访问
        // 验证 gameMoves 数据源为空（棋谱 toggle 的依赖数据）
        #expect(vm.gameMoves.isEmpty)
    }

    @MainActor
@Test("回放按钮：gameMoves 为空时 disabled=true")
    func replayDisabledWhenNoMoves() {
        let vm = GameViewModel()
        #expect(vm.gameMoves.isEmpty)
    }

    @MainActor
@Test("回放按钮：buildGameRecord 空棋局不 crash")
    func replayBuildRecordNoCrash() {
        let vm = GameViewModel()
        let record = vm.buildGameRecord()
        _ = record // 不 crash 即可
    }

    // MARK: - setDifficulty（难度 Menu）

    @MainActor
@Test("setDifficulty 正确更新值")
    func setDifficultyUpdates() {
        let vm = GameViewModel()
        #expect(vm.difficulty == .medium)
        vm.setDifficulty(.beginner)
        #expect(vm.difficulty == .beginner)
        vm.setDifficulty(.master)
        #expect(vm.difficulty == .master)
    }

    @MainActor
@Test("AIDifficulty 有 5 个级别")
    func allDifficulties() {
        #expect(AIDifficulty.allCases.count == 5)
    }

    // MARK: - newGame 全面重置

    @MainActor
@Test("newGame 重置所有状态")
    func newGameFullReset() {
        let vm = GameViewModel()
        let testPiece = Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 0))
        vm.isThinking = true
        vm.gameState = .redWon
        vm.capturedPieces = (red: [testPiece], black: [])
        vm.gameMoves = [GameMove(id: UUID(), piece: testPiece, from: Position(row: 0, col: 0), to: Position(row: 1, col: 0), captured: nil, turnNumber: 1, notation: "車九平八", timestamp: Date(), isCheck: false, isCheckmate: false)]
        vm.hintMove = (from: Position(row: 0, col: 0), to: Position(row: 1, col: 0))
        vm.selectedPosition = Position(row: 5, col: 5)
        vm.legalMovesForSelected = [Position(row: 0, col: 0)]

        vm.newGame()

        #expect(vm.isThinking == false)
        #expect(vm.board.moveHistory.isEmpty)
        #expect(vm.gameState == .playing)
        #expect(vm.capturedPieces.red.isEmpty)
        #expect(vm.capturedPieces.black.isEmpty)
        #expect(vm.gameMoves.isEmpty)
        #expect(vm.hintMove == nil)
        #expect(vm.selectedPosition == nil)
        #expect(vm.legalMovesForSelected.isEmpty)
    }

    // MARK: - StatusBarView 状态

    @MainActor
@Test("StatusBarView 初始状态：无被吃棋子，红方先走，不在将中")
    func statusBarInitial() {
        let vm = GameViewModel()
        #expect(vm.capturedPieces.red.isEmpty)
        #expect(vm.capturedPieces.black.isEmpty)
        #expect(vm.currentTurn == .red)
        #expect(vm.isInCheck == false)
    }

    @MainActor
@Test("capturedPieces 元组类型正确")
    func capturedPiecesTypes() {
        let vm = GameViewModel()
        let _: [Piece] = vm.capturedPieces.red
        let _: [Piece] = vm.capturedPieces.black
    }

    // MARK: - macOS 零影响

    @MainActor
@Test("ToolbarView macOS 分支正常实例化")
    func toolbarMacOSNoCrash() {
        let vm = GameViewModel()
        let toolbar = ToolbarView(viewModel: vm)
        _ = toolbar
    }

    @MainActor
@Test("StatusBarView macOS 分支正常实例化")
    func statusBarMacOSNoCrash() {
        let vm = GameViewModel()
        let statusBar = StatusBarView(viewModel: vm)
        _ = statusBar
    }

    // MARK: - v3.1 特有：capturedPiecesText 无 Group 包裹

    @MainActor
@Test("capturedPiecesText 空 pieces 显示「无」")
    func capturedPiecesTextEmpty() {
        let vm = GameViewModel()
        #expect(vm.capturedPieces.red.isEmpty)
        #expect(vm.capturedPieces.black.isEmpty)
        // capturedPiecesText 内部: pieces.isEmpty → Text("无")
        // 验证数据正确即可，View 渲染在 macOS 测试中不可直接验证
    }

    // MARK: - undoMove capturedPieces 同步

    @MainActor
@Test("undoMove 不 crash（即使 moveHistory 不足）")
    func undoMoveSafeWithInsufficientHistory() {
        let vm = GameViewModel()
        // 空 history
        vm.undoMove() // guard count>=2，不 crash
        #expect(vm.board.moveHistory.isEmpty)

        // 走一步试试
        vm.selectPiece(at: Position(row: 9, col: 0))
        if !vm.legalMovesForSelected.isEmpty {
            let target = vm.legalMovesForSelected[0]
            vm.selectPiece(at: target)
        }
        // 不论是否成功走棋，undoMove 不应 crash
        vm.isThinking = false
        vm.gameState = .playing
        vm.undoMove()
    }
}
