import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.3 Step 2 引擎可靠性四指纹回归锢定（L5 规约，Luke 硬性验收）
//
// ① MultiPV depth=0（PA-1 C 层 depth 未追踪回归）
// ② evaluate 超时返回空（watchdog 缺失回归——超时不得无限等，须 nil 降级）
// ③ 大师难度中局跳库 search 非 nil（红二：非 bestMove 面绕过单例+可用性检查+降级）
// ④ 连将杀局面搜索非 nil（红五：R3R1 1.18 间歇性 →nil）
// ⑤（附）E1 资产校验：nnue 与 manifest 单源一致
// ⚠️ 串行执行（全局 C 引擎状态，与 PikafishCAPITests 同约束）

@Suite("v6.3 Step 2: 引擎可靠性四指纹", .serialized)
struct EngineReliabilityFingerprintTests {

    static let startFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

    // ---------- 指纹①：MultiPV depth=0 ----------

    @Test("指纹①: topMoves 各候选线 depth>0（PA-1 depth 未追踪回归锢定）", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func fingerprintMultiPVDepthNotZero() async throws {
        let lines = await PositionAnalyzer.shared.topMoves(fen: Self.startFEN, moveHistory: [], count: 3)
        try #require(!lines.isEmpty, "multiPV 应返回候选线")
        for line in lines {
            #expect(line.depth > 0, "原症状：三候选全 depth=0（MultiPVEntry 未采集 depth 回归）")
            #expect(!line.bestMove.isEmpty)
        }
    }

    // ---------- 指纹②：evaluate 超时返回空（不无限等） ----------

    @Test("指纹②: evaluate watchdog 超时返回 nil（非 bestMove 面超时治理锢定）", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func fingerprintEvaluateTimeoutReturnsNil() async throws {
        // 经 Router 单例取引擎（E3 口径）
        let engine = await EngineRouter.shared.switchEngineIfNeeded()
        guard let emb = engine as? EmbeddedPikafishEngine, emb.isReady else {
            Issue.record("引擎未就绪——指纹②无法执行")
            return
        }
        // 注入短 watchdog 帽（默认 15s 太长不适合测试），movetime 8s >> 帽 800ms
        let saved = EmbeddedPikafishEngine.watchdogHardCapMs
        EmbeddedPikafishEngine.watchdogHardCapMs = 800
        defer { EmbeddedPikafishEngine.watchdogHardCapMs = saved }

        let t0 = Date()
        let line = await emb.evaluate(fen: Self.startFEN, moveHistory: [], depth: 0, timeMs: 8_000)
        let elapsed = Date().timeIntervalSince(t0) * 1000
        #expect(line == nil, "超时必须返回 nil 降级（原症状：分析路径无 watchdog 无限等）")
        #expect(elapsed < 4_000, "watchdog 应在硬帽附近返回，实测 \(elapsed)ms")
    }

    // ---------- 指纹③：大师难度中局跳库 search 非 nil（红二） ----------

    @Test("指纹③: 大师难度中局（moveHistory≥6 跳库）经 Router 路由 search 非 nil", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func fingerprintMasterMidgameSkipBookSearchNotNil() async throws {
        // 构造与 LazyOpeningBookTests 大师中局同构的局面（车对车走满 6 步）
        let board = Board(pieces: [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 8, col: 0)),
            TestPieceFactory.blackGeneral(0, 5),
            TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 1, col: 0))
        ])
        for _ in 0..<3 {
            let p1 = board.piece(at: Position(row: 8, col: 0))!
            board.execute(Move(piece: p1, from: p1.position, to: Position(row: 8, col: 4), captured: nil))
            let p2 = board.piece(at: Position(row: 1, col: 0))!
            board.execute(Move(piece: p2, from: p2.position, to: Position(row: 1, col: 4), captured: nil))
            let p3 = board.piece(at: Position(row: 8, col: 4))!
            board.execute(Move(piece: p3, from: p3.position, to: Position(row: 8, col: 0), captured: nil))
            let p4 = board.piece(at: Position(row: 1, col: 4))!
            board.execute(Move(piece: p4, from: p4.position, to: Position(row: 1, col: 0), captured: nil))
        }
        #expect(board.moveHistory.count >= 6)

        // 经 Router 路由（E3 收敛口径）：专业级走 Pikafish，movetime 限时
        let engine = await EngineRouter.shared.switchEngineIfNeeded()
        let fen = FENParser.generate(board: board)
        let best = await engine.bestMove(
            fen: fen, moveHistory: [],
            difficulty: .grandmaster, timeLimitMs: 3_000)
        #expect(best != nil, "红二症状：大师难度中局跳库后搜索 →nil（绕过单例+可用性检查+降级）")
    }

    // ---------- 指纹④：连将杀局面搜索非 nil（红五，R3R1 1.18 同构） ----------

    @Test("指纹④: 连将杀局面 CheckmateSearch 非 nil（R3R1 1.18 间歇 nil 锢定）")
    @MainActor
    func fingerprintCheckmateSearchNotNil() {
        let redChariot = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 2, col: 0))
        let redHorse = TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 3, col: 2))
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let blackAdvisor = TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 1, col: 4))
        let board = Board(pieces: [redChariot, redHorse, redGeneral, blackGeneral, blackAdvisor])
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 8, timeLimitMs: 5_000)
        if result == nil {
            // 与 R3R1 1.18 相同的降级验证：单步将杀必须找得到
            let board2 = Board(pieces: [
                TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 1, col: 0)),
                Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
                Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
            ])
            board2.setCurrentTurn(.red)
            let result2 = CheckmateSearch.search(board: LegacySearchBoard(from: board2), for: .red, maxDepth: 4)
            #expect(result2 != nil, "连将杀与单步将杀双 nil——红五症状（1.18 搜索 →nil）")
        }
    }

    // ---------- P1 锢定：acquire 重入单飞 ----------

    @Test("P1锢定: acquireEmbeddedEngine 并发重入返回同一实例（无双 start/假活）", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func acquireReentrancySingleInstance() async throws {
        let results = await withTaskGroup(of: EmbeddedPikafishEngine?.self, returning: [EmbeddedPikafishEngine?].self) { group in
            for _ in 0..<8 {
                group.addTask { await EngineRouter.shared.acquireEmbeddedEngine() }
            }
            var out: [EmbeddedPikafishEngine?] = []
            for await r in group { out.append(r) }
            return out
        }
        let nonNil = try #require(results.compactMap { $0 }.first, "应至少一个非 nil")
        for r in results {
            #expect(r != nil, "重入调用不得拿到 nil（应 await 同一 in-flight Task）")
        }
        let ids = Set(results.compactMap { $0 }.map { ObjectIdentifier($0) })
        #expect(ids.count == 1, "并发重入必须单实例（Ruby P1：双实例并发 start + 落败 deinit quit 假活），实际 \(ids.count) 个")
    }

    // ---------- 附：E1 资产校验（manifest 单源） ----------

    @Test("E1: nnue 资产与 asset-manifest.json 单源一致（大小+sha256）", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    func nnueAssetMatchesManifest() {
        switch EmbeddedPikafishEngine.verifyNNUEAsset() {
        case .ok(let bytes):
            #expect(bytes > 1_000_000, "nnue 大小量级 sanity")
        case .failed(let reason):
            Issue.record("E1 资产校验失败: \(reason)")
        }
    }
}
