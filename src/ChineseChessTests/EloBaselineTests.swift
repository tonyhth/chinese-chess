import Testing
import Foundation
@testable import ChineseChess

@Suite("v3.0 Elo 基线测量", .serialized, .disabled(if: ProcessInfo.processInfo.environment["SKIP_ELO"] != nil))
struct EloBaselineTests {

    // MARK: - 共用输出格式

    private func printResult(label: String, config: SelfPlayConfig, result: SelfPlaySessionResult, startTime: Date) {
        let totalGames = result.redWins + result.blackWins + result.draws
        let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))

        let decisiveGames = result.redWins + result.blackWins
        var eloInfo = "无法计算"
        if decisiveGames > 0, result.redWins > 0 {
            let scoreRate = Double(result.redWins) / Double(decisiveGames)
            let eloDiff = -400 * log10(1.0 / scoreRate - 1.0)
            eloInfo = String(format: "%+.0f Elo", eloDiff)
        }

        let moves = result.games.map { $0.totalMoves }
        let avgMoves = moves.isEmpty ? 0 : Double(moves.reduce(0, +)) / Double(moves.count)

        let winner: String
        if result.redWins > result.blackWins { winner = "红方(\(config.redDifficulty.rawValue))" }
        else if result.blackWins > result.redWins { winner = "黑方(\(config.blackDifficulty.rawValue))" }
        else { winner = "和棋" }

        print("""
        ═══════════════════════════════════════
        Elo 基线: \(label)
        ═══════════════════════════════════════
        配置: \(config.redDifficulty.rawValue) vs \(config.blackDifficulty.rawValue), 1 局, maxMoves=\(config.maxMovesPerGame)
        结果: 胜方=\(winner)
          红方胜: \(result.redWins) / 黑方胜: \(result.blackWins) / 和棋: \(result.draws)
          步数: \(moves.first ?? 0)  |  平均: \(String(format: "%.0f", avgMoves))
          先手优势: \(eloInfo)
          耗时: \(elapsed)s
        ═══════════════════════════════════════
        """)
    }

    // MARK: - Test 1: easy vs medium

    @Test("easyVsMedium — easy vs medium 1局", .timeLimit(.minutes(10)))
    func easyVsMedium() async {
        let config = SelfPlayConfig(
            red: .easy, black: .medium,
            games: 1, maxMoves: 150, swapSides: false
        )
        let runner = SelfPlayRunner()
        let start = Date()
        let result = await runner.run(config: config)

        printResult(label: "easy vs medium", config: config, result: result, startTime: start)

        let totalGames = result.redWins + result.blackWins + result.draws
        #expect(totalGames == 1, "应完成 1 局")
        #expect((result.games.first?.totalMoves ?? 0) > 0, "应有有效步数")
    }

    // MARK: - Test 2: medium vs hard

    @Test("mediumVsHard — medium vs hard 1局", .timeLimit(.minutes(15)))
    func mediumVsHard() async {
        let config = SelfPlayConfig(
            red: .medium, black: .hard,
            games: 1, maxMoves: 150, swapSides: false
        )
        let runner = SelfPlayRunner()
        let start = Date()
        let result = await runner.run(config: config)

        printResult(label: "medium vs hard", config: config, result: result, startTime: start)

        let totalGames = result.redWins + result.blackWins + result.draws
        #expect(totalGames == 1, "应完成 1 局")
        #expect((result.games.first?.totalMoves ?? 0) > 0, "应有有效步数")
    }

    // MARK: - Test 3: hard vs master

    @Test("hardVsMaster — hard vs master 1局", .timeLimit(.minutes(30)))
    func hardVsMaster() async {
        let config = SelfPlayConfig(
            red: .hard, black: .master,
            games: 1, maxMoves: 150, swapSides: false
        )
        let runner = SelfPlayRunner()
        let start = Date()
        let result = await runner.run(config: config)

        printResult(label: "hard vs master", config: config, result: result, startTime: start)

        let totalGames = result.redWins + result.blackWins + result.draws
        #expect(totalGames == 1, "应完成 1 局")
        #expect((result.games.first?.totalMoves ?? 0) > 0, "应有有效步数")
    }

    // MARK: - Test 4: master vs master

    @Test("masterVsMaster — master vs master 1局", .timeLimit(.minutes(60)))
    func masterVsMaster() async {
        let config = SelfPlayConfig(
            red: .master, black: .master,
            games: 1, maxMoves: 150, swapSides: false
        )
        let runner = SelfPlayRunner()
        let start = Date()
        let result = await runner.run(config: config)

        printResult(label: "master vs master", config: config, result: result, startTime: start)

        let totalGames = result.redWins + result.blackWins + result.draws
        #expect(totalGames == 1, "应完成 1 局")
        #expect((result.games.first?.totalMoves ?? 0) > 0, "应有有效步数")
    }
}
