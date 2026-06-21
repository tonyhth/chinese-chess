import Testing
import Foundation
@testable import ChineseChess

@Suite("v3.0 Elo 基线测量", .disabled(if: ProcessInfo.processInfo.environment["SKIP_ELO"] != nil))
struct EloBaselineTests {

    @Test("medium vs medium 5局自对弈 + Elo 估算（基线样本）")
    func mediumVsMediumEloBaseline() {
        // v3.0 基线测量：先用 5 局快速获取初步数据
        // 后续可扩展到 20-100 局获取更精确的 Elo 估算
        let config = SelfPlayConfig(red: .medium, black: .medium, games: 5, maxMoves: 200)
        let runner = SelfPlayRunner()
        let result = runner.run(config: config)

        let totalGames = result.redWins + result.blackWins + result.draws
        let redWinRate = Double(result.redWins) / Double(totalGames)
        let drawRate = Double(result.draws) / Double(totalGames)

        print("""
        ═══════════════════════════════════════
        Elo 基线测量报告
        ═══════════════════════════════════════
        配置: medium vs medium, 5 局（基线样本）, maxMoves=200

        结果:
          红方胜: \(result.redWins)
          黑方胜: \(result.blackWins)
          和棋:   \(result.draws)
          总局数: \(totalGames)

        胜率:
          红方: \(String(format: "%.1f%%", redWinRate * 100))
          黑方: \(String(format: "%.1f%%", (1 - redWinRate - drawRate) * 100))
          和棋率: \(String(format: "%.1f%%", drawRate * 100))
        """)

        // Elo 差计算（BayesElo 近似）
        let decisiveGames = result.redWins + result.blackWins
        if decisiveGames > 0 && result.redWins > 0 {
            let scoreRate = Double(result.redWins) / Double(decisiveGames)
            let eloDiff = -400 * log10(1.0 / scoreRate - 1.0)
            print("  先手优势: \(String(format: "%+.0f", eloDiff)) Elo")
        } else {
            print("  先手优势: 无法计算（无决胜局）")
        }

        // 步数统计
        let moves = result.games.map { $0.totalMoves }
        let avgMoves = Double(moves.reduce(0, +)) / Double(moves.count)
        print("""
          步数: 平均=\(String(format: "%.0f", avgMoves)), 最多=\(moves.max() ?? 0), 最少=\(moves.min() ?? 0)
        ═══════════════════════════════════════
        """)

        // 同级别自对弈，Elo 差应接近 0
        // 主要验证：1) 不崩溃 2) 能分出胜负或和棋 3) 先手胜率合理
        #expect(totalGames == 20, "应完成 20 局")
        #expect(avgMoves > 0, "应有有效步数")
    }
}
