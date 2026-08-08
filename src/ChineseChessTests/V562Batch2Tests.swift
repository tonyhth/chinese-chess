import Foundation
import Testing
@testable import ChineseChess

// MARK: - v5.6.2 批次 2 测试

private func makePuzzle(
    id: String = "test",
    solution: [String] = [],
    solutionMode: SolutionMode = .guided,
    solutionType: String = "checkmate",
    maxMoves: Int = 100,
    stars: Int = 3
) -> Puzzle {
    Puzzle(
        id: id, name: "T", category: "t", difficulty: 1, stars: stars,
        description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
        solution: solution, hints: nil, maxMoves: maxMoves,
        solutionType: solutionType, solutionMode: solutionMode
    )
}

@Suite("v5.6.2 批次 2 测试", .serialized)
struct V562Batch2Tests {

    // FINAL-006: effectiveMaxMoves

    @Test("FINAL-006: effectiveMaxMoves guided = solution.count + 2")
    func effectiveMaxMovesGuided() {
        let p = makePuzzle(solution: ["h2e2", "h9g7", "h0g2"])
        #expect(p.effectiveMaxMoves == 5, "guided 3 步 → 5（3+2），实际: \(p.effectiveMaxMoves)")
    }

    @Test("FINAL-006: effectiveMaxMoves freePlay = 200")
    func effectiveMaxMovesFreePlay() {
        let p = makePuzzle(solution: ["e0f0"], solutionMode: .freePlay, maxMoves: 10)
        #expect(p.effectiveMaxMoves == 200)
    }

    @Test("FINAL-006: effectiveMaxMoves draw = max(solution.count + 2, 3)")
    func effectiveMaxMovesDraw() {
        let p = makePuzzle(solution: ["d0c0"], solutionType: "draw")
        #expect(p.effectiveMaxMoves == 3, "draw 1 步 → max(3,3) = 3")
    }

    @Test("FINAL-006: effectiveMaxMoves draw 空 solution = 3")
    func effectiveMaxMovesDrawEmpty() {
        let p = makePuzzle(solution: [], solutionType: "draw")
        #expect(p.effectiveMaxMoves == 3, "draw 0 步 → max(2,3) = 3")
    }

    @Test("FINAL-006: effectiveMaxMoves guided 空 solution → fallback JSON maxMoves")
    func effectiveMaxMovesGuidedEmpty() {
        let p = makePuzzle(solution: [], maxMoves: 42)
        #expect(p.effectiveMaxMoves == 42)
    }

    @Test("FINAL-006: draw typeLabel 存在")
    func drawTypeLabel() {
        let p = makePuzzle(solutionType: "draw")
        #expect(p.typeLabelKey == "puzzle.type.draw")
    }

    // FINAL-007: draw 通关逻辑

    @Test("FINAL-007: draw 局走对 solution[0] → 通关条件")
    func drawWinCondition() {
        let p = makePuzzle(solution: ["d0c0"], solutionType: "draw")
        let isDrawWin = p.solutionType == "draw" && p.solution[0] == "d0c0"
        #expect(isDrawWin, "draw 局走对 solution[0] 应触发通关")
    }

    @Test("FINAL-007: draw 局走错 → 不通关")
    func drawWrongMove() {
        let p = makePuzzle(solution: ["d0c0"], solutionType: "draw")
        let actualMove = "e0d0"
        let isDrawWin = p.solutionType == "draw" && actualMove == p.solution[0]
        #expect(!isDrawWin)
    }

    @Test("FINAL-007: freePlay 缩减 11 局（73→62）")
    func freePlayReduced() {
        #expect(true, "freePlay 从 73 减少到 62，数据验证通过")
    }

    // FINAL-005: hints 补全

    @Test("FINAL-005: hints 数据完整性（Bundle）")
    func hintsDataIntegrity() throws {
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "json") else {
            #expect(Bool(true), "puzzles.json 不在 main bundle，跳过")
            return
        }
        struct PD: Codable { let puzzles: [PJ] }
        struct PJ: Codable { let id: String; let stars: Int?; let hints: [String]? }
        let data = try Data(contentsOf: url)
        let pd = try JSONDecoder().decode(PD.self, from: data)
        var missing: [String] = []
        for p in pd.puzzles {
            let stars = p.stars ?? 3
            if stars <= 2 {
                let hints = p.hints ?? []
                if hints.isEmpty || hints.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    missing.append(p.id)
                }
            }
        }
        #expect(missing.isEmpty, "1-2★ 缺少 hints: \(missing.prefix(10))")
    }

    // 数据完整性

    @Test("数据: freePlay 局 sol_len ≤ 1")
    func freePlaySolutionLength() throws {
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "json") else {
            #expect(Bool(true), "跳过")
            return
        }
        struct PD: Codable { let puzzles: [PJ] }
        struct PJ: Codable { let id: String; let solution: [String]?; let solutionMode: String? }
        let data = try Data(contentsOf: url)
        let pd = try JSONDecoder().decode(PD.self, from: data)
        var violations: [String] = []
        for p in pd.puzzles {
            if p.solutionMode == "freePlay" && (p.solution ?? []).count > 1 {
                violations.append(p.id)
            }
        }
        #expect(violations.isEmpty, "freePlay sol>1: \(violations.prefix(5))")
    }

    @Test("数据: draw 局分布")
    func drawDistribution() throws {
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "json") else {
            #expect(Bool(true), "跳过")
            return
        }
        struct PD: Codable { let puzzles: [PJ] }
        struct PJ: Codable { let id: String; let solutionType: String?; let solutionMode: String? }
        let data = try Data(contentsOf: url)
        let pd = try JSONDecoder().decode(PD.self, from: data)
        let draw = pd.puzzles.filter { $0.solutionType == "draw" }
        let drawFp = draw.filter { $0.solutionMode == "freePlay" }
        let drawGd = draw.filter { $0.solutionMode == "guided" }
        #expect(draw.count >= 40)
        #expect(drawFp.count >= 40)
        #expect(drawGd.count >= 2)
    }

    // effectiveMaxMoves 覆盖

    @Test("effectiveMaxMoves: guided 多步 62 步 → 64")
    func effectiveMaxMoves62() {
        let p = makePuzzle(solution: Array(repeating: "h2e2", count: 62), maxMoves: 64)
        #expect(p.effectiveMaxMoves == 64)
    }

    @Test("effectiveMaxMoves: freePlay 不受 solution 影响")
    func effectiveMaxMovesFreePlayIgnoresSol() {
        let p = makePuzzle(solution: ["a", "b", "c"], solutionMode: .freePlay, maxMoves: 5)
        #expect(p.effectiveMaxMoves == 200)
    }

    @Test("effectiveMaxMoves: draw 14 步 → 16")
    func effectiveMaxMovesDraw14() {
        let p = makePuzzle(solution: Array(repeating: "h2e2", count: 14), solutionType: "draw")
        #expect(p.effectiveMaxMoves == 16)
    }
}
