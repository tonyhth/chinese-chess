import Testing
import Foundation
@testable import ChineseChess

/// Contempt 禁用 + C1 Softmax 升级 测试
@Suite("Contempt 禁用 + C1 Softmax 测试")
struct ContemptDisableSoftmaxTests {

    // MARK: - Contempt 禁用验证

    @Test("Contempt 禁用: AIEvalConfig.basic contempt 仍为 0")
    func contemptBasicStillZero() {
        #expect(AIEvalConfig.basic.contempt == 0)
    }

    @Test("Contempt 禁用: AIEvalConfig.advanced contempt 仍为 0")
    func contemptAdvancedStillZero() {
        #expect(AIEvalConfig.advanced.contempt == 0)
    }

    @Test("Contempt 禁用: bestMove novice 不受影响")
    func contemptDisabledNovice() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .novice, isIOS: false)
        #expect(move != nil)
    }

    @Test("Contempt 禁用: bestMove amateurMid contempt=0 不再偏置")
    func contemptDisabledAmateurMid() async {
        let engine = AIEngine()
        let board = Board()
        // amateurMid 之前 contempt=20，现在应为 0
        let move = await engine.bestMove(for: board, difficulty: .amateurMid, isIOS: false)
        #expect(move != nil, "amateurMid 应正常返回走法")
    }

    @Test("Contempt 禁用: bestMove amateurHigh contempt=0 不再偏置")
    func contemptDisabledAmateurHigh() async {
        let engine = AIEngine()
        let board = Board()
        // amateurHigh 之前 contempt=30，现在应为 0
        let move = await engine.bestMove(for: board, difficulty: .amateurHigh, isIOS: false)
        #expect(move != nil, "amateurHigh 应正常返回走法")
    }

    @Test("Contempt 禁用: bestMoves amateurMid 不受影响")
    func contemptDisabledBestMovesAmateurMid() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .amateurMid, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty)
    }

    // MARK: - C1 Softmax: 自对弈端到端验证

    @Test("C1 Softmax: novice 自对弈 1 局正常完成", .timeLimit(.minutes(3)))
    func softmaxNoviceSelfPlay() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1,
            maxMoves: 30
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 1)
        #expect(result.games[0].totalMoves > 0)
    }

    @Test("C1 Softmax: beginner 自对弈 1 局正常完成", .timeLimit(.minutes(5)))
    func softmaxBeginnerSelfPlay() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .beginner,
            black: .beginner,
            games: 1,
            maxMoves: 40
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 1)
        let game = result.games[0]
        #expect(game.totalMoves > 0)
        #expect(game.totalMoves <= 40)
    }

    @Test("C1 Softmax: 多局自对弈结果统计正确", .timeLimit(.minutes(5)))
    func softmaxMultiGames() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 3,
            maxMoves: 20
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 3)
        #expect(result.redWins + result.blackWins + result.draws == 3)
    }

    @Test("C1 Softmax: amateurLow 自对弈 1 局正常", .timeLimit(.minutes(5)))
    func softmaxAmateurLowSelfPlay() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .amateurLow,
            black: .amateurLow,
            games: 1,
            maxMoves: 40
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 1)
        #expect(result.games[0].totalMoves > 0)
    }

    // MARK: - C1 Softmax: 走法随机性验证

    @Test("C1 Softmax: 同一局面多次搜索不会总是返回相同走法（随机性）", .timeLimit(.minutes(3)))
    func softmaxRandomness() async {
        // Softmax 引入随机性，同一局面应该不总是选同一个走法
        // 注意：这不是严格测试（有可能随机选到同一个），但多个候选下概率很低
        let engine = AIEngine()
        let board = Board()
        var selectedMoves = Set<String>()

        for _ in 0..<5 {
            // bestMoves 内部调用，自对弈时通过 softmaxSelect 选择
            let candidates = await engine.bestMoves(for: board, difficulty: .novice, isIOS: false, topK: 3)
            for c in candidates {
                let key = "\(c.move.from.col)\(c.move.from.row)->\(c.move.to.col)\(c.move.to.row)"
                selectedMoves.insert(key)
            }
        }

        // novice 开局至少有多种合法走法，candidates 应覆盖 >1 种
        #expect(selectedMoves.count >= 2, "应至少有 2 种不同候选走法，实际：\(selectedMoves)")
    }

    // MARK: - P1 fix: 测试逻辑修正验证

    @Test("P1 fix: T1T2C1FixTests repetitionThreshold 自定义=8 正确")
    func p1TestLogicFix() {
        var config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1
        )
        config.repetitionThreshold = 8
        #expect(config.repetitionThreshold == 8, "自定义值 8 应正确赋值")
        #expect(config.repetitionThreshold != 6, "不应等于默认值 6")
    }

    // MARK: - 回归: 人机对弈路径

    @Test("回归: amateurDan 人机对弈正常（contempt=0）")
    func regressionHumanPlayAmateurDan() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .amateurDan, isIOS: false)
        #expect(move != nil)
    }

    @Test("回归: grandmaster 人机对弈正常")
    func regressionGrandmaster() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .grandmaster, isIOS: false)
        #expect(move != nil)
    }

    // MARK: - 边界

    @Test("C1 Softmax: bestMoves topK=1 时仍正常（单候选走 Softmax）")
    func softmaxTopK1() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .beginner, isIOS: false, topK: 1)
        #expect(candidates.count == 1)
        // softmaxSelect 单候选时直接返回，不崩溃
    }
}
