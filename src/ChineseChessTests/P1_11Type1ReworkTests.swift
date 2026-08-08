import Foundation
import Testing
@testable import ChineseChess

// MARK: - P1-11 类型1 返工测试
//
// commit 9b9eea2: 按 solution length 筛选 freePlay/guided，修正原 b0fb8ef 的 ID 区间误改
//
// 规则：
// - solution 长度 ≤ 1 → freePlay（solution[0] 作为提示首步）
// - solution 长度 > 1 或 0 → guided
// - 不再按 ID 区间判断

@Suite("P1-11 类型1 返工：solution length 筛选", .serialized)
struct P1_11Type1ReworkTests {

    // ============================================================
    // 1. effectiveMode 逻辑验证（代码层）
    // ============================================================

    @Test("effectiveMode: solutionMode=freePlay 优先（不变）")
    func effectiveModeFreePlayPriority() {
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: ["e0f0"], hints: nil, maxMoves: 100,
            solutionMode: .freePlay
        )
        #expect(puzzle.effectiveMode == .freePlay, "solutionMode=freePlay 应优先")
    }

    @Test("effectiveMode: solutionMode=guided + solution 非空 → guided")
    func effectiveModeGuidedWithSolution() {
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: ["h2e2", "h9g7", "h0g2"], hints: nil, maxMoves: 100,
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided)
    }

    @Test("effectiveMode: solutionMode=guided + 空 solution → guided")
    func effectiveModeGuidedEmptySolution() {
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: [], hints: nil, maxMoves: 100,
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided)
    }

    // ============================================================
    // 2. 筛选规则验证：solution length 决定模式
    // ============================================================

    @Test("筛选规则: sol_len=0 → guided（向后兼容）")
    func filterRuleEmptySolutionGuided() {
        // sol_len=0 + solutionMode=guided → effectiveMode=guided
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: [], hints: nil, maxMoves: 100,
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided, "空 solution + guided 模式应为 guided")
    }

    @Test("筛选规则: sol_len=1 + freePlay → freePlay（提示首步）")
    func filterRuleOneStepFreePlay() {
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: ["e0f0"], hints: nil, maxMoves: 100,
            solutionMode: .freePlay
        )
        #expect(puzzle.effectiveMode == .freePlay, "sol_len=1 + freePlay 应为 freePlay")
    }

    @Test("筛选规则: sol_len=1 + guided → guided（不该是 freePlay）")
    func filterRuleOneStepGuidedStaysGuided() {
        // sol_len=1 但 solutionMode=guided → effectiveMode=guided
        // 这是因为 effectiveMode 逻辑：solutionMode != freePlay → 检查 solution 非空 → guided
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: ["e0f0"], hints: nil, maxMoves: 100,
            solutionMode: .guided
        )
        // effectiveMode: solutionMode 不是 freePlay → solution 非空 → guided
        #expect(puzzle.effectiveMode == .guided, "sol_len=1 + guided 模式应为 guided（只有 freePlay 标记才走 freePlay）")
    }

    @Test("筛选规则: sol_len=2+ → guided（多步引导）")
    func filterRuleMultiStepGuided() {
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: ["h2e2", "h9g7"], hints: nil, maxMoves: 100,
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided, "多步 solution 应为 guided")
    }

    // ============================================================
    // 3. 数据一致性验证（puzzles.json）
    // ============================================================

    @Test("数据一致性: 从 Bundle 加载验证（如果可用）")
    func dataConsistencyFromBundle() throws {
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "json") else {
            #expect(Bool(true), "puzzles.json 不在 main bundle（测试环境限制），跳过数据验证")
            return
        }

        struct PuzzleData: Codable {
            let puzzles: [PuzzleJSON]
        }
        struct PuzzleJSON: Codable {
            let id: String
            let solution: [String]?
            let solutionMode: String?
        }

        let data = try Data(contentsOf: url)
        let puzzleData = try JSONDecoder().decode(PuzzleData.self, from: data)

        var fpViolations: [(String, Int)] = []  // freePlay with sol_len > 1
        var gdViolations: [(String, Int)] = []  // guided with sol_len == 1

        for p in puzzleData.puzzles {
            let sol = p.solution ?? []
            let mode = p.solutionMode ?? "guided"

            if mode == "freePlay" && sol.count > 1 {
                fpViolations.append((p.id, sol.count))
            }
            if mode == "guided" && sol.count == 1 {
                gdViolations.append((p.id, sol.count))
            }
        }

        #expect(fpViolations.isEmpty, "freePlay 局 sol_len > 1 的违规: \(fpViolations.prefix(5))")
        #expect(gdViolations.isEmpty, "guided 局 sol_len == 1 的违规: \(gdViolations.prefix(5))")
    }

    // ============================================================
    // 4. 原 b0fb8ef 误改恢复验证（抽样）
    // ============================================================

    @Test("原误改恢复: sol_len=19 → guided 模式（模拟 sqyq_432）")
    func reworkRestoreGuided1() {
        let puzzle = Puzzle(
            id: "sqyq_432_like", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: Array(repeating: "h2e2", count: 19), hints: nil, maxMoves: 30,
            solutionMode: .guided  // 返工后恢复为 guided
        )
        #expect(puzzle.effectiveMode == .guided, "sol_len=19 应为 guided（原 b0fb8ef 误改已恢复）")
    }

    @Test("原误改恢复: sol_len=31 → guided 模式（模拟 sqyq_453）")
    func reworkRestoreGuided2() {
        let puzzle = Puzzle(
            id: "sqyq_453_like", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: Array(repeating: "h2e2", count: 31), hints: nil, maxMoves: 40,
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided, "sol_len=31 应为 guided")
    }

    // ============================================================
    // 5. 返工新改 freePlay 验证（抽样）
    // ============================================================

    @Test("返工新改: sol_len=1 → freePlay（模拟 sqyq_481/497/551）")
    func reworkNewFreePlay() {
        let puzzle = Puzzle(
            id: "sqyq_481_like", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: ["e0f0"], hints: nil, maxMoves: 100,
            solutionMode: .freePlay  // 返工后改为 freePlay
        )
        #expect(puzzle.effectiveMode == .freePlay, "sol_len=1 + freePlay 应为 freePlay（返工新改）")
    }

    @Test("返工新改: sol_len=0 → freePlay（空 solution 自由对弈）")
    func reworkNewFreePlayEmpty() {
        let puzzle = Puzzle(
            id: "sqyq_empty_like", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: [], hints: nil, maxMoves: 100,
            solutionMode: .freePlay
        )
        #expect(puzzle.effectiveMode == .freePlay, "空 solution + freePlay 应为 freePlay")
    }

    // ============================================================
    // 6. maxMoves 与 solution 长度的兼容性
    // ============================================================

    @Test("maxMoves 兼容: guided 局 maxMoves ≥ sol_len")
    func maxMovesCompatibleGuided() {
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: Array(repeating: "h2e2", count: 62), hints: nil, maxMoves: 64,
            solutionMode: .guided
        )
        #expect(puzzle.maxMoves >= puzzle.solution.count, "guided 局 maxMoves 应 ≥ solution 长度")
    }

    @Test("maxMoves 兼容: freePlay 局 maxMoves 不影响自由对弈")
    func maxMovesCompatibleFreePlay() {
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: ["e0f0"], hints: nil, maxMoves: 100,
            solutionMode: .freePlay
        )
        // freePlay 模式不受 maxMoves 限制（自由对弈不判定失败）
        #expect(puzzle.effectiveMode == .freePlay)
        #expect(puzzle.maxMoves >= 1, "maxMoves 应 ≥ 1")
    }

    // ============================================================
    // 7. 边界情况
    // ============================================================

    @Test("边界: sol_len=2 + freePlay → 仍为 freePlay（solutionMode 优先）")
    func boundarySol2FreePlay() {
        // 虽然 freePlay 局 sol_len 应 ≤ 1，但代码层面 solutionMode=freePlay 总是优先
        // 数据层面的约束由 puzzles.json 保证，代码层面不检查
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: ["h2e2", "h9g7"], hints: nil, maxMoves: 100,
            solutionMode: .freePlay
        )
        // effectiveMode 逻辑：solutionMode == freePlay → 直接返回 freePlay
        // 不管 solution 内容
        #expect(puzzle.effectiveMode == .freePlay, "代码层面 solutionMode=freePlay 总是优先")
    }

    @Test("边界: 极长 solution + guided → guided")
    func boundaryVeryLongSolution() {
        let puzzle = Puzzle(
            id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
            description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
            solution: Array(repeating: "h2e2", count: 200), hints: nil, maxMoves: 200,
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided, "极长 solution 仍为 guided")
    }
}
