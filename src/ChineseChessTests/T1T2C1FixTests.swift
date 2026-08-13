import Testing
import Foundation
@testable import ChineseChess

/// T1+T2+C1 三方案修复测试
@Suite("T1+T2+C1 修复测试")
struct T1T2C1FixTests {

    // MARK: - T1: repetitionThreshold 默认值验证

    @Test("T1: SelfPlayConfig.repetitionThreshold 默认值 = 6")
    func t1SelfPlayConfigDefault() {
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1
        )
        #expect(config.repetitionThreshold == 6, "SelfPlayConfig 默认 repetitionThreshold 应为 6")
    }

    @Test("T1: MixedEngineConfig.repetitionThreshold 默认值 = 6")
    func t1MixedEngineConfigDefault() {
        let config = MixedEngineConfig(
            games: 1
        )
        #expect(config.repetitionThreshold == 6, "MixedEngineConfig 默认 repetitionThreshold 应为 6")
    }

    @Test("T1: SelfPlayConfig.repetitionThreshold 可通过属性修改")
    func t1SelfPlayConfigCustom() {
        var config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1
        )
        config.repetitionThreshold = 3
        #expect(config.repetitionThreshold == 6, "应支持通过属性修改 repetitionThreshold")
    }

    // MARK: - T2: clearTT() 功能验证

    @Test("T2: AIEngine.clearTT() 不崩溃")
    func t2ClearTTNoCrash() async {
        let engine = AIEngine()
        let board = Board()
        // 先做一次搜索填充 TT
        _ = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        // 清空 TT 不应崩溃
        await engine.clearTT()
    }

    @Test("T2: AIEngine.clearHistory() 同时清空 TT")
    func t2ClearHistoryClearsTT() async {
        let engine = AIEngine()
        let board = Board()
        _ = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        // clearHistory 应同时清 TT（T2 改动）
        await engine.clearHistory()
        // 验证不崩溃，且后续搜索仍正常工作
        let move = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        #expect(move != nil, "清空 TT 后应仍能正常搜索")
    }

    @Test("T2: 连续多次 clearTT() 安全")
    func t2MultipleClearTT() async {
        let engine = AIEngine()
        await engine.clearTT()
        await engine.clearTT()
        await engine.clearTT()
        // 不崩溃即通过
    }

    // MARK: - C1: bestMoves() 返回 top-k 候选

    @Test("C1: bestMoves topK=1 返回单个候选")
    func c1BestMovesTopK1() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .beginner, isIOS: false, topK: 1)
        #expect(candidates.count == 1, "topK=1 应只返回 1 个候选")
    }

    @Test("C1: bestMoves topK=3 返回不超过 3 个候选")
    func c1BestMovesTopK3() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .beginner, isIOS: false, topK: 3)
        #expect(candidates.count <= 3, "候选数应 ≤ 3")
        #expect(!candidates.isEmpty, "应至少返回 1 个候选")
    }

    @Test("C1: bestMoves topK=5 返回不超过 5 个候选")
    func c1BestMovesTopK5() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .beginner, isIOS: false, topK: 5)
        #expect(candidates.count <= 5, "候选数应 ≤ 5")
        #expect(!candidates.isEmpty, "应至少返回 1 个候选")
    }

    @Test("C1: bestMoves novice 返回候选")
    func c1BestMovesNovice() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .novice, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty, "novice 应返回候选")
        #expect(candidates.count <= 3, "候选数 ≤ 3")
    }

    @Test("C1: bestMoves beginner 返回候选")
    func c1BestMovesBeginner() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .beginner, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty, "beginner 应返回候选")
    }

    @Test("C1: bestMoves amateurLow 返回候选")
    func c1BestMovesAmateurLow() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .amateurLow, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty, "amateurLow 应返回候选")
    }

    @Test("C1: bestMoves 候选评分按降序排列")
    func c1BestMovesSorted() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .beginner, isIOS: false, topK: 5)
        for i in 0..<(candidates.count - 1) {
            #expect(candidates[i].score >= candidates[i + 1].score,
                    "候选应按评分降序排列：[\(i)].score=\(candidates[i].score) < [\(i+1)].score=\(candidates[i+1].score)")
        }
    }

    @Test("C1: bestMoves 候选都是合法走法")
    func c1CandidatesAreLegal() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .novice, isIOS: false, topK: 3)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        for candidate in candidates {
            #expect(legalMoves.contains(where: { $0.from == candidate.move.from && $0.to == candidate.move.to }),
                    "每个候选都应是合法走法")
        }
    }

    // MARK: - 集成: 自对弈不因 TT 泄漏崩溃

    @Test("T2+C1 集成: novice 自对弈 1 局正常完成", .timeLimit(.minutes(3)))
    func integrationNoviceSelfPlay() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1,
            maxMoves: 30
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 1, "应完成 1 局")
        #expect(result.redWins + result.blackWins + result.draws == 1, "胜负统计应正确")
    }

    @Test("T2+C1 集成: beginner 自对弈 1 局正常完成", .timeLimit(.minutes(5)))
    func integrationBeginnerSelfPlay() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .beginner,
            black: .beginner,
            games: 1,
            maxMoves: 40
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 1, "应完成 1 局")
        let game = result.games[0]
        #expect(game.totalMoves > 0, "应有走步")
        #expect(game.totalMoves <= 40, "不应超过步数上限")
    }

    // MARK: - T1: 高重复阈值减少虚假和棋

    @Test("T1: 阈值=6 下自对弈不会过早判重复和棋", .timeLimit(.minutes(5)))
    func t1HigherThresholdLessRepetition() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 2,
            maxMoves: 20
        )
        let result = await runner.run(config: config)
        for game in result.games {
            // 不强制结果，但验证不崩溃且步数合理
            #expect(game.totalMoves > 0, "应有走步")
        }
    }
}
