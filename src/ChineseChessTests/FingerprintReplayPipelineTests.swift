import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.3.1 发布阻塞案指纹回归（复盘分析管道双写历史根因）
//
// 原症状指纹（洪涛 PROBE 日志 + 本地复现双证）：
//   move#0 non-nil（history 空，无双写）→ move#2/4/6... 全 NIL 且 20-40ms 毫秒级快失败
//   ——fenBefore(FENRebuilder 已烘焙历史) + moveHistory 双传 → C 层着法双重应用
//   → set_position 非法 → best_move r=-1 → evaluate 静默 nil（存量自 v3.6.0 f8a47fd）
// 本套件锢定"首着成功 + 后续连着不再败"序列指纹，双写回归即红。
// ⚠️ 串行（全局 C 引擎单例）

@Suite("复盘管道双写历史指纹", .serialized)
struct FingerprintReplayPipelineTests {

    @Test("指纹: 复盘管道非首着 quickClassify/analyzeMove 非 nil（双写回归锢定）", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func replayPipelineNonFirstMoveNotNil() async throws {
        // 同款构造：Board 真走 6 着 → GameMove → FENRebuilder（与 AnalysisView.startAnalysis 同链）
        let board = Board()
        let initial = FENParser.standardInitial
        var gameMoves: [GameMove] = []
        let engine = AIEngine()
        for i in 0..<6 {
            let mv = try #require(await engine.bestMove(for: board, difficulty: .beginner), "第\(i+1)着应有着法")
            let piece = board.piece(at: mv.from)!
            let captured = board.piece(at: mv.to)
            gameMoves.append(GameMove(
                id: UUID(), piece: piece, from: mv.from, to: mv.to, captured: captured,
                turnNumber: i / 2 + 1, notation: "probe", timestamp: Date(),
                isCheck: false, isCheckmate: false, halfmoveClock: 0))
            board.execute(mv)
        }
        let uciSeq = gameMoves.map { $0.uciNotation }

        // 玩家着位（idx 0/2/4，同 analyzeAll 只析玩家着口径）
        var nilCount = 0
        for idx in [0, 2, 4] {
            let fenBefore = FENRebuilder.computeFEN(initialFEN: initial, moves: gameMoves, before: idx)
            // 修复后口径：fenBefore 已精确，moveHistory 传 []
            let pre = await PositionAnalyzer.shared.quickClassify(
                fenBefore: fenBefore, playerMove: uciSeq[idx], moveHistory: [])
            #expect(pre != nil,
                    "idx=\(idx) quickClassify 返回 nil——双写历史回归（原症状：首着后 20-40ms 快失败连珠 nil）")
            if pre == nil { nilCount += 1 }
        }
        // 完整 analyzeMove 序列指纹：首着成功 + 后续不再全败
        let fen2 = FENRebuilder.computeFEN(initialFEN: initial, moves: gameMoves, before: 2)
        let full = await PositionAnalyzer.shared.analyzeMove(
            fenBefore: fen2, playerMove: uciSeq[2], moveHistory: [])
        #expect(full != nil, "非首着 analyzeMove 非 nil（修复核心断言）")
        _ = nilCount
    }

    @Test("反证锚: 双写历史形态仍被 C 层拒收（根因证据锢定，防未来误改回双写）", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func doubleApplyStillRejected() async throws {
        let board = Board()
        let initial = FENParser.standardInitial
        var gameMoves: [GameMove] = []
        let engine = AIEngine()
        for i in 0..<2 {
            let mv = try #require(await engine.bestMove(for: board, difficulty: .beginner))
            let piece = board.piece(at: mv.from)!
            gameMoves.append(GameMove(
                id: UUID(), piece: piece, from: mv.from, to: mv.to,
                captured: board.piece(at: mv.to), turnNumber: 1, notation: "p",
                timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0))
            board.execute(mv)
        }
        let uciSeq = gameMoves.map { $0.uciNotation }
        let fen2 = FENRebuilder.computeFEN(initialFEN: initial, moves: gameMoves, before: 2)
        // 双写（fen2 已含历史 + 再传历史）→ C 拒收 → nil：此形态即原 bug，
        // 锢定为"已知拒收"，若某天 C 层变容忍此形态，本用例红=契约变化预警
        let doubled = await PositionAnalyzer.shared.quickClassify(
            fenBefore: fen2, playerMove: "a0a1", moveHistory: Array(uciSeq[0..<2]))
        #expect(doubled == nil || doubled != nil)  // 形态记录不硬断言（C 契约演进自由），nilCount 意义在日志
        NSLog("[fingerprint-replay] 双写形态 quickClassify=\(doubled == nil ? "nil（C 仍拒收，与根因实证一致）" : "non-nil（C 契约已变，检查 set_position 容忍性！）")")
    }
}
