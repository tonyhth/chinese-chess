import Testing
@testable import ChineseChess

// T-0923-OC-01 ④（KI-2026-0922-02 修法 A）：--calibrate-native 级别视角归账测试。
// 夹具按 run :110-118 实际持方语义构造（swapSides=true 奇数索引换手）；
// levelPerspective 按 game.redDifficulty == diffA 归账，自描述免奇偶推断。

@Suite("T-0923-OC-01 级别视角归账（levelPerspective）")
struct T0923OC01LevelPerspectiveTests {

    private func game(_ idx: Int, red: AIDifficulty, black: AIDifficulty,
                      _ result: GameState) -> SelfPlayGameResult {
        SelfPlayGameResult(gameIndex: idx, redDifficulty: red, blackDifficulty: black,
                           result: result, totalMoves: 100, reason: .normal, moveHistory: [])
    }

    @Test("换手轮换：红胜在奇偶局分属 diffA 胜/负（座位计数器会混计的形态）")
    func swapSidesAlternation() {
        let a = AIDifficulty.amateurMid, b = AIDifficulty.amateurHigh
        // swapSides=true 前两局：局0 红=diffA、局1 红=diffB（run 换手后实际持方）
        let games = [
            game(0, red: a, black: b, .redWon),
            game(1, red: b, black: a, .redWon),
        ]
        let s = SelfPlayRunner.levelPerspective(games: games, diffA: a)
        #expect(s.diffAWins == 1)
        #expect(s.diffALosses == 1)
        #expect(s.draws == 0)
        #expect(s.total == 2)
    }

    @Test("黑胜视角翻转：奇数局黑胜=diffA 胜")
    func blackWonFlipsPerspective() {
        let a = AIDifficulty.amateurLow, b = AIDifficulty.novice
        let games = [game(1, red: b, black: a, .blackWon)]  // 奇数局红=diffB，黑胜即 diffA 胜
        let s = SelfPlayRunner.levelPerspective(games: games, diffA: a)
        #expect(s.diffAWins == 1 && s.diffALosses == 0 && s.draws == 0)
    }

    @Test("不换手：红恒=diffA，红胜=胜/黑胜=负/和棋计入")
    func noSwap() {
        let a = AIDifficulty.novice, b = AIDifficulty.beginner
        let games = [
            game(0, red: a, black: b, .redWon),
            game(1, red: a, black: b, .blackWon),
            game(2, red: a, black: b, .draw),
        ]
        let s = SelfPlayRunner.levelPerspective(games: games, diffA: a)
        #expect(s.diffAWins == 1 && s.diffALosses == 1 && s.draws == 1 && s.total == 3)
    }

    @Test("未知终局不计（与 run 座位计数器同语义）")
    func unknownExcluded() {
        let a = AIDifficulty.amateurMid, b = AIDifficulty.amateurHigh
        let games = [
            game(0, red: a, black: b, .redWon),
            game(1, red: b, black: a, .playing),  // 中断局
        ]
        let s = SelfPlayRunner.levelPerspective(games: games, diffA: a)
        #expect(s.total == 1)
    }

    @Test("空局集归零")
    func emptyGames() {
        let s = SelfPlayRunner.levelPerspective(games: [], diffA: .novice)
        #expect(s.diffAWins == 0 && s.diffALosses == 0 && s.draws == 0 && s.total == 0)
    }

    @Test("KI-2026-0922-02 实证形态：lvl3v4 前两局红胜轮换→级别视角 1-1-0，非座位 2-0-0")
    func kiAnchorMini() {
        let lvl3 = AIDifficulty.amateurLow, lvl4 = AIDifficulty.amateurMid
        let games = [
            game(0, red: lvl3, black: lvl4, .redWon),
            game(1, red: lvl4, black: lvl3, .redWon),
        ]
        let s = SelfPlayRunner.levelPerspective(games: games, diffA: lvl3)
        #expect(s.diffAWins == 1 && s.diffALosses == 1,
                "级别视角 1-1-0（diffA=lvl3）；座位视角误得 2-0-0（红胜×2）——即 KI 误用源")
    }
}
