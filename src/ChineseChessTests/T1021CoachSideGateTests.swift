import Testing
import Foundation
@testable import ChineseChess

/// T-1021-OC-01 教练执方门修复测试
/// 前置：coachConfig != nil（模拟真实教练会话——coachConfig==nil 时 applyMove 尾部触发主 AI 干扰走子流）
/// a 执红交替 / b 执黑交替（本次暴露盲区）/ 红线：人类路径两道门零触碰 / 教练通道合法性保持
@Suite("T1021 CoachSideGate", .serialized)
struct T1021CoachSideGateTests {

    private func makeCoachConfig(playerSide: Side) -> CoachConfig {
        CoachConfig(
            targetSubcategory: OpeningSubcategory(id: "t1021", name: "中炮对屏风马", firstMoves: ["h2e2"], gameCount: 12),
            aiDifficulty: .amateurLow,
            playerSide: playerSide
        )
    }

    @MainActor
    @Test("a 执红：人类红走→教练黑应答→交替推进")
    func redSideAlternating() {
        let vm = GameViewModel()
        vm.setHumanSide(.red)
        vm.coachConfig = makeCoachConfig(playerSide: .red)

        // 人类红走 兵 (6,0)→(5,0)
        vm.movePiece(from: Position(row: 6, col: 0), to: Position(row: 5, col: 0))
        #expect(vm.gameMoves.count == 1)
        #expect(vm.board.currentTurn == .black)

        // 教练黑应答 makeCoachMove 兵 (3,0)→(4,0)——修复前经 selectPiece+movePiece 人类通道被 L221/L245 双门拒
        vm.makeCoachMove(from: Position(row: 3, col: 0), to: Position(row: 4, col: 0))
        #expect(vm.gameMoves.count == 2)
        #expect(vm.board.currentTurn == .red)

        // 交替推进（兵初始列偶数：0/2/4/6/8——第二组用 col 2）
        vm.movePiece(from: Position(row: 6, col: 2), to: Position(row: 5, col: 2))
        #expect(vm.gameMoves.count == 3)
        #expect(vm.board.currentTurn == .black)
        vm.makeCoachMove(from: Position(row: 3, col: 2), to: Position(row: 4, col: 2))
        #expect(vm.gameMoves.count == 4)
        #expect(vm.board.currentTurn == .red)
    }

    @MainActor
    @Test("b 执黑：AI 红先行→人类黑应答→交替（本次暴露盲区）")
    func blackSideAlternating() {
        let vm = GameViewModel()
        vm.setHumanSide(.black)
        vm.coachConfig = makeCoachConfig(playerSide: .black)

        // AI 红先行 makeCoachMove 兵 (6,0)→(5,0)——修复前同被双门拒（隐藏冻结形态）
        vm.makeCoachMove(from: Position(row: 6, col: 0), to: Position(row: 5, col: 0))
        #expect(vm.gameMoves.count == 1)
        #expect(vm.board.currentTurn == .black)

        // 人类黑应答 兵 (3,0)→(4,0)
        vm.movePiece(from: Position(row: 3, col: 0), to: Position(row: 4, col: 0))
        #expect(vm.gameMoves.count == 2)
        #expect(vm.board.currentTurn == .red)

        // 教练红再走（col 2）
        vm.makeCoachMove(from: Position(row: 6, col: 2), to: Position(row: 5, col: 2))
        #expect(vm.gameMoves.count == 3)
        #expect(vm.board.currentTurn == .black)

        // 人类黑再走（col 2）
        vm.movePiece(from: Position(row: 3, col: 2), to: Position(row: 4, col: 2))
        #expect(vm.gameMoves.count == 4)
        #expect(vm.board.currentTurn == .red)
    }

    @MainActor
    @Test("红线：人类路径两道门零触碰（执方门仍拒异侧走子）")
    func humanGatesIntact() {
        let vm = GameViewModel()
        vm.setHumanSide(.red)
        vm.coachConfig = makeCoachConfig(playerSide: .red)

        // 人类红走+教练黑应答
        vm.movePiece(from: Position(row: 6, col: 0), to: Position(row: 5, col: 0))
        vm.makeCoachMove(from: Position(row: 3, col: 0), to: Position(row: 4, col: 0))
        #expect(vm.gameMoves.count == 2)

        // 门2（movePiece L245）：人类 movePiece 黑子（教练兵在 (4,0)）→ 拒（piece.side != humanSide）
        vm.movePiece(from: Position(row: 4, col: 0), to: Position(row: 5, col: 0))
        #expect(vm.gameMoves.count == 2, "人类执方门应拒黑子走子")

        // 门1（selectPiece L221 同族侧别校验）：人类回合选黑子 → 拒（selectedPosition 保持 nil）
        vm.selectPiece(at: Position(row: 4, col: 0))
        #expect(vm.selectedPosition == nil, "执方门应拒选异侧子")
    }

    @MainActor
    @Test("教练通道合法性保持：非法走子被 applyMove 拒")
    func coachIllegalMoveRejected() {
        let vm = GameViewModel()
        vm.setHumanSide(.black)
        vm.coachConfig = makeCoachConfig(playerSide: .black)

        // 教练红：士 (9,5)→(7,5) 直线移动非法（士限九宫斜线）
        vm.makeCoachMove(from: Position(row: 9, col: 5), to: Position(row: 7, col: 5))
        #expect(vm.gameMoves.count == 0)
        #expect(vm.board.currentTurn == .red, "非法走子不应翻转回合")
    }

    @MainActor
    @Test("教练通道终局态静默：gameState != .playing 时 makeCoachMove 拒（与原 movePiece 通用门语义对齐）")
    func coachMoveSilentOnFinishedGame() {
        let vm = GameViewModel()
        vm.setHumanSide(.black)
        vm.coachConfig = makeCoachConfig(playerSide: .black)
        vm.gameState = .redWon  // 模拟终局

        vm.makeCoachMove(from: Position(row: 6, col: 0), to: Position(row: 5, col: 0))
        #expect(vm.gameMoves.count == 0, "终局态教练走法应被通用门拒")
        #expect(vm.board.currentTurn == .red)
    }
}
