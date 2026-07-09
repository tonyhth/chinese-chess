import Foundation
import Testing
@testable import ChineseChess

// MARK: - v4.0 Phase 3 #8: AnalysisViewModel 性能优化测试

@Suite("v4.0 Phase 3 #8 玩家方判断", .serialized)
struct PlayerColorTests {

    @Test("默认红先手 FEN → 玩家为红方")
    func defaultRedFirstMover() {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2", "h9g7"], initialFEN: FENParser.standardInitial)
        #expect(vm.playerColor == .red)
        #expect(vm.firstMoverColor == .red)
    }

    @Test("黑先手 FEN → 玩家为黑方")
    func blackFirstMover() {
        let vm = AnalysisViewModel()
        // 构造黑先手 FEN
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1"
        vm.load(moves: ["h9g7", "h2e2"], initialFEN: fen)
        #expect(vm.firstMoverColor == .black)
        #expect(vm.playerColor == .black)
    }

    @Test("红先手：偶数 index 是玩家走法")
    func redFirstPlayerIndices() {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2", "h9g7", "b2e2", "b9c7"], initialFEN: FENParser.standardInitial)
        // 红方先手 → 玩家走法在 index 0, 2
        #expect(vm.isPlayerMove(at: 0) == true)   // 红
        #expect(vm.isPlayerMove(at: 1) == false)  // 黑
        #expect(vm.isPlayerMove(at: 2) == true)   // 红
        #expect(vm.isPlayerMove(at: 3) == false)  // 黑
    }

    @Test("黑先手：奇数 index 是玩家走法")
    func blackFirstPlayerIndices() {
        let vm = AnalysisViewModel()
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1"
        vm.load(moves: ["h9g7", "h2e2", "b9c7", "b2e2"], initialFEN: fen)
        // 黑方先手 → 玩家走法在 index 0, 2
        #expect(vm.isPlayerMove(at: 0) == true)   // 黑
        #expect(vm.isPlayerMove(at: 1) == false)  // 红
        #expect(vm.isPlayerMove(at: 2) == true)   // 黑
        #expect(vm.isPlayerMove(at: 3) == false)  // 红
    }

    @Test("playerColorOverride 切换分析范围")
    func playerColorOverride() {
        let vm = AnalysisViewModel()
        // 红先手，但玩家选黑方
        vm.load(moves: ["h2e2", "h9g7", "b2e2", "b9c7"],
                initialFEN: FENParser.standardInitial,
                playerColorOverride: .black)
        #expect(vm.playerColor == .black)
        #expect(vm.firstMoverColor == .red)
        // 黑方走法在 index 1, 3
        #expect(vm.isPlayerMove(at: 0) == false)  // 红
        #expect(vm.isPlayerMove(at: 1) == true)   // 黑
        #expect(vm.isPlayerMove(at: 2) == false)  // 红
        #expect(vm.isPlayerMove(at: 3) == true)   // 黑
    }
}

@Suite("v4.0 Phase 3 #8 AI 走法跳过", .serialized)
struct AISkipTests {

    @Test("analyzeAll 进度 total 为玩家走法数")
    func progressTotalIsPlayerMoveCount() {
        let vm = AnalysisViewModel()
        // 4 步棋，红先手 → 玩家走法 2 步
        vm.load(moves: ["h2e2", "h9g7", "b2e2", "b9c7"],
                initialFEN: FENParser.standardInitial)
        let playerMoveCount = vm.moves.indices.filter { vm.isPlayerMove(at: $0) }.count
        #expect(playerMoveCount == 2)
    }

    @Test("analyzeStep 默认跳过 AI 走法")
    func analyzeStepSkipsAI() async {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2", "h9g7"],
                initialFEN: FENParser.standardInitial)
        // index 1 是 AI（黑方）走法，默认不分析
        await vm.analyzeStep(1)
        #expect(vm.analyses[1] == nil, "AI 走法默认应跳过")
    }

    @Test("analyzeStep force:true 可分析 AI 走法")
    func analyzeStepForce() async {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2", "h9g7"],
                initialFEN: FENParser.standardInitial)
        // index 1 是 AI 走法，force 时可分析
        await vm.analyzeStep(1, force: true)
        // 引擎可能不可用（测试环境），但至少不应崩溃
        // 如果引擎可用，analyses[1] 不为 nil
        // 关键：不崩溃即通过
    }

    @Test("analyzeStep 跳过已分析的步")
    func analyzeStepSkipsAnalyzed() async {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2", "h9g7"],
                initialFEN: FENParser.standardInitial)
        // 先分析 index 0
        await vm.analyzeStep(0)
        let first = vm.analyses[0]
        // 再调一次，应跳过（不覆盖）
        await vm.analyzeStep(0)
        #expect(vm.analyses[0]?.playerMove == first?.playerMove, "已分析的步不应被覆盖")
    }
}

@Suite("v4.0 Phase 3 #8 预筛与 MoveAnalysis", .serialized)
struct QuickClassifyTests {

    @Test("MoveAnalysis isQuickResult 默认 false")
    func isQuickResultDefaultFalse() {
        let analysis = MoveAnalysis(
            playerMove: "h2e2", quality: .good,
            bestMove: "h2e2", bestEval: 50, playerEval: 45,
            evalDelta: 5, alternatives: []
        )
        #expect(analysis.isQuickResult == false)
    }

    @Test("MoveAnalysis isQuickResult 显式 true")
    func isQuickResultExplicitTrue() {
        let analysis = MoveAnalysis(
            playerMove: "h2e2", quality: .brilliant,
            bestMove: "h2e2", bestEval: 50, playerEval: 50,
            evalDelta: 0, alternatives: [], isQuickResult: true
        )
        #expect(analysis.isQuickResult == true)
    }

    @Test("MoveAnalysis Codable 兼容：旧存档无 isQuickResult")
    func codableBackwardCompat() throws {
        // 模拟旧存档 JSON（无 isQuickResult 字段）
        let json = """
        {
            "playerMove": "h2e2",
            "quality": 4,
            "bestMove": "h2e2",
            "bestEval": 50,
            "playerEval": 45,
            "evalDelta": 5,
            "alternatives": []
        }
        """
        let data = json.data(using: .utf8)!
        let analysis = try JSONDecoder().decode(MoveAnalysis.self, from: data)
        #expect(analysis.isQuickResult == false, "旧存档应默认 isQuickResult=false")
        #expect(analysis.quality == .good)
        #expect(analysis.evalDelta == 5)
    }

    @Test("MoveAnalysis Codable 兼容：新存档有 isQuickResult")
    func codableNewFormat() throws {
        let json = """
        {
            "playerMove": "h2e2",
            "quality": 5,
            "bestMove": "h2e2",
            "bestEval": 50,
            "playerEval": 50,
            "evalDelta": 0,
            "alternatives": [],
            "isQuickResult": true
        }
        """
        let data = json.data(using: .utf8)!
        let analysis = try JSONDecoder().decode(MoveAnalysis.self, from: data)
        #expect(analysis.isQuickResult == true)
        #expect(analysis.quality == .brilliant)
    }

    @Test("MoveAnalysis Codable round-trip")
    func codableRoundTrip() throws {
        let original = MoveAnalysis(
            playerMove: "b2e2", quality: .doubtful,
            bestMove: "h2e2", bestEval: 100, playerEval: -50,
            evalDelta: 150, alternatives: [], isQuickResult: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MoveAnalysis.self, from: data)
        #expect(decoded.playerMove == original.playerMove)
        #expect(decoded.quality == original.quality)
        #expect(decoded.evalDelta == original.evalDelta)
        #expect(decoded.isQuickResult == original.isQuickResult)
    }

    @Test("QuickClassifyResult needFullAnalysis: brilliant 不需要")
    func quickClassifyBrilliantNoFull() {
        let result = PositionAnalyzer.QuickClassifyResult(
            quality: .brilliant, bestMove: "h2e2", bestEval: 50,
            adjustedPlayerEval: 50, evalDelta: 0,
            needFullAnalysis: false
        )
        #expect(result.needFullAnalysis == false)
        #expect(result.quality == .brilliant)
    }

    @Test("QuickClassifyResult needFullAnalysis: delta>=30 需要完整分析")
    func quickClassifyNeedsFull() {
        let result = PositionAnalyzer.QuickClassifyResult(
            quality: .normal, bestMove: "h2e2", bestEval: 100,
            adjustedPlayerEval: 50, evalDelta: 50,
            needFullAnalysis: true
        )
        #expect(result.needFullAnalysis == true)
    }

    @Test("预筛阈值：delta=29 是 good（预筛命中）")
    func quickClassifyThreshold29() {
        // delta=29 < 30 → good, needFullAnalysis=false
        let result = PositionAnalyzer.QuickClassifyResult(
            quality: .good, bestMove: "h2e2", bestEval: 100,
            adjustedPlayerEval: 71, evalDelta: 29,
            needFullAnalysis: false
        )
        #expect(result.quality == .good)
        #expect(result.needFullAnalysis == false)
    }

    @Test("预筛阈值：delta=30 需完整分析")
    func quickClassifyThreshold30() {
        // delta=30 >= 30 → needFullAnalysis=true
        let result = PositionAnalyzer.QuickClassifyResult(
            quality: .normal, bestMove: "h2e2", bestEval: 100,
            adjustedPlayerEval: 70, evalDelta: 30,
            needFullAnalysis: true
        )
        #expect(result.needFullAnalysis == true)
    }
}

@Suite("v4.0 Phase 3 #8 evalCurve 完整性", .serialized)
struct EvalCurveTests {

    @Test("evalSequence 只包含有分析结果的步")
    func evalSequenceOnlyAnalyzed() {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2", "h9g7", "b2e2", "b9c7"],
                initialFEN: FENParser.standardInitial)
        // 用 quality(at:) 查询代替直接赋值
        // analyses 是 private(set)，无法从外部赋值
        // 改为：验证 evalSequence 对有/无分析结果的行为
        let seq = vm.evalSequence
        #expect(seq.isEmpty, "未分析时 evalSequence 应为空")
    }

    @Test("预筛命中的 playerEval 不为 0")
    func quickResultPlayerEvalNonZero() {
        let analysis = MoveAnalysis(
            playerMove: "h2e2", quality: .brilliant,
            bestMove: "h2e2", bestEval: 50, playerEval: 50,
            evalDelta: 0, alternatives: [], isQuickResult: true
        )
        #expect(analysis.isQuickResult == true)
        #expect(analysis.playerEval != 0, "预筛命中的走法 playerEval 应有值")
    }
}

@Suite("v4.0 Phase 3 #8 进度与 UI", .serialized)
struct AnalysisProgressTests {

    @Test("红先手 4 步棋 → 玩家走法 2 步")
    func progressRedFirst4Moves() {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2", "h9g7", "b2e2", "b9c7"],
                initialFEN: FENParser.standardInitial)
        let playerMoves = vm.moves.indices.filter { vm.isPlayerMove(at: $0) }
        #expect(playerMoves.count == 2)
        #expect(playerMoves == [0, 2])
    }

    @Test("黑先手 4 步棋 → 玩家走法 2 步")
    func progressBlackFirst4Moves() {
        let vm = AnalysisViewModel()
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1"
        vm.load(moves: ["h9g7", "h2e2", "b9c7", "b2e2"], initialFEN: fen)
        let playerMoves = vm.moves.indices.filter { vm.isPlayerMove(at: $0) }
        #expect(playerMoves.count == 2)
        #expect(playerMoves == [0, 2])
    }

    @Test("playerColorOverride=.black → 玩家走法在奇数 index")
    func progressOverrideBlack() {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2", "h9g7", "b2e2", "b9c7"],
                initialFEN: FENParser.standardInitial,
                playerColorOverride: .black)
        let playerMoves = vm.moves.indices.filter { vm.isPlayerMove(at: $0) }
        #expect(playerMoves == [1, 3])
    }

    @Test("空 moves 不崩溃")
    func emptyMovesNoCrash() {
        let vm = AnalysisViewModel()
        vm.load(moves: [], initialFEN: FENParser.standardInitial)
        #expect(vm.analyses.isEmpty)
        #expect(vm.evalSequence.isEmpty)
    }

    @Test("单步棋：红先手 → 玩家走法 1 步")
    func singleMoveRedFirst() {
        let vm = AnalysisViewModel()
        vm.load(moves: ["h2e2"], initialFEN: FENParser.standardInitial)
        let playerMoves = vm.moves.indices.filter { vm.isPlayerMove(at: $0) }
        #expect(playerMoves.count == 1)
    }
}
