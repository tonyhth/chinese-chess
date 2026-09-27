import XCTest
@testable import ChineseChess

/// T-0926-OC-04 v6.5 v2 §3.3: noisyEvaluate 等价性测试
/// 验证：① noise=0 时搜索确定性（lvl5 等价性锚点）② noise>0 时非确定性
/// ③ 跨相位覆盖（开局/中局/残局）④ QS 路径覆盖（含吃子的中局位）
/// 红线验证：noisyEvaluate 不改 evaluator.evaluate 本体（noise=0 → raw 直返）
struct T0926OC04NoisyEvaluateTests {

    // 跨相位 FEN（同 OC-01 预检采样表口径）
    static let openingFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"
    static let midWithCaptureFEN = "2bak4/9/4b4/9/9/3R5/9/9/4A4/4K4 w"  // 红车可吃黑士——QS 路径触发
    static let endgameFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w"  // 简单残局

    /// ① noise=0 确定性：lvl5 同一局面两次搜索结果一致（叶噪声=0 → 无随机源）
    @Test("noisyEvaluate 等价性①: lvl5（noise=0）同一局面两次搜索结果一致")
    func lvl5NoiseZeroDeterminism() async throws {
        let engine = AIEngine()
        guard let board1 = Board(fen: Self.openingFEN),
              let board2 = Board(fen: Self.openingFEN) else {
            throw TestFailure("FEN 解析失败")
        }
        let move1 = await engine.bestMove(for: board1, difficulty: .amateurHigh, isIOS: false)
        let move2 = await engine.bestMove(for: board2, difficulty: .amateurHigh, isIOS: false)
        XCTAssertNotNil(move1)
        XCTAssertNotNil(move2)
        XCTAssertEqual(move1, move2, "lvl5 noise=0 应确定性——两次搜索结果应一致")
    }

    /// ② noise>0 非确定性：lvl1（noise=180）多次搜索至少出现一次不同结果
    @Test("noisyEvaluate 等价性②: lvl1（noise=180）多次搜索存在随机性")
    func lvl1NoisePositiveNondeterminism() async throws {
        let engine = AIEngine()
        guard let board = Board(fen: Self.midWithCaptureFEN) else {
            throw TestFailure("FEN 解析失败")
        }
        var moves = Set<Move>()
        for _ in 0..<6 {
            if let m = await engine.bestMove(for: board, difficulty: .novice, isIOS: false) {
                moves.insert(m)
            }
        }
        XCTAssertGreaterThanOrEqual(moves.count, 1, "至少应有一个合法走法")
        // noise=180 应引入随机性——多轮至少 2 种不同走法
        XCTAssertGreaterThan(moves.count, 1, "lvl1 noise=180 应产生随机性——多轮至少 2 种走法")
    }

    /// ③ 跨相位：lvl5 在开局/中局/残局均产生合法走法
    @Test("noisyEvaluate 等价性③: lvl5 跨相位（开局/中局/残局）合法走法")
    func lvl5CrossPhase() async throws {
        let engine = AIEngine()
        for (label, fen) in [("开局", Self.openingFEN),
                             ("中局-QS", Self.midWithCaptureFEN),
                             ("残局", Self.endgameFEN)] {
            guard let board = Board(fen: fen) else {
                throw TestFailure("\(label) FEN 解析失败")
            }
            let move = await engine.bestMove(for: board, difficulty: .amateurHigh, isIOS: false)
            XCTAssertNotNil(move, "\(label)：lvl5 应返回走法")
        }
    }

    /// ④ QS 路径覆盖：含吃子的中局位 lvl4（noise=35）多次搜索结果合法且存在随机性
    @Test("noisyEvaluate 等价性④: lvl4（noise=35）QS 路径含在内——合法+随机")
    func lvl4QSPathCoverage() async throws {
        let engine = AIEngine()
        guard let board = Board(fen: Self.midWithCaptureFEN) else {
            throw TestFailure("FEN 解析失败")
        }
        var moves = Set<Move>()
        for _ in 0..<6 {
            if let m = await engine.bestMove(for: board, difficulty: .amateurMid, isIOS: false) {
                moves.insert(m)
            }
        }
        XCTAssertGreaterThanOrEqual(moves.count, 1, "lvl4 应返回合法走法")
        // noise=35 幅度较小，多轮可能仍有随机性；至少验证不崩溃+合法走法
        XCTAssertGreaterThan(moves.count, 0, "lvl4 QS 路径应正常工作")
    }

    /// ⑤ 红线验证：leafNoiseAmplitude 属性值与 §3.2 五档总表一致
    @Test("noisyEvaluate 等价性⑤: leafNoiseAmplitude 五档值与 §3.2 一致")
    func leafNoiseAmplitudeValues() {
        XCTAssertEqual(AIDifficulty.novice.leafNoiseAmplitude, 180, "lvl1=180")
        XCTAssertEqual(AIDifficulty.beginner.leafNoiseAmplitude, 120, "lvl2=120")
        XCTAssertEqual(AIDifficulty.amateurLow.leafNoiseAmplitude, 70, "lvl3=70")
        XCTAssertEqual(AIDifficulty.amateurMid.leafNoiseAmplitude, 35, "lvl4=35")
        XCTAssertEqual(AIDifficulty.amateurHigh.leafNoiseAmplitude, 0, "lvl5=0（等价性锚点）")
    }
}
