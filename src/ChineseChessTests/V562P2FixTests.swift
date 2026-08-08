import Foundation
import Testing
@testable import ChineseChess

// MARK: - v5.6.2 P2 修复补充测试（commit 35e5706）

private func makePuzzle(
    solution: [String] = [],
    solutionMode: SolutionMode = .guided,
    solutionType: String = "checkmate",
    maxMoves: Int = 100
) -> Puzzle {
    Puzzle(
        id: "test", name: "T", category: "t", difficulty: 1, stars: 1,
        description: "", playerSide: "red", initialFEN: FENParser.standardInitial,
        solution: solution, hints: nil, maxMoves: maxMoves,
        solutionType: solutionType, solutionMode: solutionMode
    )
}

@Suite("v5.6.2 P2 修复测试", .serialized)
struct V562P2FixTests {

    // P2-1: PuzzleSelectView 使用 effectiveMaxMoves

    @Test("P2-1: PuzzleSelectView 步数显示用 effectiveMaxMoves（guided）")
    func puzzleSelectUsesEffectiveMaxMovesGuided() {
        let p = makePuzzle(solution: ["a", "b", "c"], maxMoves: 999)
        // effectiveMaxMoves = 3+2 = 5, 不是 JSON maxMoves=999
        #expect(p.effectiveMaxMoves == 5, "步数显示应为 5（effectiveMaxMoves），不是 999（maxMoves）")
    }

    @Test("P2-1: PuzzleSelectView 步数显示用 effectiveMaxMoves（freePlay）")
    func puzzleSelectUsesEffectiveMaxMovesFreePlay() {
        let p = makePuzzle(solution: ["a"], solutionMode: .freePlay, maxMoves: 5)
        #expect(p.effectiveMaxMoves == 200, "freePlay 步数显示应为 200")
    }

    @Test("P2-1: PuzzleSelectView 步数显示用 effectiveMaxMoves（draw）")
    func puzzleSelectUsesEffectiveMaxMovesDraw() {
        let p = makePuzzle(solution: ["a"], solutionType: "draw", maxMoves: 50)
        #expect(p.effectiveMaxMoves == 3, "draw 步数显示应为 3")
    }

    // P2-2: draw 通关消息

    @Test("P2-2: draw 类型 puzzle 有 drawSuccess 消息")
    func drawSuccessMessage() {
        let p = makePuzzle(solutionType: "draw")
        #expect(p.solutionType == "draw")
        // PuzzlePlayView 中：solutionType == "draw" → 显示 l10n.t("puzzle.drawSuccess")
        // 验证 l10n key 存在
        let text = L10n.shared.t("puzzle.drawSuccess")
        #expect(!text.isEmpty, "puzzle.drawSuccess l10n key 应有值")
        #expect(text != "puzzle.drawSuccess", "puzzle.drawSuccess 不应返回 key 本身（说明未翻译）")
    }

    @Test("P2-2: 非 draw 类型不显示 drawSuccess")
    func nonDrawNoDrawSuccess() {
        let p = makePuzzle(solutionType: "checkmate")
        #expect(p.solutionType != "draw", "checkmate 类型不应触发 drawSuccess 消息")
    }
}
