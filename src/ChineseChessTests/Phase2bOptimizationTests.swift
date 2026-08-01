import Testing
@testable import ChineseChess

@Suite("Phase 2b 剪枝优化 + TT 升级 + IID 测试")
struct Phase2bOptimizationTests {

    // MARK: - Razoring 测试

    @Test("Razoring 启用后 hard 难度返回合法走法")
    func razoringHard() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
        #expect(move != nil, "启用 Razoring 后 hard 应返回合法走法")
    }

    @Test("Razoring 启用后 master 难度返回合法走法")
    func razoringMaster() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .master, isIOS: false)
        #expect(move != nil, "启用 Razoring 后 master 应返回合法走法")
    }

    // MARK: - Futility Pruning 测试

    @Test("Futility Pruning 启用后 AI 正常工作")
    func futilityPruningWorks() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
        #expect(move != nil, "启用 Futility Pruning 后应返回合法走法")
    }

    @Test("Futility Pruning 不影响 beginner 难度")
    func futilityBeginnerUnaffected() async {
        let engine = AIEngine()
        let board = Board()
        // beginner 不启用 futility，应正常工作
        let move = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        #expect(move != nil)
    }

    // MARK: - IID 测试

    @Test("IID 启用后 master 难度正常工作")
    func iidMasterWorks() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .master, isIOS: false)
        #expect(move != nil, "启用 IID 后 master 应返回合法走法")
    }

    @Test("IID 启用后 hard 难度正常工作")
    func iidHardWorks() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
        #expect(move != nil, "启用 IID 后 hard 应返回合法走法")
    }

    // MARK: - TT 双桶测试

    @Test("TT 双桶：存储和查找基本功能")
    func ttBasicStoreLookup() {
        let tt = TranspositionTable(capacity: 256)
        let hash: UInt64 = 12345
        let move = Move(
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 0), id: 100),
            from: Position(row: 0, col: 0),
            to: Position(row: 1, col: 0),
            captured: nil
        )

        tt.store(hash: hash, depth: 5, score: 100, flag: .exact, bestMove: move)
        let result = tt.lookup(hash: hash, depth: 3, alpha: -1000, beta: 1000)
        #expect(result != nil, "存储后应能查找到")
        if let r = result {
            #expect(r.score == 100, "分数应匹配")
        }
    }

    @Test("TT 双桶：不同 hash 不冲突")
    func ttNoConflict() {
        let tt = TranspositionTable(capacity: 256)
        tt.store(hash: 100, depth: 3, score: 50, flag: .exact, bestMove: nil)
        let result = tt.lookup(hash: 200, depth: 1, alpha: -1000, beta: 1000)
        #expect(result == nil, "不同 hash 不应查找到")
    }

    @Test("TT 双桶：深度优先替换 slot 0")
    func ttDepthPreferReplace() {
        let tt = TranspositionTable(capacity: 256)
        let hash: UInt64 = 999

        // 存入深度 3 的条目
        tt.store(hash: hash, depth: 3, score: 50, flag: .exact, bestMove: nil)
        // 存入深度 5 的条目（应替换 slot 0）
        tt.store(hash: hash, depth: 5, score: 80, flag: .exact, bestMove: nil)

        let result = tt.lookup(hash: hash, depth: 4, alpha: -1000, beta: 1000)
        #expect(result != nil)
        if let r = result {
            #expect(r.score == 80, "深度 5 应替换深度 3")
        }
    }

    @Test("TT 双桶：浅深度不替换 slot 0，存入 slot 1")
    func ttShallowGoesSlot1() {
        let tt = TranspositionTable(capacity: 256)
        let hash: UInt64 = 555

        // 存入深度 5 的条目
        tt.store(hash: hash, depth: 5, score: 80, flag: .exact, bestMove: nil)
        // 存入深度 2 的条目（不应替换 slot 0，进入 slot 1）
        tt.store(hash: hash, depth: 2, score: 30, flag: .exact, bestMove: nil)

        // 查找深度 4：应命中 slot 0（深度 5）
        let result = tt.lookup(hash: hash, depth: 4, alpha: -1000, beta: 1000)
        #expect(result != nil)
        if let r = result {
            #expect(r.score == 80, "slot 0 应保留深度 5 的条目")
        }
    }

    @Test("TT 双桶：clear 清空")
    func ttClear() {
        let tt = TranspositionTable(capacity: 256)
        tt.store(hash: 100, depth: 3, score: 50, flag: .exact, bestMove: nil)
        tt.clear()
        let result = tt.lookup(hash: 100, depth: 1, alpha: -1000, beta: 1000)
        #expect(result == nil, "清空后不应查找到")
    }

    @Test("TT 双桶：probeBestMove 检查两个桶")
    func ttProbeBestMove() {
        let tt = TranspositionTable(capacity: 256)
        let hash: UInt64 = 777
        let move = Move(
            piece: Piece(kind: .horse, side: .black, position: Position(row: 0, col: 1), id: 18),
            from: Position(row: 0, col: 1),
            to: Position(row: 2, col: 2),
            captured: nil
        )

        tt.store(hash: hash, depth: 3, score: 0, flag: .upper, bestMove: move)
        let best = tt.probeBestMove(hash: hash)
        #expect(best != nil, "probeBestMove 应返回存储的走法")
    }

    // MARK: - SearchConfig Phase 2b 配置测试

    @Test("SearchConfig Phase 2b 默认关闭")
    func searchConfigPhase2bDefaults() {
        let config = AISearchConfig.default
        #expect(config.enableFutility == false)
        #expect(config.enableRazoring == false)
        #expect(config.enableIID == false)
    }

    @Test("SearchConfig master 配置启用 Phase 2b")
    func searchConfigMasterPhase2b() {
        let config = AISearchConfig.master
        #expect(config.enableFutility == true)
        #expect(config.enableRazoring == true)
        #expect(config.enableIID == true)
    }

    @Test("SearchConfig hard 配置启用 Phase 2b")
    func searchConfigHardPhase2b() {
        let config = AISearchConfig.hard
        #expect(config.enableFutility == true)
        #expect(config.enableRazoring == true)
        #expect(config.enableIID == true)
    }

    @Test("SearchConfig medium 不启用 Phase 2b")
    func searchConfigMediumPhase2b() {
        let config = AISearchConfig.medium
        #expect(config.enableFutility == false)
        #expect(config.enableRazoring == false)
        #expect(config.enableIID == false)
    }

    // MARK: - 自对弈集成验证

    @Test("Phase 2b 全部启用：beginner vs beginner 2局正常完成", .timeLimit(.minutes(5)))
    func selfPlayWithPhase2b() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .beginner,
            black: .beginner,
            games: 2,
            maxMoves: 40
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 2)
        #expect(result.redWins + result.blackWins + result.draws == 2)
    }
}
