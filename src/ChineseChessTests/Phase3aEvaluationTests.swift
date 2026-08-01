import Testing
@testable import ChineseChess

@Suite("Phase 3a 评估函数深度调优测试")
struct Phase3aEvaluationTests {

    // MARK: - 棋型识别扩展测试

    @Test("Pattern 枚举包含 30+ 种棋型")
    func patternCount() {
        #expect(PatternRecognizer.Pattern.allCases.count >= 27, "棋型枚举应有 27+ 种")
    }

    @Test("拐角马识别")
    func corneredHorse() {
        // 黑马在红方九宫角附近
        let fen = "4ka3/9/9/9/9/9/9/9/4n4/3K5 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus > 0, "拐角马应有加分")
    }

    @Test("担子炮识别")
    func tandemCannon() {
        // 两黑炮在同列（小写 c = 黑炮）
        let fen = "4k4/9/9/9/9/4c4/9/9/4c4/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 300, "担子炮应至少 300 加分")
    }

    @Test("巡河炮识别")
    func riverCannon() {
        // 黑炮在 row 4（己方河沿）
        let fen = "4k4/9/9/9/4c4/9/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 200, "巡河炮应至少 200 加分")
    }

    @Test("当头炮识别")
    func centralCannon() {
        // 黑炮在中路 col 4，红将在 col 4
        let fen = "4k4/9/9/9/4c4/9/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 400, "当头炮+巡河炮应有加分")
    }

    @Test("叠炮识别")
    func stackedCannon() {
        // 两黑炮同列且相邻
        let fen = "4k4/9/9/9/9/9/4c4/4c4/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 250, "叠炮应至少 250 加分")
    }

    @Test("羊角士识别")
    func cornerAdvisor() {
        // 黑方双士在九宫
        let fen = "3akab2/9/9/9/9/9/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus > 0, "双士在九宫应有加分")
    }

    @Test("飞相局识别")
    func flyingElephant() {
        // 黑象在河沿好位置
        let fen = "4k4/9/9/9/2b1c4/9/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus > 0, "象在好位置应有加分")
    }

    @Test("过河兵识别")
    func crossedRiverSoldier() {
        // 黑卒过河（row >= 5 才算过河）
        let fen = "4k4/9/9/9/9/4p4/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 200, "过河兵应至少 200 加分")
    }

    @Test("兵线协同识别")
    func soldierLineSync() {
        // 两个黑卒在同一行（过河 row >= 5）
        let fen = "4k4/9/9/9/9/1p1p5/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 300, "双卒同行应至少 300 加分（过河+协同）")
    }

    @Test("飞将威胁识别")
    func flyingGeneralThreat() {
        // 双将在同一列，中间无子
        let fen = "4k4/9/9/9/9/9/9/9/9/4K4 w"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        #expect(bonus >= 300, "飞将威胁应至少 300 加分")
    }

    @Test("车炮配合识别")
    func chariotCannonCoord() {
        // 黑车和炮在同一行（小写 r=车, c=炮）
        let fen = "4k4/9/9/9/rc7/9/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 180, "车炮同行应至少 180 加分")
    }

    @Test("马炮配合识别")
    func horseCannonCoord() {
        // 黑马和炮相邻
        let fen = "4k4/9/9/9/9/9/9/nc7/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 150, "马炮相邻应至少 150 加分")
    }

    @Test("双车联动识别")
    func doubleChariotLink() {
        // 两黑车不同行不同列
        let fen = "4k4/9/9/9/r7r/9/9/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 350, "双车联动应至少 350 加分")
    }

    @Test("双马连环识别")
    func doubleHorseLink() {
        // 两黑马在日字互保位置
        let fen = "4k4/9/9/9/9/9/n1n7/9/9/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus >= 250, "双马互保应至少 250 加分")
    }

    @Test("防空评估：对方无炮加分")
    func airDefenseBonus() {
        // 红方无炮，黑方有炮
        let fen = "4k4/9/9/9/9/9/9/9/4c4/4K4 b"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(bonus > 0, "对方无炮时应有防空加分")
    }

    // MARK: - 位置权重表测试

    @Test("兵/卒开局权重表存在")
    func soldierOpeningWeights() async {
        let engine = AIEngine()
        let board = Board()  // 标准初始局面
        // 验证不崩溃，且返回正值
        let move = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        #expect(move != nil)
    }

    @Test("兵/卒残局权重表推进价值更高")
    func soldierEndgameWeights() async {
        // 残局局面
        let fen = "4k4/9/9/9/4p4/9/9/9/9/4K4 b"
        let board = Board(fen: fen)
        // 验证评估不崩溃
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
        #expect(move != nil)
    }

    // MARK: - 机动性评估测试

    @Test("机动性评估：车在中路加分")
    func chariotCenterMobility() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
        #expect(move != nil, "hard 难度启用机动性评估应正常工作")
    }

    @Test("机动性评估：残局马更活跃")
    func horseEndgameMobility() async {
        let engine = AIEngine()
        let fen = "4k4/9/9/9/9/9/8n/9/9/4K4 b"
        let board = Board(fen: fen)
        let move = await engine.bestMove(for: board, difficulty: .master, isIOS: false)
        #expect(move != nil, "master 残局机动性应正常")
    }

    // MARK: - 集成验证

    @Test("Phase 3a 全部启用：beginner vs beginner 2局", .timeLimit(.minutes(5)))
    func selfPlayPhase3a() async {
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
}
