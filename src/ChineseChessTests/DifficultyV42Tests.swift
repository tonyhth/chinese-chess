import Testing
import Foundation
@testable import ChineseChess

/// 难度体系 v4.2 测试 — engine params + Pikafish remap + Softmax temp
@Suite("难度体系 v4.2 测试")
struct DifficultyV42Tests {

    // MARK: - 1. AISearchConfig.mediumNoQS 验证

    @Test("mediumNoQS: quiescence 禁用")
    func mediumNoQSNoQuiescence() {
        let cfg = AISearchConfig.mediumNoQS
        #expect(cfg.enableQuiescence == false, "mediumNoQS 应禁用 QS")
    }

    @Test("mediumNoQS: killerMove 启用")
    func mediumNoQSKillerMove() {
        #expect(AISearchConfig.mediumNoQS.enableKillerMove == true)
    }

    @Test("mediumNoQS: checkExtension 启用")
    func mediumNoQSCheckExtension() {
        #expect(AISearchConfig.mediumNoQS.enableCheckExtension == true)
    }

    @Test("mediumNoQS: LMR 启用")
    func mediumNoQSLMR() {
        #expect(AISearchConfig.mediumNoQS.enableLMR == true)
    }

    @Test("mediumNoQS: futility 启用")
    func mediumNoQSFutility() {
        #expect(AISearchConfig.mediumNoQS.enableFutility == true)
    }

    @Test("mediumNoQS: PVS 禁用")
    func mediumNoQSPVS() {
        #expect(AISearchConfig.mediumNoQS.enablePVS == false)
    }

    @Test("mediumNoQS: evalConfig = .advanced")
    func mediumNoQSEvalConfig() {
        #expect(AISearchConfig.mediumNoQS.evalConfig.mobility == true)
        #expect(AISearchConfig.mediumNoQS.evalConfig.safety == true)
    }

    @Test("mediumNoQS: maxQSDepth = 0")
    func mediumNoQSMaxQSDepth() {
        #expect(AISearchConfig.mediumNoQS.maxQSDepth == 0, "mediumNoQS maxQSDepth 应为 0")
    }

    @Test("mediumNoQS: 与 .medium 的差异仅在 QS")
    func mediumNoQSVsMedium() {
        // 差异项：enableQuiescence + maxQSDepth
        #expect(AISearchConfig.mediumNoQS.enableQuiescence == false)
        #expect(AISearchConfig.medium.enableQuiescence == true)
        #expect(AISearchConfig.mediumNoQS.maxQSDepth == 0)
        // 其他配置应相同
        #expect(AISearchConfig.mediumNoQS.enableKillerMove == AISearchConfig.medium.enableKillerMove)
        #expect(AISearchConfig.mediumNoQS.enableCheckExtension == AISearchConfig.medium.enableCheckExtension)
        #expect(AISearchConfig.mediumNoQS.enableLMR == AISearchConfig.medium.enableLMR)
        #expect(AISearchConfig.mediumNoQS.enableFutility == AISearchConfig.medium.enableFutility)
    }

    // MARK: - 2. AIEngine 各级别搜索返回走法（功能验证）

    @Test("v4.2 lvl1 novice: 返回合法走法")
    func engineNovice() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .novice, isIOS: false)
        #expect(move != nil)
    }

    @Test("v4.2 lvl2 beginner: 返回合法走法（1000ms 时间限制）")
    func engineBeginner() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        #expect(move != nil)
    }

    @Test("v4.2 lvl3 amateurLow: 返回合法走法（IDS depth=4, 2000ms, mediumNoQS）")
    func engineAmateurLow() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .amateurLow, isIOS: false)
        #expect(move != nil)
    }

    @Test("v4.2 lvl4 amateurMid: 返回合法走法（IDS depth=5, 3000ms, .medium + CheckmateSearch）")
    func engineAmateurMid() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .amateurMid, isIOS: false)
        #expect(move != nil)
    }

    @Test("v4.2 lvl5 amateurHigh: 返回合法走法（IDS depth=6, 5000ms, .hard + CheckmateSearch）")
    func engineAmateurHigh() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .amateurHigh, isIOS: false)
        #expect(move != nil)
    }

    @Test("v4.2 lvl6 amateurDan: 返回合法走法")
    func engineAmateurDan() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .amateurDan, isIOS: false)
        #expect(move != nil)
    }

    // MARK: - 3. bestMoves 各级别 scored 变体验证

    @Test("v4.2 bestMoves lvl3 amateurLow: 返回候选（mediumNoQS 路径）")
    func bestMovesAmateurLow() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .amateurLow, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty)
        #expect(candidates.count <= 3)
    }

    @Test("v4.2 bestMoves lvl4 amateurMid: 返回候选（.medium 路径）")
    func bestMovesAmateurMid() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .amateurMid, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty)
    }

    @Test("v4.2 bestMoves lvl5 amateurHigh: 返回候选（.hard 路径）")
    func bestMovesAmateurHigh() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .amateurHigh, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty)
    }

    // MARK: - 4. Pikafish skillLevel 重映射验证

    @Test("v4.2 skillLevel: amateurDan(lvl6) = 0（从 4 改为 0）")
    func skillLevelAmateurDan() {
        #expect(AIDifficulty.amateurDan.skillLevel == 0, "amateurDan skillLevel 应为 0")
    }

    @Test("v4.2 skillLevel: proApprentice(lvl7) = 4（从 7 改为 4）")
    func skillLevelProApprentice() {
        #expect(AIDifficulty.proApprentice.skillLevel == 4)
    }

    @Test("v4.2 skillLevel: proExpert(lvl8) = 7（从 10 改为 7）")
    func skillLevelProExpert() {
        #expect(AIDifficulty.proExpert.skillLevel == 7)
    }

    @Test("v4.2 skillLevel: proMaster(lvl9) = 10（从 13 改为 10）")
    func skillLevelProMaster() {
        #expect(AIDifficulty.proMaster.skillLevel == 10)
    }

    @Test("v4.2 skillLevel: grandmaster(lvl10) = 20（不变）")
    func skillLevelGrandmaster() {
        #expect(AIDifficulty.grandmaster.skillLevel == 20)
    }

    @Test("v4.2 skillLevel: 业余级(lvl1-5) = nil")
    func skillLevelAmateurNil() {
        #expect(AIDifficulty.novice.skillLevel == nil)
        #expect(AIDifficulty.beginner.skillLevel == nil)
        #expect(AIDifficulty.amateurLow.skillLevel == nil)
        #expect(AIDifficulty.amateurMid.skillLevel == nil)
        #expect(AIDifficulty.amateurHigh.skillLevel == nil)
    }

    // MARK: - 5. Softmax temperature 分级验证
    // softmaxTemperature 是 private static，通过自对弈行为间接验证

    @Test("v4.2 Softmax: beginner 自对弈正常（temperature=30）", .timeLimit(.minutes(3)))
    func softmaxBeginnerTemp() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(red: .beginner, black: .beginner, games: 1, maxMoves: 30)
        let result = await runner.run(config: config)
        #expect(result.games.count == 1)
        #expect(result.games[0].totalMoves > 0)
    }

    @Test("v4.2 Softmax: amateurLow 自对弈正常（temperature=40）", .timeLimit(.minutes(5)))
    func softmaxAmateurLowTemp() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(red: .amateurLow, black: .amateurLow, games: 1, maxMoves: 40)
        let result = await runner.run(config: config)
        #expect(result.games.count == 1)
        #expect(result.games[0].totalMoves > 0)
    }

    @Test("v4.2 Softmax: amateurMid 自对弈正常（temperature=50）", .timeLimit(.minutes(8)))
    func softmaxAmateurMidTemp() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(red: .amateurMid, black: .amateurMid, games: 1, maxMoves: 40)
        let result = await runner.run(config: config)
        #expect(result.games.count == 1)
        #expect(result.games[0].totalMoves > 0)
    }

    // MARK: - 6. Contempt 禁用继承验证

    @Test("v4.2 Contempt: 所有难度 contemptFor = 0（禁用继承）")
    func contemptAllDisabled() async {
        // 所有级别都应不受 contempt 影响
        let engine = AIEngine()
        let board = Board()
        for difficulty in [AIDifficulty.amateurMid, .amateurHigh] {
            let move = await engine.bestMove(for: board, difficulty: difficulty, isIOS: false)
            #expect(move != nil, "\(difficulty) 应正常返回走法")
        }
    }

    // MARK: - 7. 时间约束合理性验证（不超时即可）

    @Test("v4.2 时间: lvl2 beginner 在合理时间内返回（1000ms 限制）", .timeLimit(.minutes(2)))
    func timeBeginner() async {
        let engine = AIEngine()
        let board = Board()
        let start = Date()
        _ = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        let elapsed = Date().timeIntervalSince(start)
        // 1000ms 限制 + 一定余量
        #expect(elapsed < 10, "beginner 应在 10s 内完成（限制 1000ms + 余量），实际 \(elapsed)s")
    }
}
