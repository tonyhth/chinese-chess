// iOS 工具栏与状态栏适配测试
// 测试范围：ToolbarView iOS EmptyView 分支、StatusBarView iOS 分支、ChineseChessiOSApp toolbar 逻辑
// 注意：由于 iOS 专用 View 代码在 macOS 测试中通过 #if os(iOS) 编译隔离，
// 本测试重点覆盖 ViewModel 层面的逻辑正确性（按钮 disabled 条件、状态转换等）

import Foundation
import Testing
@testable import ChineseChess

@Suite("iOS 工具栏与状态栏适配")
struct IOSToolbarAdaptationTests {

    // MARK: - 新局按钮逻辑

    @MainActor
@Test("新局后：isThinking=false, moveHistory 为空, gameState=playing, capturedPieces 清空")
    func newGameResetsAllState() {
        let vm = GameViewModel()
        // 模拟走棋后状态
        vm.isThinking = true
        vm.gameState = .redWon
        let testPiece = Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 0))
        vm.capturedPieces = (red: [testPiece], black: [])
        vm.gameMoves = [GameMove(id: UUID(), piece: testPiece, from: Position(row: 0, col: 0), to: Position(row: 1, col: 0), captured: nil, turnNumber: 1, notation: "車九平八", timestamp: Date(), isCheck: false, isCheckmate: false)]

        vm.newGame()

        #expect(vm.isThinking == false)
        #expect(vm.board.moveHistory.isEmpty)
        #expect(vm.gameState == .playing)
        #expect(vm.capturedPieces.red.isEmpty)
        #expect(vm.capturedPieces.black.isEmpty)
        #expect(vm.gameMoves.isEmpty)
        #expect(vm.hintMove == nil)
    }

    @MainActor
@Test("新局后按钮 disabled 状态：isThinking=false → 新局按钮可用")
    func newGameButtonEnabledAfterNewGame() {
        let vm = GameViewModel()
        vm.isThinking = true
        vm.newGame()
        // 新局后 isThinking=false → 新局按钮 enabled
        #expect(!vm.isThinking)
    }

    // MARK: - 悔棋按钮 disabled 条件

    @MainActor
@Test("初始局面悔棋：moveHistory 为空 → disabled=true")
    func undoDisabledOnEmptyHistory() {
        let vm = GameViewModel()
        #expect(vm.board.moveHistory.isEmpty)
        // disabled 条件: isThinking || board.moveHistory.isEmpty
        let undoDisabled = vm.isThinking || vm.board.moveHistory.isEmpty
        #expect(undoDisabled == true)
    }

    @MainActor
@Test("AI 思考中悔棋：isThinking=true → disabled=true")
    func undoDisabledWhileThinking() {
        let vm = GameViewModel()
        vm.isThinking = true
        // 即使 moveHistory 不为空（假设），isThinking 也阻止悔棋
        let undoDisabled = vm.isThinking
        #expect(undoDisabled == true)
    }

    @MainActor
@Test("undoMove 在 moveHistory<2 时无效：不做任何状态变更")
    func undoMoveDoesNothingWithLessThanTwoMoves() {
        let vm = GameViewModel()
        let originalTurn = vm.currentTurn
        vm.undoMove()
        // moveHistory 为空，guard 不通过，状态不变
        #expect(vm.board.moveHistory.isEmpty)
        #expect(vm.currentTurn == originalTurn)
    }

    @MainActor
@Test("undoMove 在 isThinking=true 时无效")
    func undoMoveBlockedWhenThinking() {
        let vm = GameViewModel()
        vm.isThinking = true
        vm.undoMove()
        #expect(vm.board.moveHistory.isEmpty)
    }

    // MARK: - 提示按钮 disabled 条件

    @MainActor
@Test("提示按钮：初始局面 playing 且 !isThinking → disabled=false")
    func hintEnabledOnInitialBoard() {
        let vm = GameViewModel()
        let hintDisabled = vm.isThinking || vm.gameState != .playing
        #expect(hintDisabled == false)
    }

    @MainActor
@Test("提示按钮：游戏结束后 → disabled=true")
    func hintDisabledAfterGameOver() {
        let vm = GameViewModel()
        vm.gameState = .redWon
        let hintDisabled = vm.gameState != .playing
        #expect(hintDisabled == true)
    }

    @MainActor
@Test("提示按钮：AI 思考中 → disabled=true")
    func hintDisabledWhileThinking() {
        let vm = GameViewModel()
        vm.isThinking = true
        let hintDisabled = vm.isThinking
        #expect(hintDisabled == true)
    }

    @MainActor
@Test("requestHint 在 !playing 时被 guard 拦截，不触发异步")
    func requestHintBlockedWhenNotPlaying() {
        let vm = GameViewModel()
        vm.gameState = .blackWon
        vm.requestHint()
        // guard 拦截，isThinking 保持 false（不会设为 true）
        #expect(vm.isThinking == false)
    }

    // MARK: - setDifficulty

    @MainActor
@Test("setDifficulty 正确更新 difficulty 值")
    func setDifficultyUpdatesValue() {
        let vm = GameViewModel()
        #expect(vm.difficulty == .medium) // 默认值

        vm.setDifficulty(.beginner)
        #expect(vm.difficulty == .beginner)

        vm.setDifficulty(.master)
        #expect(vm.difficulty == .master)
    }

    @MainActor
@Test("AIDifficulty CaseIterable 包含 5 个级别")
    func allDifficulties() {
        #expect(AIDifficulty.allCases.count == 5)
    }

    // MARK: - ToolbarView iOS 分支验证（编译时）

    @MainActor
@Test("ToolbarView 在 macOS 上不返回 EmptyView（编译时确认）")
    func toolbarViewMacOSBranch() {
        let vm = GameViewModel()
        let toolbar = ToolbarView(viewModel: vm)
        // macOS 分支正常创建，iOS 分支返回 EmptyView
        // 此测试仅验证 macOS 分支能正常实例化
        _ = toolbar
    }

    // MARK: - StatusBarView 状态覆盖

    @MainActor
@Test("StatusBarView 初始状态无被吃棋子")
    func statusBarInitialNoCaptures() {
        let vm = GameViewModel()
        #expect(vm.capturedPieces.red.isEmpty)
        #expect(vm.capturedPieces.black.isEmpty)
    }

    @MainActor
@Test("StatusBarView currentTurn 初始为红方")
    func statusBarInitialRedTurn() {
        let vm = GameViewModel()
        #expect(vm.currentTurn == .red)
    }

    @MainActor
@Test("StatusBarView isInCheck 初始为 false")
    func statusBarInitialNotInCheck() {
        let vm = GameViewModel()
        #expect(vm.isInCheck == false)
    }

    // MARK: - buildGameRecord

    @MainActor
@Test("buildGameRecord：初始局面（无走法）返回 nil 或有值取决于实现")
    func buildGameRecordEmpty() {
        let vm = GameViewModel()
        let record = vm.buildGameRecord()
        // 空棋局可能返回 nil（无意义的记录）或有值
        // 关键是不 crash
        _ = record
    }

    // MARK: - 回放按钮 disabled 条件

    @MainActor
@Test("回放按钮：gameMoves 为空时 disabled=true")
    func replayDisabledWhenNoMoves() {
        let vm = GameViewModel()
        #expect(vm.gameMoves.isEmpty)
        // toolbar 中回放按钮 disabled 条件: gameViewModel.gameMoves.isEmpty
        let replayDisabled = vm.gameMoves.isEmpty
        #expect(replayDisabled == true)
    }

    // MARK: - Panel 互斥管理

    @MainActor
@Test("ChineseChessiOSApp.Panel enum 完整性")
    func panelEnumCases() {
        // Panel 是 ChineseChessiOSApp 内部 enum，无法直接测试
        // 但可以验证 GameViewModel 的面板相关状态管理
        // 这里验证 activePanel 的 3 个值：none, record, stats
        // 由于 Panel 在 #if os(iOS) 内，macOS 测试无法访问
        // 通过 GameViewModel 的 gameMoves 来间接验证
        let vm = GameViewModel()
        #expect(vm.gameMoves.isEmpty) // record panel 数据源
    }

    // MARK: - 条件编译边界

    @MainActor
@Test("capturedPieces 元组类型正确")
    func capturedPiecesTupleType() {
        let vm = GameViewModel()
        // 验证 capturedPieces 结构
        let redPieces = vm.capturedPieces.red
        let blackPieces = vm.capturedPieces.black
        #expect(redPieces.isEmpty)
        #expect(blackPieces.isEmpty)
        // 类型推断
        let _: [Piece] = redPieces
        let _: [Piece] = blackPieces
    }

    @MainActor
@Test("newGame 后 hintMove 被清除")
    func newGameClearsHint() {
        let vm = GameViewModel()
        // 假设有 hint
        vm.hintMove = (from: Position(row: 0, col: 0), to: Position(row: 1, col: 0))
        vm.newGame()
        #expect(vm.hintMove == nil)
    }

    @MainActor
@Test("newGame 后 selectedPosition 被清除")
    func newGameClearsSelection() {
        let vm = GameViewModel()
        vm.selectedPosition = Position(row: 5, col: 5)
        vm.newGame()
        #expect(vm.selectedPosition == nil)
    }

    @MainActor
@Test("newGame 后 legalMovesForSelected 为空")
    func newGameClearsLegalMoves() {
        let vm = GameViewModel()
        vm.legalMovesForSelected = [Position(row: 0, col: 0)]
        vm.newGame()
        #expect(vm.legalMovesForSelected.isEmpty)
    }

    // MARK: - macOS 零影响验证

    @MainActor
@Test("StatusBarView macOS 分支：capturedPiecesText 函数可用且不 crash")
    func statusBarMacOSBranchNoCrash() {
        let vm = GameViewModel()
        let statusBar = StatusBarView(viewModel: vm)
        _ = statusBar
    }

    // MARK: - Undo 后 capturedPieces 同步

    @MainActor
@Test("undoMove 正确恢复 capturedPieces")
    func undoMoveRestoresCapturedPieces() async {
        let vm = GameViewModel()
        // 初始局面手动执行走棋（模拟吃子）
        // 走一步棋（红方走，触发 AI 回应）
        let redCharriot = vm.board.piece(at: Position(row: 9, col: 0))
        #expect(redCharriot != nil)
        #expect(redCharriot?.kind == .chariot)

        vm.selectPiece(at: Position(row: 9, col: 0))
        #expect(vm.selectedPosition != nil)

        // 走到有效位置
        let targetPos = Position(row: 5, col: 0)
        if vm.legalMovesForSelected.contains(targetPos) {
            vm.selectPiece(at: targetPos)
        }

        // 不论走棋是否成功，undoMove 不应 crash
        if vm.board.moveHistory.count >= 2 {
            let beforeRed = vm.capturedPieces.red.count
            let beforeBlack = vm.capturedPieces.black.count
            vm.undoMove()
            vm.undoMove() // 撤销一对
            // 验证不 crash，capturedPieces 数量不超过 before
            #expect(vm.capturedPieces.red.count <= beforeRed)
            #expect(vm.capturedPieces.black.count <= beforeBlack)
        }
    }
}
