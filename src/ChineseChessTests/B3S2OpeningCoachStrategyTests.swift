import Testing
import Foundation
@testable import ChineseChess

// MARK: - Phase B3 Step 2 — AI 开局配合走法策略测试

@Suite("B3S2 CoachConfig", .serialized)
struct B3S2CoachConfigTests {

    private func makeSubcategory(id: String = "test", firstMoves: [String] = ["h2e2", "h0g2"]) -> OpeningSubcategory {
        OpeningSubcategory(id: id, name: "测试开局", firstMoves: firstMoves, gameCount: 10)
    }

    @Test("CoachConfig 基本构造")
    func configConstruction() {
        let sub = makeSubcategory()
        let config = CoachConfig(
            targetSubcategory: sub,
            aiDifficulty: .medium,
            playerSide: .red
        )
        #expect(config.targetSubcategory.id == "test")
        #expect(config.aiDifficulty == .medium)
        #expect(config.playerSide == .red)
    }

    @Test("CoachConfig 黑方执棋")
    func configBlackPlayer() {
        let sub = makeSubcategory()
        let config = CoachConfig(
            targetSubcategory: sub,
            aiDifficulty: .hard,
            playerSide: .black
        )
        #expect(config.playerSide == .black)
    }
}

@Suite("B3S2 OpeningEndReason", .serialized)
struct B3S2OpeningEndReasonTests {

    @Test("OpeningEndReason 三种结束原因")
    func allReasons() {
        let reasons: [OpeningEndReason] = [.naturalEnd, .maxStepsReached, .userAbandoned]
        #expect(reasons.count == 3)
    }
}

@Suite("B3S2 OpeningCoachStrategy", .serialized)
struct B3S2OpeningCoachStrategyTests {

    private func makeSubcategory(id: String = "test", firstMoves: [String] = ["h2e2", "h0g2"]) -> OpeningSubcategory {
        OpeningSubcategory(id: id, name: "测试开局", firstMoves: firstMoves, gameCount: 10)
    }

    // MARK: - 构造

    @Test("基本构造")
    func construction() {
        let sub = makeSubcategory()
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)
        #expect(strategy.playerSide == .red)
        #expect(strategy.isInFirstMovesRange == true)
    }

    // MARK: - 策略 1：firstMoves 严格按序列走

    @Test("策略1：AI 执红先手走 firstMoves[0]")
    func strategy1RedFirst() {
        let sub = makeSubcategory(firstMoves: ["h2e2", "h0g2", "e2e6"])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .black)

        // AI 执红先手，totalStepIndex=0, playerSide=black
        // 例外：totalStepIndex==0 && playerSide==black → 不计入前置用户走法
        // aiStepIndex=0 → firstMoves[0]
        let aiMove = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        #expect(aiMove == "h2e2", "AI 执红先手应走 firstMoves[0]=h2e2")
    }

    @Test("策略1：用户执红时 AI（黑）走 firstMoves[1]")
    func strategy1BlackSecond() {
        let sub = makeSubcategory(firstMoves: ["h2e2", "h0g2", "e2e6"])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)

        // 用户执红先走，然后 AI 走
        // totalStepIndex=0, playerSide=red → 计入前置用户走法(+1) → totalStepIndex=1
        // aiStepIndex=1 → firstMoves[1]
        let aiMove = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        #expect(aiMove == "h0g2", "AI 执黑应走 firstMoves[1]=h0g2")
    }

    @Test("策略1：多步序列推进（用户执红）")
    func strategy1MultiStepRed() {
        let sub = makeSubcategory(firstMoves: ["h2e2", "h0g2", "e2e6"])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)

        // 第1次调用：前置用户(+1=1), AI走 firstMoves[1]=h0g2, AI(+1=2)
        let move1 = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        #expect(move1 == "h0g2")

        // 第2次调用：前置用户(+1=3), AI走 firstMoves[3] → 超出范围(3>=3)，策略2/3
        let move2 = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        // firstMoves 只有3项，index 3 超出 → 进入策略 2（OpeningBook）
        // 标准开局有开局库数据
        #expect(move2 != nil, "超出 firstMoves 应回退到 OpeningBook")
    }

    @Test("策略1：多步序列推进（AI 执红）— 逐步更新 FEN")
    func strategy1MultiStepBlack() {
        let sub = makeSubcategory(firstMoves: ["h2e2", "h0g2", "e2e6"])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .black)

        // 第1次：例外(totalStepIndex=0, black) → 不计入前置 → aiStepIndex=0
        // AI走 firstMoves[0]=h2e2, AI(+1=1)
        let fen0 = FENParser.standardInitial
        let move1 = strategy.nextAIMove(currentFEN: fen0)
        #expect(move1 == "h2e2")

        // 第2次：前置用户(+1=2), aiStepIndex=2 → firstMoves[2]=e2e6, AI(+1=3)
        // 逐步更新 FEN：h2e2 后的新局面
        let board1 = Board(fen: fen0)
        if let m1 = ICCSParser.parse("h2e2", on: board1) { board1.execute(m1) }
        // 用户走 h0g2
        if let m2 = ICCSParser.parse("h0g2", on: board1) { board1.execute(m2) }
        let fen2 = FENParser.generate(board: board1)

        let move2 = strategy.nextAIMove(currentFEN: fen2)
        #expect(move2 == "e2e6")
    }

    // MARK: - 步数计数器统一管理

    @Test("步数计数器由 nextAIMove 内部统一管理")
    func stepCounterInternal() {
        let sub = makeSubcategory(firstMoves: ["h2e2", "h0g2"])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)

        #expect(strategy.isInFirstMovesRange == true) // 0 < 2

        // 调用 nextAIMove：前置用户(+1=1), AI走 firstMoves[1], AI(+1=2)
        _ = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        #expect(strategy.isInFirstMovesRange == false) // 2 >= 2
    }

    // MARK: - maxSteps 限制

    @Test("超过 20 步开局结束")
    func maxStepsReached() {
        let sub = makeSubcategory(firstMoves: [])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)

        // nextAIMove 每次调用计入前置(+1) + AI(+1) = +2
        // 调用 10 次后 totalStepIndex = 20
        for _ in 0..<10 {
            _ = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        }

        // 第 11 次调用时 aiStepIndex >= 20 → 返回 nil
        let move = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        #expect(move == nil, "超过 20 步应返回 nil")
    }

    // MARK: - 策略 2：OpeningBook 查询

    @Test("策略2：firstMoves 不合法时回退到 OpeningBook")
    func strategy2FallbackToBook() {
        let sub = makeSubcategory(firstMoves: ["z9z9"]) // 非法 ICCS
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)

        // isLegalMove("z9z9") 返回 false → 回退到策略 2
        let move = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        // 标准初始局面有开局库数据
        #expect(move != nil, "标准初始局面应有开局库候选")
    }

    // MARK: - 策略 3：无书谱候选

    @Test("策略3：无书谱候选时返回 nil")
    func strategy3NoBookCandidates() {
        let sub = makeSubcategory(firstMoves: ["z9z9"])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)

        // 用一个不在开局库中的 FEN（只有将帅）
        let fen = "4k4/9/9/9/9/9/9/9/4K4/9 w - - 0 1"
        let move = strategy.nextAIMove(currentFEN: fen)
        #expect(move == nil, "无书谱候选且 firstMoves 不合法时应返回 nil")
    }

    // MARK: - isInFirstMovesRange

    @Test("isInFirstMovesRange 边界")
    func isInFirstMovesRangeBoundary() {
        let sub = makeSubcategory(firstMoves: ["h2e2", "h0g2"])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .black)

        #expect(strategy.isInFirstMovesRange == true) // 0 < 2
        // AI先手: 不计前置 → aiStepIndex=0, 走 firstMoves[0], +1 → totalStepIndex=1
        _ = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        #expect(strategy.isInFirstMovesRange == true) // 1 < 2
        // 第二次: 前置+1=2, aiStepIndex=2 → 超出范围
        _ = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        #expect(strategy.isInFirstMovesRange == false) // 2 >= 2
    }

    // MARK: - 引用语义（struct→class 修复验证）

    @Test("OpeningCoachStrategy 是引用类型（class）")
    func referenceSemantics() {
        let sub = makeSubcategory(firstMoves: ["h2e2", "h0g2"])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)

        let sameRef = strategy
        // 调用 sameRef 的 nextAIMove，strategy 也应受影响
        _ = sameRef.nextAIMove(currentFEN: FENParser.standardInitial)
        #expect(strategy.isInFirstMovesRange == false, "class 引用语义：修改应反映到同一实例")
    }

    // MARK: - firstMoves 为空

    @Test("firstMoves 为空时直接查 OpeningBook")
    func emptyFirstMoves() {
        let sub = makeSubcategory(firstMoves: [])
        let strategy = OpeningCoachStrategy(targetSubcategory: sub, playerSide: .red)

        let move = strategy.nextAIMove(currentFEN: FENParser.standardInitial)
        // 标准初始局面有开局库数据
        #expect(move != nil, "firstMoves 为空应回退到 OpeningBook")
    }
}
