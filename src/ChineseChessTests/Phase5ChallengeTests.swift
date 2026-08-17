import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 5 每日挑战扩展测试（endgameStart + solveMate + cannonOnly）

@Suite("Phase 5 每日挑战扩展 — 模式分类", .serialized)
struct ChallengeModeClassificationTests {

    @Test("endgameStart isImplemented = true")
    func endgameStartImplemented() {
        #expect(DailyChallengeMode.endgameStart.isImplemented == true)
    }

    @Test("solveMate isImplemented = true")
    func solveMateImplemented() {
        #expect(DailyChallengeMode.solveMate.isImplemented == true)
    }

    @Test("cannonOnly isImplemented = true")
    func cannonOnlyImplemented() {
        #expect(DailyChallengeMode.cannonOnly.isImplemented == true)
    }

    @Test("endgameStart needsPuzzle = true")
    func endgameStartNeedsPuzzle() {
        #expect(DailyChallengeMode.endgameStart.needsPuzzle == true)
    }

    @Test("solveMate needsPuzzle = true")
    func solveMateNeedsPuzzle() {
        #expect(DailyChallengeMode.solveMate.needsPuzzle == true)
    }

    @Test("cannonOnly needsPuzzle = false")
    func cannonOnlyNeedsNoPuzzle() {
        #expect(DailyChallengeMode.cannonOnly.needsPuzzle == false)
    }

    @Test("endgameStart modeType = .game")
    func endgameStartModeType() {
        #expect(DailyChallengeMode.endgameStart.modeType == .game)
    }

    @Test("solveMate modeType = .puzzle")
    func solveMateModeType() {
        #expect(DailyChallengeMode.solveMate.modeType == .puzzle)
    }

    @Test("cannonOnly modeType = .game")
    func cannonOnlyModeType() {
        #expect(DailyChallengeMode.cannonOnly.modeType == .game)
    }

    @Test("ChallengeResult 三个 case")
    func challengeResultCases() {
        #expect(ChallengeResult(rawValue: "success") == .success)
        #expect(ChallengeResult(rawValue: "failure") == .failure)
        #expect(ChallengeResult(rawValue: "inProgress") == .inProgress)
    }

    @Test("ChallengeModeType 四个 case")
    func challengeModeTypeCases() {
        let allTypes: [ChallengeModeType] = [.puzzle, .game, .timed, .difficulty]
        #expect(allTypes.count == 4)
    }
}

@Suite("Phase 5 每日挑战扩展 — Puzzle 选取", .serialized)
struct ChallengePuzzleSelectionTests {

    private func makeManager() -> DailyChallengeManager {
        let suite = UserDefaults(suiteName: "test_phase5_\(UUID().uuidString)")!
        return DailyChallengeManager(defaults: suite)
    }

    private func makeTestPuzzles() -> [Puzzle] {
        [
            Puzzle(id: "easy1", name: "easy1", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red",
                   initialFEN: "3ak4/9/9/9/9/9/9/9/9/3AK4 w",
                   solution: ["a0a1"], hints: nil, maxMoves: 1,
                   solutionType: "checkmate"),
            Puzzle(id: "easy2", name: "easy2", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "black",
                   initialFEN: "3ak4/9/9/9/9/9/9/9/9/3AK4 b",
                   solution: ["a0a1", "a3a4"], hints: nil, maxMoves: 2,
                   solutionType: "checkmate"),
            Puzzle(id: "hard1", name: "hard1", category: "x", difficulty: 3, stars: 3,
                   description: "", playerSide: "red",
                   initialFEN: "3ak4/9/9/9/9/9/9/9/9/3AK4 w",
                   solution: ["a0a1", "a3a4", "a0a2"], hints: nil, maxMoves: 3,
                   solutionType: "sequence"),
            Puzzle(id: "mate1", name: "mate1", category: "x", difficulty: 2, stars: 2,
                   description: "", playerSide: "red",
                   initialFEN: "3ak4/9/9/9/9/9/9/9/9/3AK4 w",
                   solution: ["b0c1"], hints: nil, maxMoves: 1,
                   solutionType: "checkmate"),
        ]
    }

    @Test("endgameStartPuzzle 选取 difficulty=1 的残局")
    func endgameStartSelectsDifficulty1() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()
        let result = manager.endgameStartPuzzle(puzzles: puzzles)
        #expect(result != nil)
        #expect(result?.difficulty == 1, "应只选 difficulty=1 的残局")
    }

    @Test("endgameStartPuzzle 确定性：同一天多次调用结果一致")
    func endgameStartDeterministic() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()
        let result1 = manager.endgameStartPuzzle(puzzles: puzzles)
        let result2 = manager.endgameStartPuzzle(puzzles: puzzles)
        #expect(result1?.id == result2?.id, "同一天应返回同一 Puzzle")
    }

    @Test("endgameStartPuzzle 空候选返回 nil")
    func endgameStartEmptyCandidates() {
        let manager = makeManager()
        let puzzles = [
            Puzzle(id: "hard", name: "hard", category: "x", difficulty: 4, stars: 5,
                   description: "", playerSide: "red", initialFEN: "",
                   solution: [], hints: nil, maxMoves: 5)
        ]
        let result = manager.endgameStartPuzzle(puzzles: puzzles)
        #expect(result == nil, "无 difficulty=1 候选时应返回 nil")
    }

    @Test("solveMatePuzzle 选取一步杀残局")
    func solveMateSelectsOneMoveMate() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()
        let result = manager.solveMatePuzzle(puzzles: puzzles)
        #expect(result != nil)
        #expect(result?.solutionType == "checkmate")
        #expect(result?.solution.count == 1, "应选 solution.count==1 的残局")
    }

    @Test("solveMatePuzzle 确定性")
    func solveMateDeterministic() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()
        let result1 = manager.solveMatePuzzle(puzzles: puzzles)
        let result2 = manager.solveMatePuzzle(puzzles: puzzles)
        #expect(result1?.id == result2?.id)
    }

    @Test("solveMatePuzzle 排除多步 solution")
    func solveMateExcludesMultiMove() {
        let manager = makeManager()
        let puzzles = [
            Puzzle(id: "multi", name: "multi", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "",
                   solution: ["a0a1", "a3a4"], hints: nil, maxMoves: 2,
                   solutionType: "checkmate"),
        ]
        let result = manager.solveMatePuzzle(puzzles: puzzles)
        #expect(result == nil, "多步 solution 不应被选为一步杀")
    }

    @Test("solveMatePuzzle 排除非 checkmate 类型")
    func solveMateExcludesNonCheckmate() {
        let manager = makeManager()
        let puzzles = [
            Puzzle(id: "seq", name: "seq", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "",
                   solution: ["a0a1"], hints: nil, maxMoves: 1,
                   solutionType: "sequence"),
        ]
        let result = manager.solveMatePuzzle(puzzles: puzzles)
        #expect(result == nil, "非 checkmate 类型不应被选")
    }

    @Test("endgameStartPuzzle 排序一致性")
    func endgameStartSortedConsistency() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()
        // 多次调用，验证 id 在 easy1/easy2 中
        let result = manager.endgameStartPuzzle(puzzles: puzzles)
        #expect(result?.id == "easy1" || result?.id == "easy2", "应选自 difficulty=1 候选")
    }
}

@Suite("Phase 5 每日挑战扩展 — GameViewModel 挑战加载", .serialized)
struct ChallengeLoadTests {

    @MainActor
    private func makeTestPuzzle() -> Puzzle {
        Puzzle(id: "test1", name: "test", category: "x", difficulty: 1, stars: 1,
               description: "", playerSide: "red",
               initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
               solution: ["b2e2"], hints: nil, maxMoves: 1,
               solutionType: "checkmate")
    }

    @MainActor
    @Test("loadChallenge endgameStart 设置棋盘和执边")
    func loadEndgameStart() {
        let vm = GameViewModel()
        let puzzle = makeTestPuzzle()
        vm.loadChallenge(mode: .endgameStart, puzzle: puzzle, difficulty: .beginner)

        #expect(vm.challengeMode == .endgameStart)
        #expect(vm.humanSide == puzzle.side)
        #expect(vm.difficulty == .beginner)
        #expect(vm.isBlitzMode == false)
        #expect(vm.isMasterChallenge == false)
        #expect(vm.challengeResult == nil)
    }

    @MainActor
    @Test("loadChallenge solveMate 设置一步杀标记 + 60 秒限时")
    func loadSolveMate() {
        let vm = GameViewModel()
        let puzzle = makeTestPuzzle()
        vm.loadChallenge(mode: .solveMate, puzzle: puzzle, difficulty: .amateurLow)

        #expect(vm.challengeMode == .solveMate)
        #expect(vm.isOneStepMateMode == true)
        #expect(vm.isBlitzMode == true)
        #expect(vm.blitzTimeLimitSeconds == 60, "一步杀模式应限时 60 秒")
        #expect(vm.humanSide == puzzle.side)
    }

    @MainActor
    @Test("loadChallenge cannonOnly 标准局面")
    func loadCannonOnly() {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .cannonOnly, puzzle: nil, difficulty: .amateurMid)

        #expect(vm.challengeMode == .cannonOnly)
        #expect(vm.isBlitzMode == false)
        #expect(vm.isOneStepMateMode == false)
        #expect(vm.difficulty == .amateurMid)
    }

    @MainActor
    @Test("loadChallenge puzzle=nil 时 showChallengeUnavailable")
    func loadWithNilPuzzle() {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .endgameStart, puzzle: nil, difficulty: .beginner)

        #expect(vm.showChallengeUnavailable == true, "Puzzle 为空时应弹 unavailable alert")
    }

    @MainActor
    @Test("loadChallenge solveMate puzzle=nil 时 showChallengeUnavailable")
    func solveMateWithNilPuzzle() {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .solveMate, puzzle: nil, difficulty: .beginner)

        #expect(vm.showChallengeUnavailable == true)
    }

    @MainActor
    @Test("loadChallenge 重置之前的挑战状态")
    func loadChallengeResetsState() {
        let vm = GameViewModel()
        vm.challengeResult = .success
        vm.showChallengeRuleViolation = true
        vm.isOneStepMateMode = true

        vm.loadChallenge(mode: .cannonOnly, puzzle: nil, difficulty: .beginner)

        #expect(vm.challengeResult == nil, "应重置 challengeResult")
        #expect(vm.showChallengeRuleViolation == false, "应重置规则违规")
        #expect(vm.isOneStepMateMode == false, "cannonOnly 不应设一步杀标记")
    }
}

@Suite("Phase 5 每日挑战扩展 — 走法限制", .serialized)
struct ChallengeMoveRestrictionTests {

    @MainActor
    private func makeCannonOnlyVM() -> GameViewModel {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .cannonOnly, puzzle: nil, difficulty: .beginner)
        return vm
    }

    @MainActor
    @Test("cannonOnly: 炮无限制")
    func cannonNoRestriction() {
        let vm = makeCannonOnlyVM()
        // 炮在己方半场移动
        let cannonMove = Move(
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9),
            from: Position(row: 7, col: 1), to: Position(row: 7, col: 4),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(cannonMove) == true, "炮移动不应受限")
    }

    @MainActor
    @Test("cannonOnly: 车在己方半场可移动")
    func chariotInOwnHalf() {
        let vm = makeCannonOnlyVM()
        // 红车在己方半场（row 5-9）移动
        let chariotMove = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0),
            from: Position(row: 9, col: 0), to: Position(row: 8, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(chariotMove) == true, "车在己方半场可移动")
    }

    @MainActor
    @Test("cannonOnly: 车跨区吃子允许")
    func chariotCrossBorderCapture() {
        let vm = makeCannonOnlyVM()
        // 红车从己方半场跨到对方半场吃子
        let chariotMove = Move(
            piece: TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0)),
            from: Position(row: 5, col: 0), to: Position(row: 4, col: 0),
            captured: TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 4, col: 0))
        )
        #expect(vm.isChallengeMoveLegal(chariotMove) == true, "车跨区吃子应允许")
    }

    @MainActor
    @Test("cannonOnly: 车跨区无吃子禁止")
    func chariotCrossBorderNoCapture() {
        let vm = makeCannonOnlyVM()
        // 红车从己方半场跨到对方半场（无吃子）
        let chariotMove = Move(
            piece: TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0)),
            from: Position(row: 5, col: 0), to: Position(row: 3, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(chariotMove) == false, "车跨区无吃子应禁止")
    }

    @MainActor
    @Test("cannonOnly: 马在己方半场可移动")
    func horseInOwnHalf() {
        let vm = makeCannonOnlyVM()
        let horseMove = Move(
            piece: Piece(kind: .horse, side: .red, position: Position(row: 9, col: 1), id: 2),
            from: Position(row: 9, col: 1), to: Position(row: 7, col: 2),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(horseMove) == true, "马在己方半场可移动")
    }

    @MainActor
    @Test("cannonOnly: 马跨区无吃子禁止")
    func horseCrossBorderNoCapture() {
        let vm = makeCannonOnlyVM()
        let horseMove = Move(
            piece: TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 5, col: 1)),
            from: Position(row: 5, col: 1), to: Position(row: 3, col: 2),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(horseMove) == false, "马跨区无吃子应禁止")
    }

    @MainActor
    @Test("cannonOnly: 兵/将/士/相正常走法")
    func otherPiecesNormal() {
        let vm = makeCannonOnlyVM()
        let kingMove = Move(
            piece: Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            from: Position(row: 9, col: 4), to: Position(row: 8, col: 4),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(kingMove) == true, "将的正常走法不受限")
    }

    @MainActor
    @Test("非挑战模式所有走法合法")
    func nonChallengeModeAllLegal() {
        let vm = GameViewModel()
        // challengeMode = nil（默认）
        let anyMove = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0),
            from: Position(row: 9, col: 0), to: Position(row: 0, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(anyMove) == true, "非挑战模式不走法限制")
    }

    @MainActor
    @Test("endgameStart 模式无走法限制")
    func endgameStartNoRestriction() {
        let vm = GameViewModel()
        let puzzle = Puzzle(id: "t", name: "t", category: "x", difficulty: 1, stars: 1,
                            description: "", playerSide: "red",
                            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
                            solution: ["b2e2"], hints: nil, maxMoves: 1, solutionType: "checkmate")
        vm.loadChallenge(mode: .endgameStart, puzzle: puzzle, difficulty: .beginner)

        let chariotMove = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0),
            from: Position(row: 9, col: 0), to: Position(row: 0, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(chariotMove) == true, "endgameStart 不限制走法")
    }

    @MainActor
    @Test("黑方己方半场判断正确（row >= 5）")
    func blackOwnHalfCorrect() {
        let vm = makeCannonOnlyVM()
        // 黑车在己方半场（row 0-4）
        let blackMove = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
            from: Position(row: 0, col: 0), to: Position(row: 2, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(blackMove) == true, "黑方在 row 0-4 为己方半场")
    }
}

@Suite("Phase 5 每日挑战扩展 — newGame 重置", .serialized)
struct ChallengeNewGameResetTests {

    @MainActor
    @Test("newGame 清除挑战模式状态")
    func newGameClearsChallengeState() {
        let vm = GameViewModel()
        let puzzle = Puzzle(id: "t", name: "t", category: "x", difficulty: 1, stars: 1,
                            description: "", playerSide: "red",
                            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
                            solution: ["b2e2"], hints: nil, maxMoves: 1, solutionType: "checkmate")
        vm.loadChallenge(mode: .solveMate, puzzle: puzzle, difficulty: .amateurLow)

        // 确认挑战状态已设
        #expect(vm.challengeMode == .solveMate)
        #expect(vm.isOneStepMateMode == true)

        // newGame 应清除所有挑战状态
        vm.newGame()

        #expect(vm.challengeMode == nil, "newGame 应清除 challengeMode")
        #expect(vm.isOneStepMateMode == false, "newGame 应清除 isOneStepMateMode")
        #expect(vm.challengeResult == nil, "newGame 应清除 challengeResult")
        #expect(vm.showChallengeRuleViolation == false)
        #expect(vm.showChallengeUnavailable == false)
    }
}

@Suite("Phase 5 每日挑战扩展 — 一步杀判定", .serialized)
struct OneStepMateTests {

    @MainActor
    @Test("isOneStepMateMode 默认 false")
    func defaultNotOneStepMate() {
        let vm = GameViewModel()
        #expect(vm.isOneStepMateMode == false)
    }

    @MainActor
    @Test("一步杀模式 challengeResult 初始为 nil")
    func oneStepMateResultStartsNil() {
        let vm = GameViewModel()
        let puzzle = Puzzle(id: "t", name: "t", category: "x", difficulty: 1, stars: 1,
                            description: "", playerSide: "red",
                            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
                            solution: ["b2e2"], hints: nil, maxMoves: 1, solutionType: "checkmate")
        vm.loadChallenge(mode: .solveMate, puzzle: puzzle, difficulty: .beginner)
        #expect(vm.challengeResult == nil, "挑战开始时 result 应为 nil")
    }
}

@Suite("Phase 5 每日挑战扩展 — 确定性选取", .serialized)
struct DeterministicSelectionTests {

    @Test("endgameStartPuzzle 跨实例确定性")
    func crossInstanceDeterministic() {
        let suite1 = UserDefaults(suiteName: "test_det_e1_\(UUID().uuidString)")!
        let suite2 = UserDefaults(suiteName: "test_det_e2_\(UUID().uuidString)")!
        let m1 = DailyChallengeManager(defaults: suite1)
        let m2 = DailyChallengeManager(defaults: suite2)

        let puzzles = [
            Puzzle(id: "a", name: "a", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "", solution: [],
                   hints: nil, maxMoves: 1, solutionType: "checkmate"),
            Puzzle(id: "b", name: "b", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "", solution: [],
                   hints: nil, maxMoves: 1, solutionType: "checkmate"),
            Puzzle(id: "c", name: "c", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "", solution: [],
                   hints: nil, maxMoves: 1, solutionType: "checkmate"),
        ]

        let r1 = m1.endgameStartPuzzle(puzzles: puzzles)
        let r2 = m2.endgameStartPuzzle(puzzles: puzzles)
        #expect(r1?.id == r2?.id, "不同实例同一天应选同一 Puzzle")
    }

    @Test("solveMatePuzzle 跨实例确定性")
    func crossInstanceSolveMateDeterministic() {
        let suite1 = UserDefaults(suiteName: "test_det_s1_\(UUID().uuidString)")!
        let suite2 = UserDefaults(suiteName: "test_det_s2_\(UUID().uuidString)")!
        let m1 = DailyChallengeManager(defaults: suite1)
        let m2 = DailyChallengeManager(defaults: suite2)

        let puzzles = [
            Puzzle(id: "m1", name: "m1", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "",
                   solution: ["x"], hints: nil, maxMoves: 1, solutionType: "checkmate"),
            Puzzle(id: "m2", name: "m2", category: "x", difficulty: 2, stars: 2,
                   description: "", playerSide: "red", initialFEN: "",
                   solution: ["y"], hints: nil, maxMoves: 1, solutionType: "checkmate"),
        ]

        let r1 = m1.solveMatePuzzle(puzzles: puzzles)
        let r2 = m2.solveMatePuzzle(puzzles: puzzles)
        #expect(r1?.id == r2?.id, "不同实例同一天应选同一 Puzzle")
    }
}

@Suite("Phase 5 每日挑战扩展 — View 类型编译验证", .serialized)
struct ChallengeViewExistenceTests {

    @Test("DailyChallengeView 类型存在")
    func dailyChallengeViewExists() {
        #expect(DailyChallengeView.self != NSObject.self)
    }

    @Test("BoardView 类型存在")
    func boardViewExists() {
        #expect(BoardView.self != NSObject.self)
    }

    @Test("ChallengeResult Codable 兼容")
    func challengeResultCodable() {
        let data = try? JSONEncoder().encode(ChallengeResult.success)
        #expect(data != nil)
        let decoded = try? JSONDecoder().decode(ChallengeResult.self, from: data!)
        #expect(decoded == .success)
    }
}
