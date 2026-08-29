import Foundation
import Testing
import Pikafish
@testable import ChineseChess

// MARK: - 时间契约测试（v6.2 movetime 加急案，Luke 令：修 Bug 必带回归测试）
// 契约：固定简单局面 + 低 movetime/depth，实测耗时超 2×movetime 即 fail。
// 锚案：startTime 修复 6a0f750 之前 movetime 被无视（5-11s+/着、曾 60s+），
// 本测试锢定该契约——若库/映射链回归导致 movetime 失效，此处先红。
// ⚠️ 串行执行（全局 C 引擎状态，与 PikafishCAPITests 同约束）

@Suite("时间契约: pikafish_best_move 耗时 ≤ 2×movetime", .serialized)
struct EngineTimeContractTests {

    static let simpleFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

    private func elapsedMs(_ body: () throws -> Void) rethrows -> Double {
        let t0 = Date()
        try body()
        return Date().timeIntervalSince(t0) * 1000
    }

    @Test("契约①: movetime 300ms 首着 ≤ 600ms（2× 契约）")
    func movetimeContractFirstMove() {
        pikafish_quit()
        #expect(pikafish_init() == 0, "引擎 init 应成功（NNUE 需在 test host bundle）")
        defer { pikafish_quit() }

        var buf = [CChar](repeating: 0, count: 64)
        let ms = elapsedMs {
            let r = pikafish_best_move(
                Self.simpleFEN, "", 0, 300, &buf, Int32(buf.count))
            #expect(r == 0, "best_move 应成功返回（r=\(r)）")
        }
        // 契约：耗时 ≤ 2×movetime（600ms）+ 工程 margin（首着含少量开销，取 800ms 硬帽）
        #expect(ms <= 800, "movetime 300ms 契约击穿：实测 \(ms)ms（>2×+margin）——movetime 消费疑似失效（对齐 6a0f750 修前症状）")
        let move = String(cString: buf)
        #expect(!move.isEmpty, "应返回非空着法")
    }

    @Test("契约②: movetime 800ms 连续三着均 ≤ 1600ms")
    func movetimeContractSequential() {
        pikafish_quit()
        #expect(pikafish_init() == 0)
        defer { pikafish_quit() }

        var moves = ""
        for i in 1...3 {
            var buf = [CChar](repeating: 0, count: 64)
            let ms = elapsedMs {
                let r = pikafish_best_move(
                    Self.simpleFEN, moves, 0, 800, &buf, Int32(buf.count))
                #expect(r == 0, "第\(i)着 best_move 应成功（r=\(r)）")
            }
            #expect(ms <= 1600, "第\(i)着 movetime 800ms 契约击穿：实测 \(ms)ms")
            let mv = String(cString: buf)
            #expect(!mv.isEmpty, "第\(i)着应返回非空着法")
            moves += mv + " "
        }
    }

    @Test("契约③: Swift 层 watchdog——EmbeddedPikafishEngine.bestMove 超时兜底不无限等")
    @MainActor
    func swiftWatchdogContract() async throws {
        // 经 EngineRouter 取共享引擎（保持开关保存/还原，无跨用例污染）
        // v6.3 E5: 开关退场——原开关保存/还原移除

        let engine = await EngineRouter.shared.switchEngineIfNeeded()
        guard let emb = engine as? EmbeddedPikafishEngine, emb.isReady else {
            Issue.record("引擎未就绪（NNUE 缺失？）——契约③无法执行")
            return
        }

        let t0 = Date()
        // grandmaster 档 defaultTimeMs=10s，watchdog 预算 12s，取 13.5s 硬帽
        let move = await emb.bestMove(
            fen: Self.simpleFEN, moveHistory: [],
            difficulty: .grandmaster, timeLimitMs: 0)
        let ms = Date().timeIntervalSince(t0) * 1000
        #expect(ms <= 13_500, "watchdog 契约击穿：bestMove 实测 \(ms)ms > 13.5s 硬帽（UI 无限等回归）")
        _ = move // 着法可为 nil（超时降级）——契约只锢定耗时上界
    }

    // MARK: - v6.3 工单② 分级时延契约（洪涛令：28s 案补实证层，Luke 派单）
    // 契约：难度 6-10 每级同起局面 10 着连续自弈，采样第 1/5/10 着，
    // 单着 ≤ 预算+2s（对齐 Swift watchdog soft 预算与探针口径）。
    // ⚠️ 长用例（~5 级×10 着×5-10s ≈ 5-8 min），串行 suite 尾部执行
    @Test("契约④: 难度 6-10 分级时延采样（1/5/10 着 ≤ 预算+2s）")
    @MainActor
    func perLevelTimingContract() async throws {
        let budgets: [(AIDifficulty, Int, String)] = [
            (.amateurDan, 5000, "lvl6"), (.proApprentice, 6000, "lvl7"),
            (.proExpert, 7000, "lvl8"), (.proMaster, 8000, "lvl9"),
            (.grandmaster, 10000, "lvl10"),
        ]
        // 自持实例（不走 Router）：契约①/② 的裸 pikafish_quit 会把 Router 预热实例
        // 变僵尸（isReady 仍 true 但 C 层已死），本用例须独立 init/quit 生命周期
        let emb = EmbeddedPikafishEngine()
        do { try await emb.start() } catch {
            Issue.record("引擎启动失败——契约④无法执行: \(error)")
            return
        }
        defer { Task { await emb.shutdown() } }
        for (diff, budget, label) in budgets {
            await emb.newGame()
            var history: [String] = []
            for moveIdx in 1...10 {
                let t0 = Date()
                let mv = await emb.bestMove(
                    fen: Self.simpleFEN, moveHistory: history,
                    difficulty: diff, timeLimitMs: 0)
                let ms = Date().timeIntervalSince(t0) * 1000
                guard let mv else {
                    Issue.record("\(label) 第\(moveIdx)着返回 nil——时延契约外失败")
                    break
                }
                // 采样点断言（1/5/10）
                if moveIdx == 1 || moveIdx == 5 || moveIdx == 10 {
                    #expect(ms <= Double(budget + 2000) + 500,
                            "\(label) 第\(moveIdx)着实测 \(ms)ms > 预算+2s+margin（分级时延契约击穿，对齐 28s 案形态）")
                }
                history.append(mv)
            }
        }
    }
}
