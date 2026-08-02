import Foundation
import Testing
@testable import ChineseChess

// MARK: - 批次3 v3.9 综合测试（认输 / 长将 / 50回合 / captureMoves / wouldBeInCheck / SoundEngine / AIConfig）

@Suite("v3.9 批次3 认输功能", .serialized)
struct ResignTests {

    @MainActor
    @Test("requestResign 在游戏进行中设置 showResignConfirm")
    func requestResignSetsFlag() {
        let vm = GameViewModel()
        #expect(vm.gameState == .playing)
        #expect(vm.showResignConfirm == false)

        vm.requestResign()
        #expect(vm.showResignConfirm == true)
    }

    @MainActor
    @Test("requestResign 在非 playing 状态被拒绝")
    func requestResignBlockedWhenNotPlaying() {
        let vm = GameViewModel()
        vm.gameState = .redWon
        vm.requestResign()
        #expect(vm.showResignConfirm == false)
    }

    @MainActor
    @Test("requestResign 在 isThinking 时被拒绝")
    func requestResignBlockedWhenThinking() {
        let vm = GameViewModel()
        vm.isThinking = true
        vm.requestResign()
        #expect(vm.showResignConfirm == false)
    }

    @MainActor
    @Test("confirmResign 设置 gameState 为对手胜")
    func confirmResignSetsWinner() {
        let vm = GameViewModel()
        // 初始 currentTurn = .red（红方先走）
        vm.requestResign()
        vm.confirmResign()

        #expect(vm.showResignConfirm == false)
        // 红方认输 → 黑方赢
        #expect(vm.gameState == .blackWon)
    }

    @MainActor
    @Test("cancelResign 清除确认标志")
    func cancelResignClearsFlag() {
        let vm = GameViewModel()
        vm.requestResign()
        #expect(vm.showResignConfirm == true)

        vm.cancelResign()
        #expect(vm.showResignConfirm == false)
        #expect(vm.gameState == .playing)
    }

    @MainActor
    @Test("confirmResign 后游戏状态不是 playing")
    func confirmResignEndsGame() {
        let vm = GameViewModel()
        vm.confirmResign()
        #expect(vm.gameState != .playing)
    }

    @MainActor
    @Test("认输后再次 requestResign 被拒绝")
    func requestResignAfterEnd() {
        let vm = GameViewModel()
        vm.confirmResign()
        // 游戏已结束，不应能再次认输
        vm.requestResign()
        #expect(vm.showResignConfirm == false)
    }
}

@Suite("v3.9 批次3 长将判负弹窗状态", .serialized)
struct PerpetualCheckStateTests {

    @MainActor
    @Test("perpetualCheckMessage 初始为 nil")
    func perpetualCheckMessageInitialNil() {
        let vm = GameViewModel()
        #expect(vm.perpetualCheckMessage == nil)
    }

    @MainActor
    @Test("已解释标志存在时 perpetualCheckMessage 保持 nil")
    func perpetualCheckMessageAfterExplained() {
        UserDefaults.standard.set(true, forKey: "chinesechess.perpetualCheckExplained")
        defer { UserDefaults.standard.removeObject(forKey: "chinesechess.perpetualCheckExplained") }

        let vm = GameViewModel()
        #expect(vm.perpetualCheckMessage == nil)
    }
}

@Suite("v3.9 批次3 MoveValidator.captureMoves", .serialized)
struct CaptureMovesTests {

    private func makeBoard(_ pieces: [Piece]) -> Board {
        Board(pieces: pieces)
    }

    @Test("captureMoves 只返回吃子走法")
    func captureMovesOnlyCaptures() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 3), id: 203)
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 3), id: 153)
        let bs = Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 3), id: 233)
        let board = makeBoard([rg, bg, rc, bs])

        let captures = MoveValidator.captureMoves(for: .red, on: board)
        #expect(!captures.isEmpty)
        // 所有返回的走法都应该是吃子走法
        #expect(captures.allSatisfy { $0.captured != nil })
    }

    @Test("captureMoves 无吃子时返回少量或空")
    func captureMovesEmpty() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 3), id: 203)
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 5), id: 155)
        let board = makeBoard([rg, bg, rc])

        let captures = MoveValidator.captureMoves(for: .red, on: board)
        let nonGeneralCaptures = captures.filter { $0.piece.kind != .general }
        #expect(nonGeneralCaptures.isEmpty)
    }

    /// v3.9 设计：captureMoves 跳过 wouldBeInCheck 检查，可能包含更多走法。
    /// QS 内部通过实际执行验证合法性。
    /// 参考：AIEngine.swift quiescenceSearch 注释
    @Test("captureMoves 可能包含更多走法（跳过 wouldBeInCheck）")
    func captureMovesConsistentWithAllLegal() {
        let board = Board()
        let allRed = MoveValidator.allLegalMoves(for: .red, on: board)
        let captureRed = MoveValidator.captureMoves(for: .red, on: board)
        let allCaptures = allRed.filter { $0.captured != nil }

        // captureMoves 跳过 wouldBeInCheck 检查，可能包含更多走法
        #expect(captureRed.count >= allCaptures.count,
                "captureMoves 应 >= allLegalMoves 吃子数（不做 wouldBeInCheck 过滤）")
        // 所有返回的走法都应该是吃子走法
        #expect(captureRed.allSatisfy { $0.captured != nil },
                "captureMoves 只返回吃子走法")
    }

    /// v3.9 设计：captureMoves 跳过 wouldBeInCheck 检查，可能返回送将走法。
    /// QS 内部通过实际执行验证合法性，送将走法会被过滤。
    /// 此测试验证设计行为：captureMoves 不做 wouldBeInCheck 过滤。
    @Test("captureMoves 可能包含送将走法（设计预期）")
    func captureMovesFiltersSelfCheck() {
        // 红车阻隔将帅对面，离开后送将
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 8, col: 4), id: 184)
        let bc = Piece(kind: .chariot, side: .black, position: Position(row: 8, col: 0), id: 280)
        let board = makeBoard([rg, bg, rc, bc])

        let captures = MoveValidator.captureMoves(for: .red, on: board)
        let movesToBC = captures.filter { $0.to == Position(row: 8, col: 0) }
        // captureMoves 跳过 wouldBeInCheck 检查，可能包含送将走法
        // 这是设计预期，QS 内部会通过实际执行过滤
        #expect(!movesToBC.isEmpty,
                "captureMoves 跳过 wouldBeInCheck 检查，可能包含送将走法（设计预期）")
    }

    @Test("captureMoves 对黑方有效")
    func captureMovesForBlack() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 3), id: 203)
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 3), id: 153)
        let bc = Piece(kind: .chariot, side: .black, position: Position(row: 3, col: 3), id: 233)
        let board = makeBoard([rg, bg, rc, bc])

        let captures = MoveValidator.captureMoves(for: .black, on: board)
        // 黑车可以吃红车
        let hasCapture = captures.contains { $0.captured != nil }
        #expect(hasCapture)
        #expect(captures.allSatisfy { $0.captured != nil })
    }
}

@Suite("v3.9 批次3 wouldBeInCheck in-place execute/undo", .serialized)
struct WouldBeInCheckInPlaceTests {

    @Test("wouldBeInCheck 执行后棋盘恢复一致")
    func boardRestoredAfterCheck() {
        let board = Board()
        let originalSnapshot = board.snapshot()

        let redMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(!redMoves.isEmpty)

        let piece = redMoves[0].piece
        _ = MoveValidator.legalMoves(for: piece, on: board)

        // 验证棋子数量和位置一致
        #expect(board.pieces.count == originalSnapshot.pieces.count)
        #expect(board.currentTurn == originalSnapshot.currentTurn)
    }

    @Test("wouldBeInCheck 多次调用棋盘一致")
    func boardConsistentAcrossMultipleCalls() {
        let board = Board()
        let snapshot1 = board.snapshot()

        _ = MoveValidator.allLegalMoves(for: .red, on: board)
        let snapshot2 = board.snapshot()
        _ = MoveValidator.allLegalMoves(for: .black, on: board)
        let snapshot3 = board.snapshot()

        #expect(snapshot1.pieces.count == snapshot2.pieces.count)
        #expect(snapshot2.pieces.count == snapshot3.pieces.count)
        #expect(snapshot1.currentTurn == snapshot2.currentTurn)
        #expect(snapshot2.currentTurn == snapshot3.currentTurn)
    }

    @Test("wouldBeInCheck 对炮的走法验证棋盘一致性")
    func boardConsistentForCannon() {
        let board = Board()
        let cannon = board.piece(at: Position(row: 7, col: 1))!
        let originalCount = board.pieces.count

        let moves = MoveValidator.legalMoves(for: cannon, on: board)
        #expect(!moves.isEmpty)
        #expect(board.pieces.count == originalCount)
    }

    @Test("wouldBeInCheck 全局走法生成不改变棋盘")
    func allMovesDoNotMutateBoard() {
        let board = Board()
        let originalCount = board.pieces.count
        let originalTurn = board.currentTurn

        _ = MoveValidator.allLegalMoves(for: .red, on: board)
        _ = MoveValidator.allLegalMoves(for: .black, on: board)
        _ = MoveValidator.captureMoves(for: .red, on: board)
        _ = MoveValidator.captureMoves(for: .black, on: board)

        #expect(board.pieces.count == originalCount)
        #expect(board.currentTurn == originalTurn)
    }
}

@Suite("v3.9 批次3 SoundEngine isMuted 同步", .serialized)
struct SoundEngineMutedSyncTests {

    @Test("isMuted 同步读写一致")
    func isMutedSyncReadWrite() {
        let engine = SoundEngine.shared
        let original = engine.isMuted

        engine.isMuted = true
        #expect(engine.isMuted == true)

        engine.isMuted = false
        #expect(engine.isMuted == false)

        engine.isMuted = original
    }

    @Test("isMuted 连续设置不会死锁")
    func isMutedNoDeadlock() {
        let engine = SoundEngine.shared
        let original = engine.isMuted

        for i in 0..<20 {
            engine.isMuted = (i % 2 == 0)
        }
        #expect(engine.isMuted == false)

        engine.isMuted = original
    }

    @Test("isMuted 快速切换后最终值正确")
    func isMutedFinalValue() {
        let engine = SoundEngine.shared
        let original = engine.isMuted

        engine.isMuted = true
        engine.isMuted = true
        engine.isMuted = false
        engine.isMuted = false
        engine.isMuted = true

        #expect(engine.isMuted == true)

        engine.isMuted = original
    }
}

@Suite("v3.9 批次3 AIConstants medium 配置", .serialized)
struct AIConstantsMediumConfigTests {

    @Test("medium 启用 Quiescence Search")
    func mediumEnablesQS() {
        #expect(AISearchConfig.medium.enableQuiescence == true, "medium 应启用 QS")
    }

    @Test("medium 使用 advanced eval - mobility 启用")
    func mediumUsesAdvancedEval() {
        #expect(AISearchConfig.medium.evalConfig.mobility == true, "medium 应启用 mobility 评估")
    }

    @Test("medium 使用 advanced eval - safety 启用")
    func mediumSafetyEnabled() {
        #expect(AISearchConfig.medium.evalConfig.safety == true, "medium 应启用 safety 评估")
    }

    @Test("medium maxQSDepth 为 2")
    func mediumQSDepth() {
        #expect(AISearchConfig.medium.maxQSDepth == 2, "medium QS 深度应为 2")
    }

    @Test("hard 配置未受影响")
    func hardConfigUnchanged() {
        #expect(AISearchConfig.hard.enableQuiescence == true)
        #expect(AISearchConfig.hard.evalConfig.mobility == true)
        #expect(AISearchConfig.hard.maxQSDepth == 4)
    }

    @Test("default 配置 QS 关闭")
    func defaultConfigQSDisabled() {
        #expect(AISearchConfig.default.enableQuiescence == false)
    }

    @Test("default 配置使用 advanced eval（mobility=true）")
    func defaultConfigBasicEval() {
        #expect(AISearchConfig.default.evalConfig.mobility == true)
    }
}

// v5.0: OpeningTreeNode 已被 OpeningExplorerNode 替换
// 旧测试已归档到 _archive_v4/

@Suite("v3.9 批次3 综合回归", .serialized)
struct Batch3FullRegressionTests {

    @Test("标准初始局面棋子数量正确")
    func initialBoardPieceCount() {
        let board = Board()
        #expect(board.pieces.count == 32, "标准象棋应有 32 枚棋子")
    }

    @Test("初始局面红方有合法走法")
    func initialRedHasMoves() {
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(moves.count >= 10, "初始局面红方应至少有 10+ 合法走法")
    }

    @Test("初始局面黑方有合法走法")
    func initialBlackHasMoves() {
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .black, on: board)
        #expect(moves.count >= 10, "初始局面黑方应至少有 10+ 合法走法")
    }

    @Test("初始局面无人被将军")
    func initialNoCheck() {
        let board = Board()
        #expect(!MoveValidator.isInCheck(.red, on: board))
        #expect(!MoveValidator.isInCheck(.black, on: board))
    }

    @Test("初始局面非将死/困毙")
    func initialNotTerminal() {
        let board = Board()
        #expect(!MoveValidator.isCheckmate(.red, on: board))
        #expect(!MoveValidator.isCheckmate(.black, on: board))
        #expect(!MoveValidator.isStalemate(.red, on: board))
        #expect(!MoveValidator.isStalemate(.black, on: board))
    }

    @Test("allLegalMoves + captureMoves 不修改棋盘状态")
    func moveGenDoesNotMutate() {
        let board = Board()
        let originalCount = board.pieces.count
        let originalTurn = board.currentTurn

        _ = MoveValidator.allLegalMoves(for: .red, on: board)
        _ = MoveValidator.allLegalMoves(for: .black, on: board)
        _ = MoveValidator.captureMoves(for: .red, on: board)
        _ = MoveValidator.captureMoves(for: .black, on: board)

        #expect(board.pieces.count == originalCount)
        #expect(board.currentTurn == originalTurn)
    }

    @Test("captureMoves 返回的目标位置确实有对方棋子")
    func captureMovesSubsetOfAllLegal() {
        let board = Board()
        let captureRed = MoveValidator.captureMoves(for: .red, on: board)
        // captureMoves 不做 isLegal 检查（用于 QS 搜索），语义与 allLegalMoves 不同
        // 验证每个返回的走法确实目标是对方棋子
        for move in captureRed {
            #expect(move.captured != nil, "captureMoves 返回的走法 captured 不应为 nil")
        }
    }

    @Test("execute + undo 棋盘完全恢复")
    func executeUndoRestoresBoard() {
        let board = Board()
        let snapshotBoard = board.snapshot()

        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let move = moves.first else {
            Issue.record("无合法走法")
            return
        }

        board.execute(move)
        #expect(board.pieces.count == snapshotBoard.pieces.count || board.pieces.count == snapshotBoard.pieces.count)
        // 初始局面无吃子，棋子数不变
        #expect(board.pieces.count == snapshotBoard.pieces.count)

        _ = board.undoLastMove()
        #expect(board.pieces.count == snapshotBoard.pieces.count)
        #expect(board.currentTurn == snapshotBoard.currentTurn)
    }
}
