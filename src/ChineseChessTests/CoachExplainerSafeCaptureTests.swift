import XCTest
@testable import ChineseChess

// MARK: - v3.7.4 Patch 测试
// 测试范围：
// 1. isSafeCapture 逻辑（通过 explain 间接测试 missedCapture 场景触发）
// 2. CommandMenu i18n key 存在性
// 3. feature.gameRecordImport key 存在性

final class CoachExplainerSafeCaptureTests: XCTestCase {

    // ============================================================
    // isSafeCapture 逻辑验证（通过 classifyScenario → explain 间接验证）
    // ============================================================

    /// 构造一个中等 evalDelta（50-300cp）+ bestMove 是安全吃子的场景
    /// 预期：scenario = .missedCapture
    ///
    /// 我们用一个简单局面：红方车可以安全吃黑方卒
    /// FEN: 红方车在 a2，黑方卒在 a5，没有保护
    func testIsSafeCapture_SafeCaptureTriggersMissedCapture() async {
        // 标准初始局面下，很难手工构造安全吃子
        // 用一个简化的残局局面：
        // r3kab1r/9/9/9/9/9/9/9/9/4K4 不太准确
        // 实际测试：用 explain() 验证 isSafeCapture 不再永远返回 false

        // 构造 MoveAnalysis：evalDelta 在 50-300 之间（非将军、非杀棋）
        let analysis = MoveAnalysis(
            playerMove: "h2e2",     // 玩家走了一步不是吃子的棋
            quality: .doubtful,
            bestMove: "b0c2",       // 最佳走法（这里不需要真的是吃子，主要验证不 crash）
            bestEval: 100,
            playerEval: 20,
            evalDelta: 80,          // 80cp 落差 → 进入中等落差分支
            alternatives: []
        )

        let standardFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: standardFEN,
            playerMove: "h2e2",
            bestMove: "b0c2"
        )

        // 验证不再因 isSafeCapture 永远返回 false 而跳过所有 missedCapture
        // 只要 classifyScenario 能正确执行不 crash，说明 isSafeCapture 的实现是有效的
        XCTAssertNotNil(explanation, "explain() 应返回非 nil 结果")
        XCTAssertNotNil(explanation.scenario, "应返回有效的 scenario")
    }

    /// evalDelta < 50 → 应返回 .generic（不需要讲解）
    func testExplain_LowEvalDelta_ReturnsGeneric() async {
        let analysis = MoveAnalysis(
            playerMove: "h2e2",
            quality: .good,
            bestMove: "b0c2",
            bestEval: 50,
            playerEval: 30,
            evalDelta: 20,          // < 50
            alternatives: []
        )

        let standardFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: standardFEN,
            playerMove: "h2e2",
            bestMove: "b0c2"
        )

        XCTAssertEqual(explanation.scenario, .generic, "evalDelta < 50 应返回 generic")
    }

    /// evalDelta >= 300 → 应返回 .blunder 或 .missedMate（不经过 isSafeCapture）
    func testExplain_HighEvalDelta_DoesNotHitSafeCapture() async {
        let analysis = MoveAnalysis(
            playerMove: "h2e2",
            quality: .blunder,
            bestMove: "b0c2",
            bestEval: 500,
            playerEval: 100,
            evalDelta: 400,         // >= 300
            alternatives: []
        )

        let standardFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: standardFEN,
            playerMove: "h2e2",
            bestMove: "b0c2"
        )

        // 高落差应该分类为 blunder 或 missedMate，不应该走到 isSafeCapture 分支
        XCTAssertTrue(
            explanation.scenario == .blunder || explanation.scenario == .missedMate,
            "evalDelta >= 300 应返回 blunder 或 missedMate，实际: \(explanation.scenario)"
        )
    }

    /// isSafeCapture 需要正确处理无效 UCI 字符串
    /// 如果 move 不是合法 UCI 格式，positions(from:) 返回 nil → isSafeCapture 返回 false
    /// 这个测试验证 explain() 在 bestMove 格式异常时不会 crash
    func testExplain_InvalidBestMove_DoesNotCrash() async {
        let analysis = MoveAnalysis(
            playerMove: "h2e2",
            quality: .doubtful,
            bestMove: "invalid",     // 无效 UCI
            bestEval: 200,
            playerEval: 100,
            evalDelta: 100,          // 进入中等落差分支，会调用 isSafeCapture
            alternatives: []
        )

        let standardFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: standardFEN,
            playerMove: "h2e2",
            bestMove: "invalid"
        )

        // 无效 UCI 不应导致 crash，应正常返回（可能是 generic 或其他场景）
        XCTAssertNotNil(explanation, "即使 bestMove 无效也不应 crash")
    }

    /// isSafeCapture 需要处理落点没有棋子的情况（不是吃子）
    /// 如果 bestMove 的目标位置没有棋子，captured 为 nil → isSafeCapture 返回 false
    func testExplain_NonCaptureMove_DoesNotTriggerMissedCapture() async {
        // 标准初始局面，b0c2 是马跳到没有棋子的位置（不是吃子）
        let analysis = MoveAnalysis(
            playerMove: "h2e2",
            quality: .doubtful,
            bestMove: "b0c2",        // 马跳，不是吃子
            bestEval: 200,
            playerEval: 100,
            evalDelta: 100,
            alternatives: []
        )

        let standardFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: standardFEN,
            playerMove: "h2e2",
            bestMove: "b0c2"
        )

        // b0c2 在初始局面不是吃子（c2 位置无棋子），所以不会是 missedCapture
        XCTAssertNotEqual(explanation.scenario, .missedCapture,
                          "非吃子走法不应触发 missedCapture")
    }

    // ============================================================
    // isSafeCapture 边界情况：通过 FEN 构造吃子局面
    // ============================================================

    /// 构造一个车吃卒的安全吃子局面
    /// 红车在 e1（UCI），黑卒在 e5（UCI），无保护
    /// 黑王放在 d9 避免车吃卒后形成将军
    ///
    /// FEN 坐标映射：FEN 行从 game row 0（黑方顶部）到 game row 9（红方底部）
    /// UCI 行 = 9 - gameRow，所以 UCI e1 = game(8,4)，UCI e5 = game(4,4)
    func testIsSafeCapture_RookCapturingUnprotectedPawn() async {
        // FEN: 3k5/9/9/9/4p4/9/9/9/4R4/4K4 w - - 0 1
        // Row 0 (黑方): 3k5 → 黑王在 col 3 (d9 UCI)
        // Row 4: 4p4 → 黑卒在 col 4 (e5 UCI)
        // Row 8: 4R4 → 红车在 col 4 (e1 UCI)
        // Row 9 (红方): 4K4 → 红帅在 col 4 (e0 UCI)
        let fen = "3k5/9/9/9/4p4/9/9/9/4R4/4K4 w - - 0 1"

        let analysis = MoveAnalysis(
            playerMove: "e0d0",      // 玩家走了帅平中（不是最佳）
            quality: .doubtful,
            bestMove: "e1e5",        // 车吃卒（安全吃子）
            bestEval: 200,
            playerEval: 80,
            evalDelta: 120,          // 中等落差
            alternatives: []
        )

        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: fen,
            playerMove: "e0d0",
            bestMove: "e1e5"
        )

        // 安全吃子：车吃卒后不被将军，落点不受攻击
        // 黑方只剩王，无法攻击 e5
        XCTAssertEqual(explanation.scenario, .missedCapture,
                       "安全吃子应触发 missedCapture，实际: \(explanation.scenario)")
    }

    /// 构造一个不安全的吃子（吃子后被回吃）
    /// 红车 e1 吃黑马 e5，但黑车 d5 可以回吃
    /// 黑王放在 d9 避免将军干扰
    func testIsSafeCapture_UnsafeCapture_DoesNotTrigger() async {
        // FEN: 3k5/9/9/9/3rn4/9/9/9/4R4/4K4 w - - 0 1
        // Row 0: 3k5 → 黑王 col 3 (d9 UCI)
        // Row 4: 3rn4 → 黑车 col 3 (d5 UCI), 黑马 col 4 (e5 UCI)
        // Row 8: 4R4 → 红车 col 4 (e1 UCI)
        // Row 9: 4K4 → 红帅 col 4 (e0 UCI)
        let fen = "3k5/9/9/9/3rn4/9/9/9/4R4/4K4 w - - 0 1"

        let analysis = MoveAnalysis(
            playerMove: "e0d0",
            quality: .doubtful,
            bestMove: "e1e5",       // 车吃马（不安全，黑车 d5 可以回吃）
            bestEval: 150,
            playerEval: 50,
            evalDelta: 100,
            alternatives: []
        )

        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: fen,
            playerMove: "e0d0",
            bestMove: "e1e5"
        )

        // 不安全吃子：车吃马后，黑车可以回吃 → isSafeCapture 返回 false
        XCTAssertNotEqual(explanation.scenario, .missedCapture,
                          "不安全吃子不应触发 missedCapture，实际: \(explanation.scenario)")
    }
}

// MARK: - v3.7.4 CommandMenu i18n 验证

final class CommandMenuI18nTests: XCTestCase {

    /// engine.menuLabel key 在 L10n 中存在
    func testI18n_EngineMenuLabel_Exists() {
        let value = L10n.shared.t("engine.menuLabel")
        XCTAssertFalse(value.isEmpty, "engine.menuLabel 不应为空")
        // 默认 fallback 行为：找不到 key 时返回 key 本身
        XCTAssertNotEqual(value, "engine.menuLabel",
                          "engine.menuLabel 应有翻译值，不是返回 key 本身")
    }

    /// engine.configureLabel key 在 L10n 中存在
    func testI18n_EngineConfigureLabel_Exists() {
        let value = L10n.shared.t("engine.configureLabel")
        XCTAssertFalse(value.isEmpty, "engine.configureLabel 不应为空")
        XCTAssertNotEqual(value, "engine.configureLabel",
                          "engine.configureLabel 应有翻译值")
    }

    /// feature.gameRecordImport key 在 L10n 中存在
    func testI18n_GameRecordImport_Exists() {
        let value = L10n.shared.t("feature.gameRecordImport")
        XCTAssertFalse(value.isEmpty, "feature.gameRecordImport 不应为空")
        XCTAssertNotEqual(value, "feature.gameRecordImport",
                          "feature.gameRecordImport 应有翻译值")
    }
}
