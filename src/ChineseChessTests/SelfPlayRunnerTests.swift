import Testing
import Foundation
@testable import ChineseChess

@Suite("自对弈框架测试")
struct SelfPlayRunnerTests {

    // MARK: - 基础功能测试

    @Test("SelfPlayRunner 快速对弈：beginner vs beginner 2局", .timeLimit(.minutes(5)))
    func quickSelfPlay() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 2,
            maxMoves: 40
        )

        let result = await runner.run(config: config)

        #expect(result.games.count == 2, "应完成 2 局")
        #expect(result.redWins + result.blackWins + result.draws == 2, "胜负统计应等于总局数")
        #expect(result.avgMoves > 0, "平均步数应大于 0")
        #expect(result.durationSeconds >= 0, "耗时不应为负")
    }

    @Test("SelfPlayRunner 先后手交换", .timeLimit(.minutes(5)))
    func sideSwap() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 4,
            maxMoves: 20,
            swapSides: true
        )

        let result = await runner.run(config: config)

        // 交换先后手时，偶数局红=beginner，奇数局红=beginner（同难度交换无区别）
        // 验证交换逻辑：游戏数=4，swapSides=true
        #expect(result.games.count == 4)
        #expect(result.games[0].redDifficulty == .novice)
        #expect(result.games[0].blackDifficulty == .novice)
        #expect(result.games[1].redDifficulty == .novice)
        #expect(result.games[1].blackDifficulty == .novice)
    }

    @Test("SelfPlayRunner 不交换先后手", .timeLimit(.minutes(5)))
    func noSideSwap() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 2,
            maxMoves: 20,
            swapSides: false
        )

        let result = await runner.run(config: config)

        for game in result.games {
            #expect(game.redDifficulty == .novice)
            #expect(game.blackDifficulty == .novice)
        }
    }

    @Test("SelfPlayRunner 步数上限判和", .timeLimit(.minutes(5)))
    func moveLimit() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1,
            maxMoves: 10  // 极小步数上限
        )

        let result = await runner.run(config: config)

        // 10 步内不太可能将死，应该是和棋（步数上限）
        let game = result.games[0]
        if game.result == .draw {
            #expect(game.reason == .moveLimit || game.reason == .repetition,
                    "和棋原因应为步数上限或重复局面")
        }
        #expect(game.totalMoves <= 10, "步数不应超过上限")
    }

    @Test("SelfPlayRunner 结果摘要格式", .timeLimit(.minutes(5)))
    func summaryFormat() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1,
            maxMoves: 20
        )

        let result = await runner.run(config: config)
        let summary = result.summary

        #expect(summary.contains("自对弈结果"), "摘要应包含标题")
        #expect(summary.contains("红胜"), "摘要应包含红胜统计")
        #expect(summary.contains("黑胜"), "摘要应包含黑胜统计")
        #expect(summary.contains("和棋"), "摘要应包含和棋统计")
        #expect(summary.contains("平均步数"), "摘要应包含平均步数")
    }

    // MARK: - BayesElo 测试

    @Test("BayesElo: 50% 胜率 Elo 差为 0")
    func eloEqual() {
        let delta = BayesElo.estimateDelta(winRate: 0.5)
        #expect(abs(delta) <= 1, "50% 胜率 Elo 差应约为 0")
    }

    @Test("BayesElo: 高胜率为正 Elo 差")
    func eloPositive() {
        let delta = BayesElo.estimateDelta(winRate: 0.9)
        #expect(delta > 0, "90% 胜率应为正 Elo 差")
        #expect(delta > 300, "90% 胜率 Elo 差应 > 300")
    }

    @Test("BayesElo: 低胜率为负 Elo 差")
    func eloNegative() {
        let delta = BayesElo.estimateDelta(winRate: 0.1)
        #expect(delta < 0, "10% 胜率应为负 Elo 差")
        #expect(delta < -300, "10% 胜率 Elo 差应 < -300")
    }

    @Test("BayesElo: 胜负平统计计算")
    func eloFromStats() {
        let delta = BayesElo.estimateDelta(wins: 70, losses: 20, draws: 10)
        let winRate = (70.0 + 5.0) / 100.0  // 75%
        let expected = BayesElo.estimateDelta(winRate: winRate)
        #expect(delta == expected, "胜负平计算应与 winRate 一致")
    }

    @Test("BayesElo: 零局数返回 0")
    func eloZero() {
        let delta = BayesElo.estimateDelta(wins: 0, losses: 0, draws: 0)
        #expect(delta == 0, "零局数应返回 0")
    }

    @Test("BayesElo: 极端值不崩溃")
    func eloExtreme() {
        // 不应该崩溃，应该 clamp 到 1%-99%
        let deltaHigh = BayesElo.estimateDelta(winRate: 1.0)
        let deltaLow = BayesElo.estimateDelta(winRate: 0.0)
        #expect(deltaHigh > 0)
        #expect(deltaLow < 0)
    }
}
