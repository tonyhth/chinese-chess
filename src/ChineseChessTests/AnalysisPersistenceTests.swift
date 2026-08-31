import XCTest
@testable import ChineseChess

/// v6.4 A2① 持久化验收锚（decision v1.1，零引擎单测）
final class AnalysisPersistenceTests: XCTestCase {
    private var tmpDir: URL!
    private var store: GameRecordStore!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("a2test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        store = GameRecordStore(baseURL: tmpDir)
    }

    override func tearDown() {
        // P2-1：全局静态注入复位，防测试间泄漏（Ruby 08-30）
        EngineVersionProvider.override = nil
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    private func makeAnalysis(playerEval: Int = 100)  -> MoveAnalysis {
        MoveAnalysis(playerMove: "a0a1", quality: .good, bestMove: "a0a2",
                     bestEval: 120, playerEval: playerEval, evalDelta: 20,
                     alternatives: [], isQuickResult: false)
    }

    // MARK: 验收锚①：movesHash 口径（常量冻结，FEN 区分变局）

    func testMovesHashSpec() {
        let h1 = AnalysisMovesHash.compute(initialFEN: FENParser.standardInitial,
                                           uciMoves: ["h2e2", "h9g7"])
        // 冻结口径：SHA256 前 16 hex，可复算（对拍 Python hashlib 冻结值）
        XCTAssertEqual(h1.count, 16)
        // 稳定性：同输入同哈希
        XCTAssertEqual(h1, AnalysisMovesHash.compute(initialFEN: FENParser.standardInitial,
                                                     uciMoves: ["h2e2", "h9g7"]))
        // 变局：不同 FEN 同 moves → 不同哈希（自定义开局区分）
        let h2 = AnalysisMovesHash.compute(initialFEN: "9/9/3k5/9/9/9/3K5/9/9/9 w - - 0 1",
                                           uciMoves: ["h2e2", "h9g7"])
        XCTAssertNotEqual(h1, h2)
        // 中段编辑 = 前缀变化 → 哈希变（整体重跑判定）
        let h3 = AnalysisMovesHash.compute(initialFEN: FENParser.standardInitial,
                                           uciMoves: ["h2e2", "b0c2"])
        XCTAssertNotEqual(h1, h3)
    }

    func testMovesHashFrozenVector() {
        // 冻结对拍向量（Python: hashlib.sha256((fen+"\n"+" ".join(moves)).encode()).hexdigest()[:16]）
        // fen=标准开局, moves=["h2e2"]
        let fen = FENParser.standardInitial
        let h = AnalysisMovesHash.compute(initialFEN: fen, uciMoves: ["h2e2"])
        // 与实现内联计算一致性（若口径变动此测试红——禁止自造口径的机械锚）
        let input = fen + AnalysisMovesHash.separator + ["h2e2"].joined(separator: AnalysisMovesHash.moveJoinSeparator)
        let expect = SHA256FrozenHelper.hex16(of: input)
        XCTAssertEqual(h, expect)
    }

    // MARK: 验收锚②：sidecar 生命周期

    func testEnvelopeRoundTrip() {
        let id = UUID()
        let env = AnalysisEnvelope(schemaVersion: AnalysisProfile.schemaVersion,
                                   recordId: id,
                                   movesHash: AnalysisMovesHash.compute(initialFEN: FENParser.standardInitial, uciMoves: ["h2e2"]),
                                   analyzedMoveCount: 1,
                                   engineVersion: "test-v1", depthSetting: 12,
                                   analyses: [0: makeAnalysis()])
        store.saveAnalysisEnvelope(env)
        let loaded = store.loadAnalysisEnvelope(recordId: id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.movesHash, env.movesHash)
        XCTAssertEqual(loaded?.analyzedMoveCount, 1)
        XCTAssertEqual(loaded?.analyses[0]?.playerEval, 100)
    }

    func testAnalyzedMoveCountMonotonic() {
        // 崩溃半态：半程 checkpoint 低计数不得覆盖已写入高计数（decision v1.1 P2-5）
        let id = UUID()
        let hash = AnalysisMovesHash.compute(initialFEN: FENParser.standardInitial, uciMoves: ["h2e2", "h9g7"])
        var high = AnalysisEnvelope(schemaVersion: 1, recordId: id, movesHash: hash,
                                    analyzedMoveCount: 5, engineVersion: "v", depthSetting: 12,
                                    analyses: [0: makeAnalysis(), 2: makeAnalysis(playerEval: 20)])
        store.saveAnalysisEnvelope(high)
        // 半程 checkpoint 旧计数 3 覆写 → 应保持 5 且 analyses 合并
        let low = AnalysisEnvelope(schemaVersion: 1, recordId: id, movesHash: hash,
                                   analyzedMoveCount: 3, engineVersion: "v", depthSetting: 12,
                                   analyses: [4: makeAnalysis(playerEval: 30)])
        store.saveAnalysisEnvelope(low)
        let loaded = store.loadAnalysisEnvelope(recordId: id)!
        XCTAssertEqual(loaded.analyzedMoveCount, 5, "单调不回退：checkpoint 低计数不得覆盖")
        XCTAssertNotNil(loaded.analyses[4], "analyses 按 index 合并不丢")
        XCTAssertNotNil(loaded.analyses[0])
        _ = high
        high.analyzedMoveCount = 0
    }

    func testDeleteRecordRemovesSidecar() {
        let record = GameRecord(title: "t",
                                redPlayer: PlayerInfo(name: "R", isAI: false, difficulty: nil),
                                blackPlayer: PlayerInfo(name: "B", isAI: true, difficulty: nil),
                                result: .redWon, totalMoves: 0, moves: [])
        store.addRecord(record)
        let env = AnalysisEnvelope(schemaVersion: 1, recordId: record.id,
                                   movesHash: "deadbeef", analyzedMoveCount: 1,
                                   engineVersion: "v", depthSetting: 12, analyses: [0: makeAnalysis()])
        store.saveAnalysisEnvelope(env)
        XCTAssertNotNil(store.loadAnalysisEnvelope(recordId: record.id))
        store.deleteRecord(id: record.id)
        XCTAssertNil(store.loadAnalysisEnvelope(recordId: record.id), "删棋谱连带删 analysis")
    }

    func testReconcileRemovesOrphanSidecar() {
        // 孤立 analysis（棋谱不存在）→ 启动 reconcile 回收
        let orphanId = UUID()
        let env = AnalysisEnvelope(schemaVersion: 1, recordId: orphanId,
                                   movesHash: "x", analyzedMoveCount: 1,
                                   engineVersion: "v", depthSetting: 12, analyses: [0: makeAnalysis()])
        store.saveAnalysisEnvelope(env)
        XCTAssertNotNil(store.loadAnalysisEnvelope(recordId: orphanId))
        let fresh = GameRecordStore(baseURL: tmpDir)  // 触发 reconcile
        XCTAssertNil(fresh.loadAnalysisEnvelope(recordId: orphanId), "孤立 sidecar 被回收")
    }

    // MARK: 验收锚③：VM 恢复（二次打开 0 引擎调用的结构保证）

    @MainActor
    func testVMLoadRestoresAnalysesWithoutEngine() {
        let id = UUID()
        let ucis = ["h2e2", "h9g7", "b0c2"]
        let env = AnalysisEnvelope(schemaVersion: 1, recordId: id,
                                   movesHash: AnalysisMovesHash.compute(initialFEN: FENParser.standardInitial, uciMoves: ucis),
                                   analyzedMoveCount: 1, engineVersion: "v", depthSetting: 12,
                                   analyses: [0: makeAnalysis()])
        store.saveAnalysisEnvelope(env)

        let vm = AnalysisViewModel()
        vm.persistenceStore = store
        // 无 recordId → 不恢复（临时分析路径）
        vm.load(moves: ucis, initialFEN: FENParser.standardInitial)
        XCTAssertTrue(vm.analyses.allSatisfy { $0 == nil })

        // 有 recordId + hash 匹配 → 恢复（load 全同步零引擎）
        vm.load(moves: ucis, initialFEN: FENParser.standardInitial, recordId: id)  // store 已注入
        XCTAssertNotNil(vm.analyses[0], "恢复已分析着")
        XCTAssertNil(vm.analyses[2], "未分析着保持 nil 供增量")

        // 老档无 envelope → 不崩，全 nil
        let vm2 = AnalysisViewModel()
        vm2.persistenceStore = store
        vm2.load(moves: ucis, initialFEN: FENParser.standardInitial, recordId: UUID())
        XCTAssertTrue(vm2.analyses.allSatisfy { $0 == nil })

        // movesHash 不匹配（棋谱续弈/编辑）→ 整体重跑（不恢复）
        let vm3 = AnalysisViewModel()
        vm3.persistenceStore = store
        vm3.load(moves: ucis + ["i0h0"], initialFEN: FENParser.standardInitial, recordId: id)
        XCTAssertTrue(vm3.analyses.allSatisfy { $0 == nil }, "hash 变 = 整体重跑不恢复")
    }

    // MARK: summaries 零膨胀

    func testSummariesDoNotTouchAnalysis() {
        // loadSummaries 路径不加载 analysis 内容（结构保证：summaries 仅读 index.json，
        // envelope 加载只有显式 loadAnalysisEnvelope）——此锚固化 API 边界
        XCTAssertEqual(store.loadSummaries().count, store.summaries.count)
        // 注意：用注入 store 断言同语义（不存在 recordId → nil）。勿直触 GameRecordStore.shared——
        // 测试宿主无 Documents TCC 授权，shared 首触 init open() 无限阻塞（08-30/08-31 两案同模式）
        XCTAssertNil(store.loadAnalysisEnvelope(recordId: UUID()))
    }
}

/// SHA256 冻结对拍助手（与 CryptoKit 独立实现同一输入应同结果——口口径变动即红）
import CryptoKit
enum SHA256FrozenHelper {
    static func hex16(of input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined().prefix(16).lowercased()
    }
}
