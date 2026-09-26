import Foundation
import Testing
@testable import ChineseChess

// MARK: - T-0926-OC-01 Phase 0：TimeManager 预算硬上限语义（名义≈真实）
//
// 契约：搜索墙钟 ≤ 预算 + 容差（容差 = max(500ms, 预算×25%)——覆盖根层走法生成/
// 排序与调度抖动；机制层硬中止最坏 ≈ 预算 + 1024 节点满负荷 + O(树宽×深度) 快退）。
// 背景：KI-2026-0829（open-a 5000ms 实跑 13498ms，2.7×；iOS 3.1×）——迭代内无
// deadline 截断 + 中止级联自身烧机时。修复=硬中止旗标两段式（negamax+QS 同款）。
// 位置源：T-0925-OC-01 采样表（V65PreflightRunner.swift 谱系留档；书外满子力局，
// 书后纯搜索路径）——mid-b 最密（历史 0-2 层完成），open-a 开局（2-3 层）。
// ⚠️ 串行（与 AIEngineTimingContractTests 同约束；预检起跑带 caffeinate 规约同源）

@Suite("TimeManager 预算硬上限语义（T-0926-OC-01）", .serialized)
struct T0926OC01TimeManagerHardCapTests {

    /// T-0925 采样表 FEN（书外位，走纯搜索路径）
    static let denseMidFEN = "r1b1kab2/2n1a1n2/1c4c2/p1p1pR2p/6p2/2P6/P3P1P1P/1CN1C1N2/9/R1BAKABr1 w - - 0 17"
    static let openingFEN = "r1bakabr1/2n3n2/1c6c/p1p1p2Rp/6p2/2P6/P3P1P1P/1C2C1N2/9/RNBAKAB2 w - - 0 11"

    /// 单档硬上限断言：墙钟 ≤ 预算+容差 且 返回着合法（中止路径不允许吐非法着）
    /// - Parameter extraPhaseMs: 预算外合法相位（lvl4=CheckmateSearch 前缀 killTimeLimit 750ms 自有预算）
    private func assertHardCap(_ diff: AIDifficulty, budgetMs: Int, fen: String, label: String,
                               extraPhaseMs: Int = 0) async throws {
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("\(label) FEN 解析失败（采样表漂移？）"); return
        }
        _ = OpeningBook.shared  // 计时外暖机：开局库 3.7MB 懒加载首访 ~3s，不得计入搜索墙钟（首轮实测污染实证）
        let engine = AIEngine()
        let t = Date()
        let move = await engine.bestMove(for: board, difficulty: diff)
        let ms = Date().timeIntervalSince(t) * 1000
        let cap = Double(budgetMs) + max(500.0, Double(budgetMs) * 0.25) + Double(extraPhaseMs)
        NSLog("[tm-hardcap] \(label) budget=\(budgetMs) extraPhase=\(extraPhaseMs) actual=\(Int(ms)) cap=\(Int(cap))")
        #expect(ms <= cap, "\(label) 预算硬上限违约：\(Int(ms))ms > cap \(Int(cap))ms（名义≈真实语义失效）")
        guard let mv = try #require(move, "\(label) 应有走法（含中止路径的首迭代兜底）") else { return }
        let legal = MoveValidator.allLegalMoves(for: board.currentTurn, on: LegacySearchBoard(from: board))
        #expect(legal.contains { $0.from == mv.from && $0.to == mv.to },
                "\(label) 返回着不合法（中止路径吐非法着——快退值污染消费面）")
    }

    @Test("硬上限①: lvl3 mediumNoQS（2000ms）最密中局——历史上限 2 层完成位")
    func lvl3DenseMidHardCap() async throws {
        try await assertHardCap(.amateurLow, budgetMs: 2000, fen: Self.denseMidFEN, label: "lvl3-mid-b")
    }

    @Test("硬上限②: lvl4 .hard+QS（5000ms）最密中局——QS 路径含在内")
    func lvl4DenseMidHardCap() async throws {
        // 墙钟两段合法相位：CheckmateSearch 前缀（killTimeLimit=5000*3/20=750ms 自有预算，产品行为）
        // + IDS 主体（5000ms 硬上限）；容差 1250 覆盖根层/调度
        try await assertHardCap(.amateurMid, budgetMs: 5000, fen: Self.denseMidFEN, label: "lvl4-mid-b",
                                extraPhaseMs: 800)
    }

    @Test("硬上限③: lvl3（2000ms）开局位跨相位回归——13498ms 实证位同型防护")
    func lvl3OpeningHardCap() async throws {
        try await assertHardCap(.amateurLow, budgetMs: 2000, fen: Self.openingFEN, label: "lvl3-open-a")
    }
}
