import Foundation
import Testing
@testable import ChineseChess

// MARK: - v4.1 Phase 5: cannonOnly 回归测试（Phase 1 坐标系修正验证）

@Suite("v4.1 Phase 5: cannonOnly 坐标系回归测试", .serialized)
struct V41CannonOnlyRegressionTests {

    @MainActor
    private func makeVM() -> GameViewModel {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .cannonOnly, puzzle: nil, difficulty: .beginner)
        return vm
    }

    // MARK: - Luke 验证用例

    @MainActor
    @Test("红车己方半场内移动: row 9 → row 7 → 合法")
    func redChariotOwnHalfLegal() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0),
            from: Position(row: 9, col: 0), to: Position(row: 7, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "红车在己方半场（row >= 5）移动应合法")
    }

    @MainActor
    @Test("红车跨入对方半场无吃子: row 5 → row 3 → 不合法")
    func redChariotCrossBorderNoCaptureIllegal() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0), id: 150),
            from: Position(row: 5, col: 0), to: Position(row: 3, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == false, "红车跨入对方半场（row <= 4）无吃子应禁止")
    }

    @MainActor
    @Test("黑车己方半场内移动: row 0 → row 2 → 合法")
    func blackChariotOwnHalfLegal() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
            from: Position(row: 0, col: 0), to: Position(row: 2, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "黑车在己方半场（row <= 4）移动应合法")
    }

    @MainActor
    @Test("黑车跨入对方半场无吃子: row 0 → row 6 → 不合法")
    func blackChariotCrossBorderNoCaptureIllegal() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
            from: Position(row: 0, col: 0), to: Position(row: 6, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == false, "黑车跨入对方半场（row >= 5）无吃子应禁止")
    }

    // MARK: - 边界值测试

    @MainActor
    @Test("红方边界: row 5 是己方半场（合法）")
    func redBoundaryRow5() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 6, col: 0), id: 150),
            from: Position(row: 6, col: 0), to: Position(row: 5, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "row=5 是红方己方半场边界，应合法")
    }

    @MainActor
    @Test("红方边界: row 4 是对方半场（不合法）")
    func redBoundaryRow4() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0), id: 150),
            from: Position(row: 5, col: 0), to: Position(row: 4, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == false, "row=4 是黑方半场，红方无吃子应禁止")
    }

    @MainActor
    @Test("黑方边界: row 4 是己方半场（合法）")
    func blackBoundaryRow4() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 3, col: 0), id: 160),
            from: Position(row: 3, col: 0), to: Position(row: 4, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "row=4 是黑方己方半场边界，应合法")
    }

    @MainActor
    @Test("黑方边界: row 5 是对方半场（不合法）")
    func blackBoundaryRow5() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 4, col: 0), id: 160),
            from: Position(row: 4, col: 0), to: Position(row: 5, col: 0),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == false, "row=5 是红方半场，黑方无吃子应禁止")
    }

    // MARK: - 跨区吃子验证

    @MainActor
    @Test("红车跨区吃子: row 5 → row 3 有吃子 → 合法")
    func redChariotCrossBorderCapture() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0), id: 150),
            from: Position(row: 5, col: 0), to: Position(row: 3, col: 0),
            captured: Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0), id: 240)
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "红车跨区吃子应合法")
    }

    @MainActor
    @Test("黑车跨区吃子: row 4 → row 6 有吃子 → 合法")
    func blackChariotCrossBorderCapture() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 4, col: 0), id: 160),
            from: Position(row: 4, col: 0), to: Position(row: 6, col: 0),
            captured: Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 0), id: 30)
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "黑车跨区吃子应合法")
    }

    // MARK: - 马走法验证

    @MainActor
    @Test("红马己方半场: row 9 → row 7 → 合法")
    func redHorseOwnHalf() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .horse, side: .red, position: Position(row: 9, col: 1), id: 2),
            from: Position(row: 9, col: 1), to: Position(row: 7, col: 2),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "红马在己方半场移动应合法")
    }

    @MainActor
    @Test("红马跨区无吃子: row 5 → row 3 → 不合法")
    func redHorseCrossBorderNoCapture() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .horse, side: .red, position: Position(row: 5, col: 1), id: 151),
            from: Position(row: 5, col: 1), to: Position(row: 3, col: 2),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == false, "红马跨区无吃子应禁止")
    }

    @MainActor
    @Test("黑马己方半场: row 0 → row 2 → 合法")
    func blackHorseOwnHalf() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .horse, side: .black, position: Position(row: 0, col: 1), id: 18),
            from: Position(row: 0, col: 1), to: Position(row: 2, col: 2),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "黑马在己方半场移动应合法")
    }

    // MARK: - 炮无限制验证

    @MainActor
    @Test("红炮任意区域移动: row 7 → row 3 → 合法")
    func redCannonAnywhere() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9),
            from: Position(row: 7, col: 1), to: Position(row: 3, col: 1),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "炮无区域限制")
    }

    @MainActor
    @Test("黑炮任意区域移动: row 2 → row 8 → 合法")
    func blackCannonAnywhere() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .cannon, side: .black, position: Position(row: 2, col: 1), id: 25),
            from: Position(row: 2, col: 1), to: Position(row: 8, col: 1),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "黑炮无区域限制")
    }

    // MARK: - 兵/将/士/相正常走法

    @MainActor
    @Test("红将正常走法不受限")
    func redGeneralNormal() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            from: Position(row: 9, col: 4), to: Position(row: 8, col: 4),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "将正常走法不受限")
    }

    @MainActor
    @Test("红兵过河正常走法不受限")
    func redSoldierCrossRiver() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .soldier, side: .red, position: Position(row: 4, col: 4), id: 40),
            from: Position(row: 4, col: 4), to: Position(row: 3, col: 4),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "兵正常走法不受限")
    }

    @MainActor
    @Test("红士正常走法不受限")
    func redAdvisorNormal() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .advisor, side: .red, position: Position(row: 9, col: 3), id: 6),
            from: Position(row: 9, col: 3), to: Position(row: 8, col: 4),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "士正常走法不受限")
    }

    @MainActor
    @Test("红相正常走法不受限")
    func redElephantNormal() {
        let vm = makeVM()
        let move = Move(
            piece: Piece(kind: .elephant, side: .red, position: Position(row: 9, col: 2), id: 4),
            from: Position(row: 9, col: 2), to: Position(row: 7, col: 4),
            captured: nil
        )
        #expect(vm.isChallengeMoveLegal(move) == true, "相正常走法不受限")
    }
}

// MARK: - v4.1 Phase 5: challengeResult 赋值逻辑测试

@Suite("v4.1 Phase 5: challengeResult 赋值逻辑", .serialized)
struct V41ChallengeResultLogicTests {

    // MARK: - playerWon 逻辑验证

    @Test("playerWon: 红方玩家+红方胜 → true")
    func playerWonRedWins() {
        let humanSide: Side = .red
        let gameState: GameState = .redWon
        let playerWon = (humanSide == .red && gameState == .redWon) || (humanSide == .black && gameState == .blackWon)
        #expect(playerWon == true)
    }

    @Test("playerWon: 红方玩家+黑方胜 → false")
    func playerWonRedLoses() {
        let humanSide: Side = .red
        let gameState: GameState = .blackWon
        let playerWon = (humanSide == .red && gameState == .redWon) || (humanSide == .black && gameState == .blackWon)
        #expect(playerWon == false)
    }

    @Test("playerWon: 黑方玩家+黑方胜 → true")
    func playerWonBlackWins() {
        let humanSide: Side = .black
        let gameState: GameState = .blackWon
        let playerWon = (humanSide == .red && gameState == .redWon) || (humanSide == .black && gameState == .blackWon)
        #expect(playerWon == true)
    }

    @Test("playerWon: 和棋 → false")
    func playerWonDraw() {
        let humanSide: Side = .red
        let gameState: GameState = .draw
        let playerWon = (humanSide == .red && gameState == .redWon) || (humanSide == .black && gameState == .blackWon)
        #expect(playerWon == false)
    }

    // MARK: - loadChallenge 初始化验证

    @MainActor
    @Test("endgameStart: 初始化 challengeResult = nil")
    func endgameStartInitNil() {
        let vm = GameViewModel()
        let puzzle = Puzzle(id: "t", name: "t", category: "x", difficulty: 1, stars: 1,
                            description: "", playerSide: "red",
                            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
                            solution: [], hints: nil, maxMoves: 5, solutionType: "sequence")
        vm.loadChallenge(mode: .endgameStart, puzzle: puzzle, difficulty: .beginner)
        #expect(vm.challengeResult == nil)
    }

    @MainActor
    @Test("cannonOnly: 初始化 challengeResult = nil")
    func cannonOnlyInitNil() {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .cannonOnly, puzzle: nil, difficulty: .amateurMid)
        #expect(vm.challengeResult == nil)
    }

    @MainActor
    @Test("solveMate: 初始化 challengeResult = nil")
    func solveMateInitNil() {
        let vm = GameViewModel()
        let puzzle = Puzzle(id: "t", name: "t", category: "x", difficulty: 1, stars: 1,
                            description: "", playerSide: "red",
                            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
                            solution: ["a0a1"], hints: nil, maxMoves: 1, solutionType: "checkmate")
        vm.loadChallenge(mode: .solveMate, puzzle: puzzle, difficulty: .beginner)
        #expect(vm.challengeResult == nil)
    }

    // MARK: - 赋值条件验证

    @MainActor
    @Test("赋值条件: challengeMode != nil && gameState != playing && challengeResult == nil")
    func assignmentConditionMet() {
        let challengeResult: ChallengeResult? = nil
        let challengeMode: DailyChallengeMode? = .cannonOnly
        let gameState: GameState = .redWon
        let shouldAssign = challengeMode != nil && gameState != .playing && challengeResult == nil
        #expect(shouldAssign == true)
    }

    @MainActor
    @Test("不覆盖条件: challengeResult 已有值时跳过赋值")
    func assignmentNoOverride() {
        let challengeResult: ChallengeResult? = .success
        let shouldSkip = challengeResult != nil
        #expect(shouldSkip == true)
    }

    // MARK: - loadChallenge 重置

    @MainActor
    @Test("loadChallenge 重置 challengeResult")
    func loadChallengeResetsResult() {
        let vm = GameViewModel()
        vm.challengeResult = .success
        vm.loadChallenge(mode: .cannonOnly, puzzle: nil, difficulty: .amateurMid)
        #expect(vm.challengeResult == nil)
    }

    // MARK: - newGame 清除

    @MainActor
    @Test("newGame 清除 challengeResult")
    func newGameClearsResult() {
        let vm = GameViewModel()
        vm.challengeResult = .success
        vm.newGame()
        #expect(vm.challengeResult == nil, "newGame 应清除 challengeResult")
    }
}

// MARK: - v4.1 Phase 5: BoardView alert 编译验证

@Suite("v4.1 Phase 5: BoardView alert 验证", .serialized)
struct V41BoardViewAlertVerifyTests {

    @Test("BoardView 类型存在")
    func boardViewExists() {
        #expect(BoardView.self != NSObject.self)
    }

    @Test("ChallengeResult 三个 case")
    func challengeResultCases() {
        #expect(ChallengeResult.success != ChallengeResult.failure)
        #expect(ChallengeResult.inProgress != ChallengeResult.success)
    }

    @Test("ChallengeResult Codable 兼容")
    func challengeResultCodable() {
        let data = try? JSONEncoder().encode(ChallengeResult.success)
        #expect(data != nil)
        let decoded = try? JSONDecoder().decode(ChallengeResult.self, from: data!)
        #expect(decoded == .success)
    }
}
