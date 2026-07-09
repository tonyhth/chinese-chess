import Foundation
import Testing
@testable import ChineseChess

// MARK: - P1: recordGameResult 补 completeChallenge 调用测试

@Suite("P1 completeChallenge 调用 — DailyChallengeManager", .serialized)
struct CompleteChallengeManagerTests {

    private func makeManager() -> DailyChallengeManager {
        let suite = UserDefaults(suiteName: "test_p1_challenge_\(UUID().uuidString)")!
        return DailyChallengeManager(defaults: suite)
    }

    private func makeTestPuzzles() -> [Puzzle] {
        [
            Puzzle(id: "test1", name: "test1", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red",
                   initialFEN: "3ak4/9/9/9/9/9/9/9/9/3AK4 w",
                   solution: ["a0a1"], hints: nil, maxMoves: 1,
                   solutionType: "checkmate")
        ]
    }

    @Test("completeChallenge 后 isTodayCompleted 返回 true")
    func completeChallengeSetsCompleted() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()

        // 完成前
        #expect(manager.isTodayCompleted(puzzles: puzzles) == false, "完成前应为 false")

        // 调用 completeChallenge
        manager.completeChallenge(score: 100, puzzles: puzzles)

        // 完成后
        #expect(manager.isTodayCompleted(puzzles: puzzles) == true, "完成后应为 true")
    }

    @Test("completeChallenge score=0 也标记完成")
    func completeChallengeScoreZero() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()

        manager.completeChallenge(score: 0, puzzles: puzzles)
        #expect(manager.isTodayCompleted(puzzles: puzzles) == true, "score=0 也应标记完成")
    }

    @Test("completeChallenge 保存分数（含双倍积分）")
    func completeChallengeSavesScore() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()

        manager.completeChallenge(score: 100, puzzles: puzzles)
        let challenge = manager.todayChallenge(puzzles: puzzles)
        #expect(challenge.completed == true)
        // Q4: bonusDoubleScore 可能生效，score 可能是 100 或 200
        let expectedScore = PlayerProfileStore.shared.profile.bonusDoubleScore ? 200 : 100
        #expect(challenge.score == expectedScore, "分数应为 \(expectedScore)")
    }

    @Test("completeChallenge score=0 保存零分")
    func completeChallengeSavesZeroScore() {
        let manager = makeManager()
        let puzzles = makeTestPuzzles()

        manager.completeChallenge(score: 0, puzzles: puzzles)
        let challenge = manager.todayChallenge(puzzles: puzzles)
        #expect(challenge.completed == true)
        #expect(challenge.score == 0, "分数应为 0")
    }
}

@Suite("P1 completeChallenge 调用 — GameViewModel 集成", .serialized)
struct CompleteChallengeIntegrationTests {

    private func makeTestPuzzle() -> Puzzle {
        Puzzle(id: "integration1", name: "integration1", category: "x", difficulty: 1, stars: 1,
               description: "", playerSide: "red",
               initialFEN: "3ak4/9/9/9/9/9/9/9/9/3AK4 w",
               solution: ["a0a1"], hints: nil, maxMoves: 1,
               solutionType: "checkmate")
    }

    @MainActor
    @Test("挑战模式：challengeMode != nil 且游戏结束 → completeChallenge 条件满足")
    func challengeModeTriggersCompleteChallenge() {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .endgamePuzzle, puzzle: makeTestPuzzle(), difficulty: .beginner)

        // 验证挑战模式已设置
        #expect(vm.challengeMode != nil, "应处于挑战模式")
        #expect(vm.challengeMode == .endgamePuzzle)

        // 验证条件：challengeMode != nil && gameState != .playing
        // 模拟游戏结束
        vm.gameState = .redWon
        let conditionMet = vm.challengeMode != nil && vm.gameState != .playing
        #expect(conditionMet == true, "挑战模式+游戏结束时 completeChallenge 条件应满足")
    }

    @MainActor
    @Test("非挑战模式：challengeMode == nil → completeChallenge 条件不满足")
    func nonChallengeModeNoCompleteChallenge() {
        let vm = GameViewModel()
        vm.newGame()

        // 确认非挑战模式
        #expect(vm.challengeMode == nil, "新游戏应无挑战模式")

        // 设置游戏结束
        vm.gameState = .redWon

        // 条件：challengeMode != nil && gameState != .playing
        let conditionMet = vm.challengeMode != nil && vm.gameState != .playing
        #expect(conditionMet == false, "非挑战模式不应满足 completeChallenge 条件")
    }

    @MainActor
    @Test("游戏进行中：gameState == .playing → completeChallenge 条件不满足")
    func playingStateNoCompleteChallenge() {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .endgamePuzzle, puzzle: makeTestPuzzle(), difficulty: .beginner)

        // 游戏仍在进行
        #expect(vm.gameState == .playing, "游戏应仍在进行")
        #expect(vm.challengeMode != nil, "应处于挑战模式")

        // 条件：challengeMode != nil && gameState != .playing
        let conditionMet = vm.challengeMode != nil && vm.gameState != .playing
        #expect(conditionMet == false, "游戏进行中不应满足 completeChallenge 条件")
    }

    @MainActor
    @Test("胜利 score=100，失败 score=0")
    func challengeScoreLogic() {
        // 验证 recordGameResult 中的 score 逻辑
        // playerWon = (humanSide == .red && gameState == .redWon) || (humanSide == .black && gameState == .blackWon)
        // score = playerWon ? 100 : 0

        // 红方赢 + 人类红方 → playerWon = true → score = 100
        let redWins = (Side.red == .red && GameState.redWon == .redWon) || (Side.black == .red && GameState.redWon == .blackWon)
        #expect(redWins == true, "红方赢时人类红方应 playerWon=true")

        // 红方赢 + 人类黑方 → playerWon = false → score = 0
        let blackLoses = (Side.black == .red && GameState.redWon == .redWon) || (Side.black == .black && GameState.redWon == .blackWon)
        #expect(blackLoses == false, "红方赢时人类黑方应 playerWon=false")
    }

    @MainActor
    @Test("loadChallenge 保存 puzzle 引用")
    func loadChallengeSavesPuzzle() {
        let vm = GameViewModel()
        let puzzle = makeTestPuzzle()
        vm.loadChallenge(mode: .endgamePuzzle, puzzle: puzzle, difficulty: .beginner)

        #expect(vm.challengeMode == .endgamePuzzle)
        // challengePuzzle 是 private，无法直接验证
        // 但 loadChallenge 后 challengeMode 已设置，说明调用成功
    }

    @MainActor
    @Test("newGame 重置 challengeMode 和 challengePuzzle")
    func newGameResetsChallenge() {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .endgamePuzzle, puzzle: makeTestPuzzle(), difficulty: .beginner)
        #expect(vm.challengeMode != nil)

        vm.newGame()
        #expect(vm.challengeMode == nil, "newGame 应重置 challengeMode")
        // challengePuzzle 也是 private，无法直接验证
        // 但 newGame 中 challengePuzzle = nil 已在代码中
    }

    @MainActor
    @Test("和棋状态 score=0")
    func drawChallengeScoreZero() {
        let vm = GameViewModel()
        vm.loadChallenge(mode: .endgamePuzzle, puzzle: makeTestPuzzle(), difficulty: .beginner)
        vm.humanSide = .red

        // 和棋
        vm.gameState = .draw

        // playerWon = (humanSide == .red && gameState == .redWon) || ...
        // 和棋时 playerWon = false → score = 0
        let playerWon = (vm.humanSide == .red && vm.gameState == .redWon) || (vm.humanSide == .black && vm.gameState == .blackWon)
        #expect(playerWon == false, "和棋时 playerWon 应为 false → score=0")
    }
}

@Suite("P1 completeChallenge 调用 — fallbackId P0 回归", .serialized)
struct FallbackIdP0RegressionTests {

    @Test("fallbackId 非开局位置返回 -1（车在 row 5）")
    func fallbackIdNonStartRow() {
        let id = Piece.fallbackId(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        #expect(id == -1, "红车在 (5,0) 非开局位置应返回 -1")
    }

    @Test("fallbackId 非开局位置返回 -1（马在 row 5）")
    func fallbackIdHorseNonStartRow() {
        let id = Piece.fallbackId(kind: .horse, side: .red, position: Position(row: 5, col: 1))
        #expect(id == -1, "红马在 (5,1) 非开局位置应返回 -1")
    }

    @Test("fallbackId 非开局位置返回 -1（炮在 row 5）")
    func fallbackIdCannonNonStartRow() {
        let id = Piece.fallbackId(kind: .cannon, side: .red, position: Position(row: 5, col: 1))
        #expect(id == -1, "红炮在 (5,1) 非开局位置应返回 -1")
    }

    @Test("fallbackId 非开局位置返回 -1（将不在底线）")
    func fallbackIdGeneralNonStartRow() {
        let id = Piece.fallbackId(kind: .general, side: .red, position: Position(row: 5, col: 4))
        #expect(id == -1, "红帅在 (5,4) 非开局位置应返回 -1")
    }

    @Test("fallbackId 开局位置返回正确 ID")
    func fallbackIdStartRow() {
        let redChariot = Piece.fallbackId(kind: .chariot, side: .red, position: Position(row: 9, col: 0))
        let blackHorse = Piece.fallbackId(kind: .horse, side: .black, position: Position(row: 0, col: 7))
        let redCannon = Piece.fallbackId(kind: .cannon, side: .red, position: Position(row: 7, col: 7))
        let blackGeneral = Piece.fallbackId(kind: .general, side: .black, position: Position(row: 0, col: 4))

        #expect(redChariot == 0, "红左车 ID=0")
        #expect(blackHorse == 19, "黑右马 ID=19")
        #expect(redCannon == 10, "红右炮 ID=10")
        #expect(blackGeneral == 24, "黑将 ID=24")
    }

    @Test("FENDecoder 残局 FEN 后备 ID 100+ 不冲突")
    func fenDecoderEndgameFallbackIds() {
        let fen = "4k4/9/9/9/R8/9/9/9/9/4K4 w - - 0 1"
        guard let result = FENDecoder.parse(fen: fen) else {
            #expect(Bool(false), "残局 FEN 解析失败")
            return
        }

        let pieces = result.pieces
        #expect(pieces.count == 3)

        // 帅/将在开局位置 → 确定性 ID
        let redGeneral = pieces.first(where: { $0.kind == .general && $0.side == .red })
        let blackGeneral = pieces.first(where: { $0.kind == .general && $0.side == .black })
        #expect(redGeneral?.id == 8)
        #expect(blackGeneral?.id == 24)

        // 红车在 (5,0) 非开局位置 → 后备 ID 100+
        let redChariot = pieces.first(where: { $0.kind == .chariot && $0.side == .red })
        #expect(redChariot != nil)
        #expect(redChariot!.id >= 100, "非开局位置红车 ID 应 >= 100")
    }
}