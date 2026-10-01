import XCTest
@testable import ChineseChess

/// T-0926-OC-04 v6.5 v2 §3.3: noisyEvaluate 等价性测试（T-1001-2 §Y N-out 对齐：五档噪声全零）
/// 验证：① noise=0 时搜索确定性（lvl5 等价性锚点）② lvl1 噪声归零后确定性（§Y N-out，Luke 10-01 12:57 裁）
/// ③ 跨相位覆盖（开局/中局/残局）④ QS 路径覆盖（含吃子的中局位）
/// ⑤ leafNoiseAmplitude 属性值与 v0.4.2 §Y 五档总表一致（全零锚，断言随 operative spec）
/// 红线验证：noisyEvaluate 不改 evaluator.evaluate 本体（noise=0 → raw 直返）
final class T0926OC04NoisyEvaluateTests: XCTestCase {

    // 跨相位 FEN（同 OC-01 预检采样表口径）
    static let openingFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"
    static let midWithCaptureFEN = "2bak4/9/4b4/9/9/3R5/9/9/4A4/4K4 w"  // 红车可吃黑士——QS 路径触发
    static let endgameFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w"  // 简单残局

    /// 辅助：将 Move 转为可比较的字符串键（Move 非 Hashable）
    private static func moveKey(_ m: Move) -> String {
        "\(m.from.row),\(m.from.col)->\(m.to.row),\(m.to.col)"
    }

    /// ① noise=0 确定性：lvl5 同一局面两次搜索结果一致（叶噪声=0 → 无随机源）
    /// T-1001-2：setenv 注入大预算隔离时间边界抖动——本用例验证噪声通道确定性，非预算行为
    ///（满开局位 depth 完成边界在 2000ms 护栏下随时钟截断抖动：三批跑两红一绿实证，
    ///  首轮 partial 收下条款使截断点进结果；注入通道 ZD-A' 现成，runner 每套件独立进程无跨套件污染）
    func testLvl5NoiseZeroDeterminism() async {
        setenv("SELFPLAY_DET_BUDGET_MS", "8000", 1)
        defer { unsetenv("SELFPLAY_DET_BUDGET_MS") }

        let engine1 = AIEngine()
        let engine2 = AIEngine()
        let board1 = Board(fen: Self.openingFEN)
        let board2 = Board(fen: Self.openingFEN)

        let move1 = await engine1.bestMove(for: board1, difficulty: .amateurHigh, isIOS: false)
        let move2 = await engine2.bestMove(for: board2, difficulty: .amateurHigh, isIOS: false)

        XCTAssertNotNil(move1, "lvl5 第一次搜索应返回走法")
        XCTAssertNotNil(move2, "lvl5 第二次搜索应返回走法")
        XCTAssertEqual(move1, move2, "lvl5 noise=0 应确定性——两次搜索结果应一致")
    }

    /// ② §Y N-out：lvl1 噪声归零（180→0）后确定性——多轮同结果（断言随 operative spec，T-1001-2）
    func testLvl1NoiseZeroDeterminism() async {
        let engine = AIEngine()
        let board = Board(fen: Self.openingFEN)

        var moveKeys = Set<String>()
        for _ in 0..<10 {
            if let m = await engine.bestMove(for: board, difficulty: .novice, isIOS: false) {
                moveKeys.insert(Self.moveKey(m))
            }
        }
        XCTAssertGreaterThanOrEqual(moveKeys.count, 1, "至少应有一个合法走法")
        // noise=0（§Y N-out 全零）→ 搜索确定性——多轮同走法
        XCTAssertEqual(moveKeys.count, 1, "lvl1 noise=0（§Y N-out）应确定性——多轮同走法（实际: \(moveKeys)）")
    }

    /// ③ 跨相位：lvl5 在开局/中局/残局均产生合法走法
    func testLvl5CrossPhase() async {
        let engine = AIEngine()
        let cases: [(String, String)] = [
            ("开局", Self.openingFEN),
            ("中局-QS", Self.midWithCaptureFEN),
            ("残局", Self.endgameFEN),
        ]
        for (label, fen) in cases {
            let board = Board(fen: fen)
            let move = await engine.bestMove(for: board, difficulty: .amateurHigh, isIOS: false)
            XCTAssertNotNil(move, "\(label)：lvl5 应返回走法")
        }
    }

    /// ④ QS 路径覆盖：含吃子的中局位 lvl4（noise=35）多次搜索结果合法且存在随机性
    func testLvl4QSPathCoverage() async {
        let engine = AIEngine()
        let board = Board(fen: Self.midWithCaptureFEN)

        var moveKeys = Set<String>()
        for _ in 0..<6 {
            if let m = await engine.bestMove(for: board, difficulty: .amateurMid, isIOS: false) {
                moveKeys.insert(Self.moveKey(m))
            }
        }
        XCTAssertGreaterThanOrEqual(moveKeys.count, 1, "lvl4 应返回合法走法")
        // noise=35 幅度较小，多轮可能仍有随机性；至少验证不崩溃+合法走法
        XCTAssertGreaterThan(moveKeys.count, 0, "lvl4 QS 路径应正常工作")
    }

    /// ⑤ 红线验证：leafNoiseAmplitude 属性值与 v0.4.2 §Y 五档总表一致（全零锚，T-1001-2 spec 对齐）
    func testLeafNoiseAmplitudeValues() {
        XCTAssertEqual(AIDifficulty.novice.leafNoiseAmplitude, 0, "lvl1=0（§Y N-out）")
        XCTAssertEqual(AIDifficulty.beginner.leafNoiseAmplitude, 0, "lvl2=0（§Y N-out）")
        XCTAssertEqual(AIDifficulty.amateurLow.leafNoiseAmplitude, 0, "lvl3=0（§Y N-out）")
        XCTAssertEqual(AIDifficulty.amateurMid.leafNoiseAmplitude, 0, "lvl4=0（§Y N-out）")
        XCTAssertEqual(AIDifficulty.amateurHigh.leafNoiseAmplitude, 0, "lvl5=0（等价性锚点）")
    }
}
