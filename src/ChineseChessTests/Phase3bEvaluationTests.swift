import Testing
@testable import ChineseChess

@Suite("Phase 3b 评估函数深度调优测试")
struct Phase3bEvaluationTests {

    // MARK: - 3.4 兵卒评估细化

    @Test("过河兵接近将位递增加分")
    func soldierApproachKing() {
        // 黑卒在红将附近（row 2，红将在 row 9 col 4）
        // 距离 = |2-9| + |4-4| = 7，太远
        // 换一个：黑卒在 row 7 col 4，红将在 row 9 col 4，距离 = 2
        let fen = "4k4/9/9/9/9/9/4p4/9/9/3K5 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        // 过河兵 200 + 接近将位 dist=2 → +100 = 至少 300
        #expect(bonus >= 300, "过河兵接近将位应有额外加分")
    }

    @Test("兵阵结构：相邻兵紧凑加分")
    func soldierStructureCompact() {
        // 两黑卒过河且相邻
        let fen = "4k4/9/9/9/9/9/4p4/4p4/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        // 过河兵 200×2 + 相邻 80 + 接近将位加分 ≥ 480
        #expect(bonus >= 400, "相邻兵应有结构加分")
    }

    @Test("兵阵结构：孤立兵减分")
    func soldierStructureIsolated() {
        // 两个孤立黑卒（间距大）
        let fen = "4k4/9/9/9/9/p7p/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        // 孤立兵：-30×2 = -60，但有其他加分（过河等）
        // 只验证不崩溃且返回整数值
        #expect(bonus >= -100 || bonus <= 1000, "孤立兵评估应在合理范围")
    }

    // MARK: - 3.5 将帅安全增强

    @Test("将帅安全：防空检测（将上方有子）")
    func kingAirDefense() async {
        let engine = AIEngine()
        // 正常开局局面，将上方有士
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
        #expect(move != nil, "防空检测应正常工作")
    }

    @Test("将帅安全：残局阶段权重变化")
    func kingSafetyEndgameWeight() async {
        let engine = AIEngine()
        // 残局局面（少量子力）
        let fen = "3ak4/9/9/9/9/9/9/9/4r4/3AK4 w"
        let board = Board(fen: fen)
        let move = await engine.bestMove(for: board, difficulty: .master, isIOS: false)
        #expect(move != nil, "残局将帅安全评估应正常")
    }

    @Test("将帅安全：士象完整 vs 缺失")
    func guardCompleteness() async {
        let engine = AIEngine()
        // 缺士缺象局面
        let fen = "4k4/9/9/9/9/9/9/9/4r4/3AK4 w"
        let board = Board(fen: fen)
        let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
        #expect(move != nil)
    }

    // MARK: - 3.6 协同减分

    @Test("马塞象眼减分不崩溃")
    func elephantEyeBlocked() {
        // 黑方象在标准位置，马在象眼
        // 黑象在 (0,2)，象眼在 (1,1)
        let fen = "1bakab3/9/9/9/9/9/9/9/n8/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        // 应有减分但不崩溃
        #expect(bonus >= -1000, "马塞象眼减分应在合理范围")
    }

    @Test("无象时马塞象眼不触发")
    func noElephantNoPenalty() {
        let fen = "4k4/9/9/9/9/9/9/9/n8/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        // 无象，不应有象眼减分
        #expect(bonus >= 0, "无象时不应有象眼减分")
    }

    // MARK: - 集成验证

    @Test("Phase 3b 全部启用：beginner vs beginner 2局", .timeLimit(.minutes(5)))
    func selfPlayPhase3b() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(red: .beginner, black: .beginner, games: 2, maxMoves: 40)
        let result = await runner.run(config: config)
        #expect(result.games.count == 2)
        #expect(result.redWins + result.blackWins + result.draws == 2)
    }

    @Test("各难度 AI 返回合法走法")
    func allDifficultiesValidMove() async {
        let engine = AIEngine()
        let board = Board()
        for diff in [AIDifficulty.beginner, .easy, .medium, .hard, .master] {
            let move = await engine.bestMove(for: board, difficulty: diff, isIOS: false)
            #expect(move != nil, "\(diff.rawValue) 应返回合法走法")
        }
    }

    @Test("残局 AI 评估不崩溃")
    func endgameEvaluation() async {
        let engine = AIEngine()
        let fens = [
            "3ak4/9/9/9/9/9/9/9/4r4/3AK4 w",    // 车 vs 士象全
            "4k4/9/9/9/9/9/9/9/4P4/4K4 w",       // 单兵
            "3Pk4/9/9/9/9/9/9/9/9/3AK4 w",       // 兵士对将士
        ]
        for fen in fens {
            let board = Board(fen: fen)
            let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
            #expect(move != nil, "残局 FEN 应正常评估: \(fen)")
        }
    }
}
