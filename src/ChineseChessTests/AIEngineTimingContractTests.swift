import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.3 洪涛工单①业余档：自研引擎分级时延契约（难度 1-5）
//
// 契约：每级同一开局连走 10 着，ContinuousClock 计时，
// 单着 ≤ 预算×1.5 + 0.5s（自研迭代加深口径——深度封顶先于时间耗尽属正常，
// 与 Pikafish 的 +2s 口径区分）。
// 预算源：AIEngine 各档 TimeManager（lvl2=1000 / lvl3=2000 / lvl4=5000 / lvl5=8000；
// lvl1 novice 为浅评估无显式预算，取名义 500ms）。
// 表格输出双通道：测试日志 + NSLog（供 evidence/engine-timing-0829/ 收割拼全 10 级画像）。
// ⚠️ 串行（与 EngineTimeContractTests 同约束；开局库命中（lvl4/5 moveHistory<6）属真实路径，计时含之）

@Suite("业余档分级时延契约（自研 1-5）", .serialized)
struct AIEngineTimingContractTests {

    // 硬断言档（1-3）与登记观察档（4-5）分离——Luke 08-29 二裁：
    // lvl4/5 违约 v6.4 立案（难度重设计工作包，与 depth 阶梯校准/V2 前史锚点合并），
    // 确定性形态：豁免硬断言但实测照常入表（带 VIOLATION-REGISTERED 标记）
    static let hardAssertLevels: [(AIDifficulty, Int, String)] = [
        (.novice, 500, "lvl1"),        // 名义预算（浅评估无显式 TimeManager）
        (.beginner, 1000, "lvl2"),
        (.amateurLow, 2000, "lvl3"),
    ]
    /// v6.4 立案档（issue: lvl4 max 13.5s / lvl5 max 45.4s 实测在案
    /// evidence/engine-timing-0829/pfcal-amateur.md；lvl3 秒回=开局库全命中路径，同工作包定性）
    static let observedLevels: [(AIDifficulty, Int, String)] = [
        (.amateurMid, 5000, "lvl4"),
        (.amateurHigh, 8000, "lvl5"),
    ]

    @Test("契约①: 难度 1-5 每级 10 着，单着 ≤ 预算×1.5+0.5s（表格输出）")
    func amateurTimingContract() async throws {
        var tableLines: [String] = []
        NSLog("[amateur-timing] | 难度 | 预算ms | 实测均值ms | 实测最大ms | 违约次数(>预算×1.5+0.5s) |")

        for (diff, budget, label) in Self.hardAssertLevels + Self.observedLevels {
            let isObserved = Self.observedLevels.contains { $0.2 == label }
            let board = Board()
            board.setCurrentTurn(.red)
            let engine = AIEngine()
            var elapsed: [Double] = []
            var violations = 0

            for _ in 0..<10 {
                let snapshot = board.snapshot()
                let t = Date()
                let move = await engine.bestMove(for: snapshot, difficulty: diff)
                let ms = Date().timeIntervalSince(t) * 1000
                let mv = try #require(move, "\(label) 应有走法")
                // 丹妮复核②：lvl3 秒回=浅层档设计行为（开局库/浅搜索），须排除假快——
                // 返回着非空且合法（对全档生效，重点锢定 lvl3 秒回路径）
                let legal = MoveValidator.allLegalMoves(for: board.currentTurn, on: LegacySearchBoard(from: board))
                #expect(legal.contains { $0.from == mv.from && $0.to == mv.to },
                        "\(label) 第\(elapsed.count+1)着返回着不合法（假快嫌疑：秒回但非合法着法）")
                board.execute(mv)
                elapsed.append(ms)
                let cap = Double(budget) * 1.5 + 500
                if ms > cap { violations += 1 }
            }

            let avg = elapsed.reduce(0, +) / Double(elapsed.count)
            let mx = elapsed.max() ?? 0
            let row = "| \(label) (\(diff.rawValue)) | \(budget) | \(Int(avg)) | \(Int(mx)) | \(violations) |"
            tableLines.append(row)
            NSLog("[amateur-timing] \(row)")

            let cap = Double(budget) * 1.5 + 500
            if isObserved {
                // 登记观察档（v6.4 立案）：违约已知在案，只记录不硬断言（确定性形态，
                // 修复落地时本分支删除、回归全档硬断言）
                let violIdx = elapsed.enumerated().filter { $0.element > cap }.map { $0.offset + 1 }
                if !violIdx.isEmpty {
                    // 丹妮复核定位锚：违约集中在第 8-10 着连续深局段（lvl5 末两着 40s+ 连坐）
                    // ——迭代加深深局段 TimeManager 失效形态，v6.4 堵漏从层内 deadline 截断入手
                    NSLog("[amateur-timing] \(label) VIOLATION-REGISTERED(v6.4 难度重设计工作包/issue=difficulty-redesign): \(violIdx.count)/10 着超帽 @着序\(violIdx)，max=\(Int(mx))ms（修复后此标记应消失）")
                }
            } else {
                // 硬断言档（1-3）
                for (i, ms) in elapsed.enumerated() {
                    #expect(ms <= cap,
                            "\(label) 第\(i+1)着实测 \(Int(ms))ms > 预算×1.5+0.5s=\(Int(cap))ms（自研迭代加深契约击穿）")
                }
            }
        }

        // 表格整体输出（收割证据用）
        NSLog("[amateur-timing] TABLE-BEGIN\n| 难度 | 预算ms | 实测均值ms | 实测最大ms | 违约次数(>预算×1.5+0.5s) |\n|---|---|---|---|---|\n" + tableLines.joined(separator: "\n") + "\nTABLE-END")
    }
}
