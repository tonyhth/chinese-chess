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
        for idx in [0, 2, 4] {
            let fenBefore = FENRebuilder.computeFEN(initialFEN: initial, moves: gameMoves, before: idx)
            // 修复后口径：fenBefore 已精确，moveHistory 传 []
            let pre = await PositionAnalyzer.shared.quickClassify(
                fenBefore: fenBefore, playerMove: uciSeq[idx], moveHistory: [])
            #expect(pre != nil,
                    "idx=\(idx) quickClassify 返回 nil——双写历史回归（原症状：首着后 20-40ms 快失败连珠 nil）")
        }
        // 完整 analyzeMove 序列指纹：首着成功 + 后续不再全败
        let fen2 = FENRebuilder.computeFEN(initialFEN: initial, moves: gameMoves, before: 2)
        let full = await PositionAnalyzer.shared.analyzeMove(
            fenBefore: fen2, playerMove: uciSeq[2], moveHistory: [])
        #expect(full != nil, "非首着 analyzeMove 非 nil（修复核心断言）")
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
        // 双写（fen2 已含历史 + 再传历史）→ C 拒收 → nil：此形态即原 bug。
        // Ruby P2①：纯 NSLog 探针（无 #expect——恒真断言 D4 同族，不污染 pass 计数）；
        // 若某天 C 层变容忍此形态，日志非 nil = 契约变化预警
        let doubled = await PositionAnalyzer.shared.quickClassify(
            fenBefore: fen2, playerMove: "a0a1", moveHistory: Array(uciSeq[0..<2]))
        NSLog("[fingerprint-replay] 双写形态 quickClassify=\(doubled == nil ? "nil（C 仍拒收，与根因实证一致）" : "non-nil（C 契约已变，检查 set_position 容忍性！）")")
    }

    // ---------- 评估面两触发形态（Luke 裁定：红 2 玩家着 / 黑 1 玩家着各一） ----------

    @Test("指纹: 评估面红方第 2 玩家着非 nil（AssessmentSession 构造同款）", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func assessmentRedSecondPlayerMove() async throws {
        let analyzer = PositionAnalyzer.shared
        let board = Board()  // 红先，玩家=红
        let engine = AIEngine()
        // AssessmentSession 同款：棋盘执行式推进 + FENParser.generate 精确 fenBefore
        for _ in 0..<3 {  // 红黑红三着后 = 红方第 2 玩家着位（原 bug 触发形态①）
            let mv = try #require(await engine.bestMove(for: board, difficulty: .beginner))
            board.execute(mv)
        }
        let fenBefore = FENParser.generate(board: board)
        let mv4 = try #require(await engine.bestMove(for: board, difficulty: .beginner))
        let analysis = await analyzer.analyzeMoveLite(
            fenBefore: fenBefore, playerMove: uciFrom(mv4), moveHistory: [],
            depth: 8, timeMs: 300, multiPVCount: 2)
        #expect(analysis != nil, "红方第 2 玩家着评估非 nil（原 bug：currentBoard 精确 FEN + 全量历史双写 → 静默 nil）")
    }

    @Test("指纹: 评估面对手先手黑方第 1 玩家着非 nil", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func assessmentBlackFirstPlayerMove() async throws {
        let analyzer = PositionAnalyzer.shared
        let board = Board()
        board.setCurrentTurn(.black)  // 对手先手场景：黑先走一着（对手），随后红方第 1 玩家着即触发
        let engine = AIEngine()
        let oppo = try #require(await engine.bestMove(for: board, difficulty: .beginner))
        board.execute(oppo)  // 对手先手着入盘
        let fenBefore = FENParser.generate(board: board)
        let player = try #require(await engine.bestMove(for: board, difficulty: .beginner))
        let analysis = await analyzer.analyzeMoveLite(
            fenBefore: fenBefore, playerMove: uciFrom(player), moveHistory: [],
            depth: 8, timeMs: 300, multiPVCount: 2)
        #expect(analysis != nil, "对手先手后玩家第 1 着评估非 nil（原 bug：黑方第 1 玩家着即双写触发）")
    }

    /// UCI 坐标换算对齐 GameMove.uciNotation（rank = 9 - row）
    private func uciFrom(_ move: Move) -> String {
        let cols = Array("abcdefghi")
        return String(cols[move.from.col]) + String(9 - move.from.row)
             + String(cols[move.to.col]) + String(9 - move.to.row)
    }
}
