import Testing
import Foundation
@testable import ChineseChess

// MARK: - NotationGenerator 测试

@Suite("NotationGenerator Tests")
struct NotationGeneratorTests {

    // MARK: - 红方基本走法

    @Test("红炮二平五")
    func testRedCannonHorizontal() {
        let board = Board()
        // 红炮 col=7 → 纵线二, 移到 col=4 → 纵线五
        let piece = board.piece(at: Position(row: 7, col: 7))!
        let move = Move(piece: piece, from: Position(row: 7, col: 7), to: Position(row: 7, col: 4), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "炮二平五")
    }

    @Test("红馬八进七")
    func testRedHorseForward() {
        let board = Board()
        // 红马 col=1 → 纵线八, 移到 col=2 → 纵线七（斜走，目标=纵线号）
        let piece = board.piece(at: Position(row: 9, col: 1))!
        let move = Move(piece: piece, from: Position(row: 9, col: 1), to: Position(row: 7, col: 2), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "馬八进七")
    }

    @Test("红車九进四")
    func testRedChariotForward() {
        let board = Board()
        // 红车 col=0 → 纵线九, 进4格（直线走子，目标=格数）
        let piece = board.piece(at: Position(row: 9, col: 0))!
        let move = Move(piece: piece, from: Position(row: 9, col: 0), to: Position(row: 5, col: 0), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "車九进四")
    }

    @Test("红兵五进一")
    func testRedSoldierForward() {
        let board = Board()
        // 红兵 col=4 → 纵线五, 进1格
        let piece = board.piece(at: Position(row: 6, col: 4))!
        let move = Move(piece: piece, from: Position(row: 6, col: 4), to: Position(row: 5, col: 4), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "兵五进一")
    }

    @Test("红仕进斜线")
    func testRedAdvisorForward() {
        let board = Board()
        // 红仕 col=3 → 纵线六, 进到 col=4 → 纵线五（斜走）
        // 红仕在 (9,3), 纵线六; 进到 (8,4), 纵线五
        let piece = board.piece(at: Position(row: 9, col: 3))!
        let move = Move(piece: piece, from: Position(row: 9, col: 3), to: Position(row: 8, col: 4), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "仕六进五")
    }

    // MARK: - 黑方基本走法

    @Test("黑马8进7")
    func testBlackHorseForward() {
        let board = Board()
        // 黑马 col=1 → 纵线8, 移到 col=2 → 纵线7
        let piece = board.piece(at: Position(row: 0, col: 1))!
        let move = Move(piece: piece, from: Position(row: 0, col: 1), to: Position(row: 2, col: 2), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "馬8进7")
    }

    @Test("黑卒5进1")
    func testBlackSoldierForward() {
        let board = Board()
        // 黑卒 col=4 → 纵线5, 进1格
        let piece = board.piece(at: Position(row: 3, col: 4))!
        let move = Move(piece: piece, from: Position(row: 3, col: 4), to: Position(row: 4, col: 4), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "卒5进1")
    }

    @Test("黑車1进2")
    func testBlackChariotForward() {
        let board = Board()
        // 黑车 col=0 → 纵线9, 进2格
        let piece = board.piece(at: Position(row: 0, col: 0))!
        let move = Move(piece: piece, from: Position(row: 0, col: 0), to: Position(row: 2, col: 0), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "車9进2")
    }

    // MARK: - 纵线编号验证

    @Test("红方纵线编号：col 0=九, col 4=五, col 8=一")
    func testRedFileNumbering() {
        let board = Board()
        // 红车 col=0 → 九
        let chariot0 = board.piece(at: Position(row: 9, col: 0))!
        let move0 = Move(piece: chariot0, from: chariot0.position, to: Position(row: 8, col: 0), captured: nil)
        let n0 = NotationGenerator.notation(for: move0, on: board)
        #expect(n0.contains("九"))

        // 红帅 col=4 → 五
        let general = board.piece(at: Position(row: 9, col: 4))!
        let moveG = Move(piece: general, from: general.position, to: Position(row: 8, col: 4), captured: nil)
        let ng = NotationGenerator.notation(for: moveG, on: board)
        #expect(ng.contains("五"))

        // 红车 col=8 → 一
        let chariot8 = board.piece(at: Position(row: 9, col: 8))!
        let move8 = Move(piece: chariot8, from: chariot8.position, to: Position(row: 8, col: 8), captured: nil)
        let n8 = NotationGenerator.notation(for: move8, on: board)
        #expect(n8.contains("一"))
    }

    @Test("黑方纵线编号：col 0=9, col 4=5, col 8=1")
    func testBlackFileNumbering() {
        let board = Board()
        // 黑车 col=0 → 9
        let chariot0 = board.piece(at: Position(row: 0, col: 0))!
        let move0 = Move(piece: chariot0, from: chariot0.position, to: Position(row: 1, col: 0), captured: nil)
        let n0 = NotationGenerator.notation(for: move0, on: board)
        #expect(n0.contains("9"))

        // 黑将 col=4 → 5
        let general = board.piece(at: Position(row: 0, col: 4))!
        let moveG = Move(piece: general, from: general.position, to: Position(row: 1, col: 4), captured: nil)
        let ng = NotationGenerator.notation(for: moveG, on: board)
        #expect(ng.contains("5"))

        // 黑车 col=8 → 1
        let chariot8 = board.piece(at: Position(row: 0, col: 8))!
        let move8 = Move(piece: chariot8, from: chariot8.position, to: Position(row: 1, col: 8), captured: nil)
        let n8 = NotationGenerator.notation(for: move8, on: board)
        #expect(n8.contains("1"))
    }

    // MARK: - 进退方向

    @Test("红方前进=row减小,后退=row增大")
    func testRedForwardBackward() {
        let board = Board()
        let chariot = board.piece(at: Position(row: 9, col: 0))!
        // 进：row 9→5
        let forwardMove = Move(piece: chariot, from: Position(row: 9, col: 0), to: Position(row: 5, col: 0), captured: nil)
        let fn = NotationGenerator.notation(for: forwardMove, on: board)
        #expect(fn.contains("进"))

        // 退：row 5→8（需模拟走后的棋盘）
        var afterBoard = board.snapshot()
        afterBoard.execute(forwardMove)
        let movedChariot = afterBoard.piece(at: Position(row: 5, col: 0))!
        let backwardMove = Move(piece: movedChariot, from: Position(row: 5, col: 0), to: Position(row: 8, col: 0), captured: nil)
        let bn = NotationGenerator.notation(for: backwardMove, on: afterBoard)
        #expect(bn.contains("退"))
    }

    @Test("黑方前进=row增大,后退=row减小")
    func testBlackForwardBackward() {
        let board = Board()
        let chariot = board.piece(at: Position(row: 0, col: 0))!
        // 进：row 0→2
        let forwardMove = Move(piece: chariot, from: Position(row: 0, col: 0), to: Position(row: 2, col: 0), captured: nil)
        let fn = NotationGenerator.notation(for: forwardMove, on: board)
        #expect(fn.contains("进"))
    }

    // MARK: - 消歧义（前后同线）

    @Test("双车同列消歧义 — 红方前車/后車")
    func testRedDoubleChariotDisambiguation() {
        // 构造：红方两个车都在 col=4
        var pieces = Board.initialPieces().filter { !($0.kind == .chariot && $0.side == .red) }
        pieces.append(Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 4), id: UUID()))
        pieces.append(Piece(kind: .chariot, side: .red, position: Position(row: 8, col: 4), id: UUID()))
        let board = Board(pieces: pieces)

        // row=5 的车在前（更靠近黑方），row=8 的车在后
        // 标准：前車五平四（前 + 棋子名 + 纵线 + 动作 + 目标）
        let frontChariot = board.piece(at: Position(row: 5, col: 4))!
        let moveFront = Move(piece: frontChariot, from: Position(row: 5, col: 4), to: Position(row: 5, col: 3), captured: nil)
        let nFront = NotationGenerator.notation(for: moveFront, on: board)
        #expect(nFront.hasPrefix("前"))
        #expect(nFront.contains("車"))
        #expect(nFront.contains("平"))

        let backChariot = board.piece(at: Position(row: 8, col: 4))!
        let moveBack = Move(piece: backChariot, from: Position(row: 8, col: 4), to: Position(row: 7, col: 4), captured: nil)
        let nBack = NotationGenerator.notation(for: moveBack, on: board)
        #expect(nBack.hasPrefix("后"))
        #expect(nBack.contains("車"))
        #expect(nBack.contains("进"))
    }

    @Test("双炮同列消歧义 — 黑方")
    func testBlackDoubleCannonDisambiguation() {
        // 构造只有双炮 + 将帅的最小棋盘
        var pieces: [Piece] = []
        pieces.append(Piece(kind: .general, side: .red, position: Position(row: 9, col: 4)))
        pieces.append(Piece(kind: .general, side: .black, position: Position(row: 0, col: 4)))
        pieces.append(Piece(kind: .cannon, side: .black, position: Position(row: 3, col: 4), id: UUID()))
        pieces.append(Piece(kind: .cannon, side: .black, position: Position(row: 5, col: 4), id: UUID()))
        let board = Board(pieces: pieces)

        // 黑方 row=5 在前（更靠近红方）
        let frontCannon = board.piece(at: Position(row: 5, col: 4))!
        let moveFront = Move(piece: frontCannon, from: Position(row: 5, col: 4), to: Position(row: 6, col: 4), captured: nil)
        let nFront = NotationGenerator.notation(for: moveFront, on: board)
        #expect(nFront.hasPrefix("前"))
        #expect(nFront.contains("砲"))

        let backCannon = board.piece(at: Position(row: 3, col: 4))!
        let moveBack = Move(piece: backCannon, from: Position(row: 3, col: 4), to: Position(row: 4, col: 4), captured: nil)
        let nBack = NotationGenerator.notation(for: moveBack, on: board)
        #expect(nBack.hasPrefix("后"))
        #expect(nBack.contains("砲"))
    }

    // MARK: - 无消歧义时无前/后前缀

    @Test("单子无消歧义前缀")
    func testNoDisambiguationPrefix() {
        let board = Board()
        let chariot = board.piece(at: Position(row: 9, col: 0))!
        let move = Move(piece: chariot, from: Position(row: 9, col: 0), to: Position(row: 8, col: 0), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(!notation.hasPrefix("前"))
        #expect(!notation.hasPrefix("后"))
    }

    // MARK: - 平走

    @Test("红車九平五")
    func testRedChariotHorizontal() {
        let board = Board()
        // 先把车前的路清空（简化测试：直接构造走法）
        let chariot = board.piece(at: Position(row: 9, col: 0))!
        let move = Move(piece: chariot, from: Position(row: 9, col: 0), to: Position(row: 9, col: 4), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "車九平五")
    }

    // MARK: - 边界情况

    @Test("红帅进一")
    func testRedGeneralForward() {
        let board = Board()
        let general = board.piece(at: Position(row: 9, col: 4))!
        let move = Move(piece: general, from: Position(row: 9, col: 4), to: Position(row: 8, col: 4), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation == "帅五进一")
    }

    @Test("红相七进五")
    func testRedElephantForward() {
        let board = Board()
        let elephant = board.piece(at: Position(row: 9, col: 6))!
        let move = Move(piece: elephant, from: Position(row: 9, col: 6), to: Position(row: 7, col: 4), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)
        // col=6 → 三, col=4 → 五, 斜走目标=纵线号
        #expect(notation == "相三进五")
    }
}

// MARK: - StatsManager 测试

@Suite("StatsManager Tests")
struct StatsManagerTests {

    /// 每个测试用独立的 UserDefaults，避免并行测试竞争
    private func makeManager() -> StatsManager {
        let suiteName = "test.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return StatsManager(defaults: defaults)
    }

    @Test("初始统计为零")
    func testInitialStats() {
        let manager = makeManager()
        let stats = manager.stats
        #expect(stats.vsAI.isEmpty)
        #expect(stats.pvp.totalGames == 0)
    }

    @Test("记录人机胜利")
    func testRecordAIWin() {
        let manager = makeManager()

        manager.recordWin(for: .medium)
        let stats = manager.stats
        let medium = stats.vsAI["medium", default: WinLossDraw()]
        #expect(medium.wins == 1)
        #expect(medium.losses == 0)
    }

    @Test("记录多局人机")
    func testMultipleAIGames() {
        let manager = makeManager()

        // 验证初始为空
        let stats0 = manager.stats
        #expect(stats0.vsAI.isEmpty)

        manager.recordWin(for: .hard)

        let stats1 = manager.stats
        let hard1 = stats1.vsAI["hard", default: WinLossDraw()]
        #expect(hard1.wins == 1)

        manager.recordWin(for: .hard)
        manager.recordLoss(for: .hard)

        let stats2 = manager.stats
        let hard2 = stats2.vsAI["hard", default: WinLossDraw()]
        #expect(hard2.wins == 2)
        #expect(hard2.losses == 1)
    }

    @Test("记录人人对战")
    func testPVPStats() {
        let manager = makeManager()

        manager.recordPVPGame(draw: false)
        manager.recordPVPGame(draw: true)

        let stats = manager.stats
        #expect(stats.pvp.totalGames == 2)
        #expect(stats.pvp.draws == 1)
    }

    @Test("重置清空统计")
    func testReset() {
        let manager = makeManager()
        manager.recordWin(for: .beginner)
        manager.reset()
        let stats = manager.stats
        #expect(stats.vsAI.isEmpty)
    }
}

// MARK: - GameMode + 人人对战测试

@Suite("GameViewModel Phase 3 Tests")
struct GameViewModelPhase3Tests {

    @Test("人人对战模式切换")
    func testGameModeSwitch() {
        let vm = GameViewModel()
        #expect(vm.gameMode == .singlePlayer)

        vm.setGameMode(.localPVP)
        #expect(vm.gameMode == .localPVP)
        #expect(vm.gameState == .playing)
        #expect(vm.gameMoves.isEmpty)
    }

    @Test("人人对战中双方都能走棋")
    func testPVPBothSidesMove() {
        let vm = GameViewModel()
        vm.setGameMode(.localPVP)

        // 红方走棋
        let redPiece = vm.board.piece(at: Position(row: 6, col: 4))!
        let redMove = Move(piece: redPiece, from: redPiece.position, to: Position(row: 5, col: 4), captured: nil)
        vm.selectPiece(at: Position(row: 6, col: 4))
        vm.movePiece(from: Position(row: 6, col: 4), to: Position(row: 5, col: 4))
        #expect(vm.gameMoves.count == 1)
        #expect(vm.gameMoves[0].piece.side == .red)

        // 黑方走棋
        let blackPiece = vm.board.piece(at: Position(row: 3, col: 4))!
        vm.selectPiece(at: Position(row: 3, col: 4))
        vm.movePiece(from: Position(row: 3, col: 4), to: Position(row: 4, col: 4))
        #expect(vm.gameMoves.count == 2)
        #expect(vm.gameMoves[1].piece.side == .black)
    }

    @Test("人人对战悔棋只撤一步")
    func testPVPUndoOneStep() {
        let vm = GameViewModel()
        vm.setGameMode(.localPVP)

        vm.selectPiece(at: Position(row: 6, col: 4))
        vm.movePiece(from: Position(row: 6, col: 4), to: Position(row: 5, col: 4))
        #expect(vm.gameMoves.count == 1)

        vm.undoMove()
        #expect(vm.gameMoves.isEmpty)
        #expect(vm.board.moveHistory.isEmpty)
    }

    @Test("人机模式悔棋撤一对")
    func testSinglePlayerUndoPair() {
        let vm = GameViewModel()
        // 直接通过 board 走棋模拟（不走 AI）
        let redPiece = vm.board.piece(at: Position(row: 6, col: 4))!
        let redMove = Move(piece: redPiece, from: redPiece.position, to: Position(row: 5, col: 4), captured: nil)
        vm.board.execute(redMove)
        vm.gameMoves.append(GameMove(id: UUID(), piece: redPiece, from: redPiece.position, to: Position(row: 5, col: 4), captured: nil, turnNumber: 1, notation: "兵五进一", timestamp: Date(), isCheck: false, isCheckmate: false))

        // 模拟 AI 走了一步
        let blackPiece = vm.board.piece(at: Position(row: 3, col: 4))!
        vm.board.execute(Move(piece: blackPiece, from: blackPiece.position, to: Position(row: 4, col: 4), captured: nil))
        vm.gameMoves.append(GameMove(id: UUID(), piece: blackPiece, from: blackPiece.position, to: Position(row: 4, col: 4), captured: nil, turnNumber: 1, notation: "卒5进1", timestamp: Date(), isCheck: false, isCheckmate: false))

        #expect(vm.gameMoves.count == 2)
        #expect(vm.board.moveHistory.count == 2)

        vm.undoMove()
        #expect(vm.gameMoves.isEmpty)
        #expect(vm.board.moveHistory.isEmpty)
    }

    @Test("GameMove 记录包含棋谱")
    func testGameMoveHasNotation() {
        let vm = GameViewModel()
        vm.selectPiece(at: Position(row: 6, col: 4))
        vm.movePiece(from: Position(row: 6, col: 4), to: Position(row: 5, col: 4))

        #expect(vm.gameMoves.count >= 1)
        #expect(!vm.gameMoves[0].notation.isEmpty)
        #expect(vm.gameMoves[0].notation == "兵五进一")
    }

    @Test("人人对战模式下 AI 不触发")
    func testPVPAINotTriggered() {
        let vm = GameViewModel()
        vm.setGameMode(.localPVP)

        vm.selectPiece(at: Position(row: 6, col: 4))
        vm.movePiece(from: Position(row: 6, col: 4), to: Position(row: 5, col: 4))

        // 人人模式：AI 不触发，isThinking 始终 false
        #expect(!vm.isThinking)
        #expect(vm.gameMoves.count == 1)
    }
}
