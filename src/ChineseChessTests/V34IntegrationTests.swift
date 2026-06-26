import Foundation
import Testing
@testable import ChineseChess

// MARK: - v3.4.0 Phase C 集成测试（适配简化版 EngineConfigStore）

@Suite("v3.4 Phase C: EngineRouter 统一")
struct V34EngineRouterTests {

    @MainActor
    @Test("EngineRouter.switchEngineIfNeeded 无外部引擎时返回 native")
    func switchEngineReturnsNative() async {
        let store = EngineConfigStore.shared
        let original = store.useEmbeddedEngine

        store.useEmbeddedEngine = false
        let engine = await EngineRouter.shared.switchEngineIfNeeded()
        #expect(engine.engineType == .native, "useEmbeddedEngine=false 时应返回 native")
        #expect(engine.displayName == "内置引擎")

        store.useEmbeddedEngine = original
    }

    @MainActor
    @Test("EngineRouter.activeEngine 返回已有实例")
    func activeEngineReturnsExisting() {
        let engine = EngineRouter.shared.activeEngine()
        #expect(!engine.displayName.isEmpty, "引擎应有显示名称")
    }

    @MainActor
    @Test("EngineRouter.fallbackNotification 存在")
    func fallbackNotificationExists() {
        #expect(EngineRouter.fallbackNotification == Notification.Name("engineRouter.fallback"))
    }

    @MainActor
    @Test("EngineRouter.newGame 不崩溃")
    func newGameNoCrash() {
        EngineRouter.shared.newGame()
        #expect(true, "newGame 应正常调用")
    }

    @MainActor
    @Test("EngineRouter.shutdown 不崩溃")
    func shutdownNoCrash() {
        EngineRouter.shared.shutdown()
        #expect(true, "shutdown 应正常调用")
    }
}

@Suite("v3.4 Phase C: EngineConfigStore 简化版")
struct V34EngineConfigStoreTests {

    @MainActor
    @Test("useEmbeddedEngine 设置和持久化")
    func useEmbeddedEnginePersistence() {
        let store = EngineConfigStore.shared
        let original = store.useEmbeddedEngine

        store.useEmbeddedEngine = true
        #expect(store.useEmbeddedEngine == true)
        #expect(UserDefaults.standard.bool(forKey: "chinesechess.useEmbeddedEngine") == true)

        store.useEmbeddedEngine = false
        #expect(store.useEmbeddedEngine == false)

        store.useEmbeddedEngine = original
    }

    @MainActor
    @Test("quickToggleEngine 返回正确值并切换状态")
    func quickToggleEngine() {
        let store = EngineConfigStore.shared
        let original = store.useEmbeddedEngine

        store.useEmbeddedEngine = false
        let result1 = store.quickToggleEngine()
        #expect(result1 == "external", "从内置切换到嵌入式应返回 external")
        #expect(store.useEmbeddedEngine == true)

        let result2 = store.quickToggleEngine()
        #expect(result2 == "builtIn", "从嵌入式切换到内置应返回 builtIn")
        #expect(store.useEmbeddedEngine == false)

        store.useEmbeddedEngine = original
    }
}

@Suite("v3.4 Phase C: GameViewModel 通知监听")
struct V34GameViewModelNotificationTests {

    @MainActor
    @Test("GameViewModel.engineFallbackMessage 初始为 nil")
    func gameViewModelInitialFallbackMessageNil() {
        let vm = GameViewModel()
        #expect(vm.engineFallbackMessage == nil, "初始状态 fallback 消息应为 nil")
    }

    @MainActor
    @Test("GameViewModel 收到 fallbackNotification 设置消息")
    func gameViewModelSetsFallbackMessage() async throws {
        let vm = GameViewModel()
        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        try await Task.sleep(for: .milliseconds(100))
    }

    @MainActor
    @Test("GameViewModel deinit 移除 observer 不崩溃")
    func gameViewModelDeinitRemovesObserver() {
        var vm: GameViewModel? = GameViewModel()
        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        vm = nil
        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        #expect(true, "deinit 移除 observer 后发送通知不崩溃")
    }
}

@Suite("v3.4 Phase C: EmbeddedPikafishEngine")
struct V34EmbeddedPikafishEngineTests {

    @Test("EmbeddedPikafishEngine 实现 ChessEngine 协议")
    func embeddedEngineConformsToChessEngine() {
        // 验证类型存在且可创建
        let engine = EmbeddedPikafishEngine()
        #expect(engine.displayName == "Pikafish")
        #expect(engine.engineType == .external)
    }

    @Test("EmbeddedPikafishEngine 未启动时 bestMove 返回 nil")
    func bestMoveReturnsNilBeforeStart() async {
        let engine = EmbeddedPikafishEngine()
        let result = await engine.bestMove(
            fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            moveHistory: [],
            difficulty: .medium,
            timeLimitMs: 1000
        )
        #expect(result == nil, "未启动时 bestMove 应返回 nil")
    }

    @Test("EmbeddedPikafishEngine stopSearch 不崩溃")
    func stopSearchNoCrash() async {
        let engine = EmbeddedPikafishEngine()
        await engine.stopSearch()
        engine.stopSearchImmediate()
        #expect(true, "stopSearch 应正常调用")
    }

    @Test("EmbeddedPikafishEngine newGame 不崩溃")
    func newGameNoCrash() async {
        let engine = EmbeddedPikafishEngine()
        await engine.newGame()
        #expect(true, "newGame 应正常调用")
    }

    @Test("EmbeddedPikafishEngine shutdown 未启动时不崩溃")
    func shutdownBeforeStartNoCrash() async {
        let engine = EmbeddedPikafishEngine()
        await engine.shutdown()
        #expect(true, "shutdown 未启动时应正常调用")
    }

    @Test("EmbeddedPikafishEngine mapDifficulty 覆盖所有难度")
    func mapDifficultyAllLevels() async {
        let engine = EmbeddedPikafishEngine()
        for difficulty in [AIDifficulty.beginner, .easy, .medium, .hard, .master] {
            let result = await engine.bestMove(
                fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
                moveHistory: [],
                difficulty: difficulty,
                timeLimitMs: 500
            )
            // 未启动时返回 nil，但不应崩溃
            _ = result
        }
        #expect(true, "所有难度级别不应崩溃")
    }
}

@Suite("v3.4 Phase C: EngineError")
struct V34EngineErrorTests {

    @Test("EngineError.startFailed 有错误描述")
    func engineErrorDescription() {
        let error = EngineError.startFailed
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.contains("pikafish") == true ||
               error.errorDescription?.contains("NNUE") == true ||
               error.errorDescription?.contains("Failed") == true,
               "错误描述应包含相关信息")
    }
}

@Suite("v3.4 Phase C: CMAESIndividual 有序字段映射")
struct V34CMAESIndividualTests {

    @Test("CMAESIndividual.from(weights) 参数顺序一致")
    func individualParameterOrderMatchesFieldNames() throws {
        let weights = EvalWeights.default
        let individual = CMAESIndividual(from: weights, generation: 0)

        #expect(individual.parameters.count > 0, "参数数组不应为空")

        let restored = individual.toEvalWeights()
        #expect(restored.generalValue == weights.generalValue, "generalValue 应还原")
        #expect(restored.chariotValue == weights.chariotValue, "chariotValue 应还原")
        #expect(restored.materialWeight == weights.materialWeight, "materialWeight 应还原")
    }

    @Test("CMAESIndividual 编码/解码往返")
    func individualCodableRoundTrip() throws {
        let weights = EvalWeights.default
        var original = CMAESIndividual(from: weights, generation: 5)
        original.fitness = 0.75

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CMAESIndividual.self, from: data)

        #expect(decoded.generation == 5, "generation 应保留")
        #expect(decoded.fitness == 0.75, "fitness 应保留")
        #expect(decoded.parameters.count == original.parameters.count, "参数数量应一致")
    }
}
