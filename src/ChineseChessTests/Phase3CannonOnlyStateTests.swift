import XCTest
@testable import ChineseChess

/// v4.1 Phase 3 验证测试：cannonOnly 完成后 DailyChallenge 状态
///
/// commit fed5daf 仅添加 2 行注释，无功能代码修改。
/// 本测试验证代码路径的正确性：
/// - cannonOnly → puzzleId = nil（规则变体，不关联残局）
/// - endgameStart/solveMate → puzzleId ≠ nil
/// - completeChallenge 各模式下的 completed/score/puzzleId 状态
final class Phase3CannonOnlyStateTests: XCTestCase {

    private func makeManager() -> DailyChallengeManager {
        let suite = UserDefaults(suiteName: "test_phase3_\(UUID().uuidString)")!
        return DailyChallengeManager(defaults: suite)
    }

    private func makeTestPuzzles() -> [Puzzle] {
        [
            Puzzle(id: "endgame1", name: "endgame1", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red",
                   initialFEN: "3ak4/9/9/9/9/9/9/9/9/3AK4 w",
                   solution: ["a0a1"], hints: nil, maxMoves: 1,
                   solutionType: "checkmate"),
            Puzzle(id: "mate1", name: "mate1", category: "x", difficulty: 2, stars: 2,
                   description: "", playerSide: "red",
                   initialFEN: "3ak4/9/9/9/9/9/9/9/9/3AK4 w",
                   solution: ["b0c1"], hints: nil, maxMoves: 1,
                   solutionType: "checkmate"),
        ]
    }

    // MARK: - dailyPuzzleId 行为

    /// 空 puzzles 数组 → nil（cannonOnly 路径）
    func testDailyPuzzleIdEmptyPuzzlesReturnsNil() {
        let manager = makeManager()
        let result = manager.dailyPuzzleId(puzzles: [])
        XCTAssertNil(result, "空 puzzles 应返回 nil（cannonOnly 传入 puzzles: []）")
    }

    /// 非 nil puzzles → 返回某个 puzzle id（endgameStart/solveMate 路径）
    func testDailyPuzzleIdNonEmptyReturnsId() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()
        let result = manager.dailyPuzzleId(puzzles: puzzles)
        XCTAssertNotNil(result, "非空 puzzles 应返回 puzzle id")
        XCTAssertTrue(puzzles.contains { $0.id == result }, "返回的 id 应在 puzzles 中")
    }

    // MARK: - completeChallenge 状态验证

    /// cannonOnly 完成后：completed=true, puzzleId=nil, score>0
    /// 关键：cannonOnly 传入 puzzles=[] → todayChallenge(puzzles: []) 生成 puzzleId=nil 的 challenge
    func testCannonOnlyCompletedState() {
        let manager = makeManager()

        // 模拟 cannonOnly 流程：completeChallenge(score: 100, puzzles: [])
        // todayChallenge(puzzles: []) 会生成 puzzleId=nil 的 challenge
        manager.completeChallenge(score: 100, puzzles: [])

        // 用同样空的 puzzles 查询，确保获取同一个 challenge
        let updated = manager.todayChallenge(puzzles: [])
        XCTAssertTrue(updated.completed, "cannonOnly 完成后 completed 应为 true")
        XCTAssertNil(updated.puzzleId, "cannonOnly 完成后 puzzleId 应为 nil（规则变体无残局关联）")
        XCTAssertGreaterThan(updated.score, 0, "cannonOnly 获胜后 score 应 > 0")
    }

    /// cannonOnly 失败后：completed=true, puzzleId=nil, score=0（bonusDoubleScore 不影响 0）
    func testCannonOnlyFailedState() {
        let manager = makeManager()

        manager.completeChallenge(score: 0, puzzles: [])

        let updated = manager.todayChallenge(puzzles: [])
        XCTAssertTrue(updated.completed, "cannonOnly 失败后 completed 也应为 true")
        XCTAssertNil(updated.puzzleId, "cannonOnly 失败后 puzzleId 仍为 nil")
        XCTAssertEqual(updated.score, 0, "cannonOnly 失败后 score 应为 0（0*2=0）")
    }

    /// endgameStart 完成后：completed=true, puzzleId≠nil, score>0
    func testEndgameStartCompletedState() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()

        // endgameStart 传入实际 puzzles → todayChallenge(puzzles:) 生成 puzzleId≠nil 的 challenge
        manager.completeChallenge(score: 100, puzzles: puzzles)

        let updated = manager.todayChallenge(puzzles: puzzles)
        XCTAssertTrue(updated.completed, "endgameStart 完成后 completed 应为 true")
        XCTAssertNotNil(updated.puzzleId, "endgameStart 完成后 puzzleId 应非 nil")
        XCTAssertGreaterThan(updated.score, 0, "endgameStart 获胜后 score 应 > 0")
    }

    /// solveMate 完成后：completed=true, puzzleId≠nil, score>0
    func testSolveMateCompletedState() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()

        manager.completeChallenge(score: 100, puzzles: puzzles)

        let updated = manager.todayChallenge(puzzles: puzzles)
        XCTAssertTrue(updated.completed, "solveMate 完成后 completed 应为 true")
        XCTAssertNotNil(updated.puzzleId, "solveMate 完成后 puzzleId 应非 nil")
        XCTAssertGreaterThan(updated.score, 0, "solveMate 获胜后 score 应 > 0")
    }

    // MARK: - cannonOnly vs endgameStart/solveMate 的 puzzleId 差异（核心验证）

    /// cannonOnly 的 puzzleId 为 nil，而 endgameStart/solveMate 的 puzzleId 非 nil
    /// 这是 Phase 3 注释强调的设计意图
    func testCannonOnlyPuzzleIdDiffersFromPuzzleModes() {
        let cannonManager = makeManager()
        let puzzleManager = makeManager()
        let puzzles = makeTestPuzzles()

        // cannonOnly 路径
        let cannonChallenge = cannonManager.todayChallenge(puzzles: [])
        XCTAssertNil(cannonChallenge.puzzleId, "cannonOnly 生成的 challenge puzzleId 应为 nil")

        // puzzle-based 路径
        let puzzleChallenge = puzzleManager.todayChallenge(puzzles: puzzles)
        XCTAssertNotNil(puzzleChallenge.puzzleId, "puzzle-based 模式的 challenge puzzleId 应非 nil")
    }

    // MARK: - completeChallenge 不改变 mode

    /// 完成挑战后 mode 不变
    func testCompleteChallengeDoesNotChangeMode() {
        let manager = makeManager()

        let originalMode = manager.todayChallenge(puzzles: []).mode
        manager.completeChallenge(score: 100, puzzles: [])

        let updated = manager.todayChallenge(puzzles: [])
        XCTAssertEqual(updated.mode, originalMode, "完成挑战后 mode 不应改变")
    }

    // MARK: - DailyChallenge 结构体验证

    /// DailyChallenge puzzleId 为 nil 时的 Codable 兼容
    func testDailyChallengeCodableWithNilPuzzleId() throws {
        let challenge = DailyChallenge(
            date: "2026-07-19",
            mode: .cannonOnly,
            puzzleId: nil,
            targetDifficulty: .amateurLow,
            completed: true,
            score: 100
        )
        let encoded = try JSONEncoder().encode(challenge)
        let decoded = try JSONDecoder().decode(DailyChallenge.self, from: encoded)

        XCTAssertEqual(decoded.mode, .cannonOnly)
        XCTAssertNil(decoded.puzzleId, "puzzleId nil 应在 Codable 后保持 nil")
        XCTAssertTrue(decoded.completed)
        XCTAssertEqual(decoded.score, 100)
    }

    /// DailyChallenge puzzleId 非 nil 时的 Codable 兼容
    func testDailyChallengeCodableWithPuzzleId() throws {
        let challenge = DailyChallenge(
            date: "2026-07-19",
            mode: .endgameStart,
            puzzleId: "puzzle_42",
            targetDifficulty: .amateurLow,
            completed: true,
            score: 100
        )
        let encoded = try JSONEncoder().encode(challenge)
        let decoded = try JSONDecoder().decode(DailyChallenge.self, from: encoded)

        XCTAssertEqual(decoded.mode, .endgameStart)
        XCTAssertEqual(decoded.puzzleId, "puzzle_42", "puzzleId 应在 Codable 后保持非 nil")
        XCTAssertTrue(decoded.completed)
        XCTAssertEqual(decoded.score, 100)
    }

    // MARK: - needsPuzzle 与 puzzleId 一致性

    /// cannonOnly needsPuzzle=false → puzzleId 应为 nil
    func testCannonOnlyNeedsPuzzleFalseConsistentWithNilPuzzleId() {
        XCTAssertFalse(DailyChallengeMode.cannonOnly.needsPuzzle,
            "cannonOnly needsPuzzle 应为 false")
    }

    /// endgameStart needsPuzzle=true → 加载时必须有 puzzle
    func testEndgameStartNeedsPuzzleTrueRequiresPuzzle() {
        XCTAssertTrue(DailyChallengeMode.endgameStart.needsPuzzle,
            "endgameStart needsPuzzle 应为 true")
    }

    /// solveMate needsPuzzle=true → 加载时必须有 puzzle
    func testSolveMateNeedsPuzzleTrueRequiresPuzzle() {
        XCTAssertTrue(DailyChallengeMode.solveMate.needsPuzzle,
            "solveMate needsPuzzle 应为 true")
    }
}
