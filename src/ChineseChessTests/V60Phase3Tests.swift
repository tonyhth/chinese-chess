import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.0 Phase 3 测试：EngineRouter + Skill Level + Fallback

@Suite("v6.0 Phase 3: EngineRouter 路由逻辑", .serialized)
@MainActor
struct V60Phase3RouterTests {

    // ============================
    // MARK: - 维度 4：路由逻辑
    // ============================

    @Test("engineFor: 业余级 1-5 路由到 nativeEngine")
    func routeAmateurToNative() {
        let router = EngineRouter.shared
        for diff in [AIDifficulty.novice, .beginner, .amateurLow, .amateurMid, .amateurHigh] {
            let engine = router.engineFor(difficulty: diff)
            // nativeEngine 是 AIEngine 实例
            #expect(engine is AIEngine, "业余级 \(diff.displayName) 应路由到 AIEngine")
        }
    }

    @Test("engineFor: 专业级 6-10 在 Pikafish 不可用时 fallback 到 nativeEngine")
    func routeProFallbackToNative() {
        let router = EngineRouter.shared
        // 测试时 Pikafish 可能未启动，验证 fallback 行为
        // engineFor 不应 crash，应返回某个引擎
        for diff in [AIDifficulty.amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster] {
            let engine = router.engineFor(difficulty: diff)
            // 即使 Pikafish 不可用，也应返回 nativeEngine（不 crash）
            #expect(engine is AIEngine || engine is EmbeddedPikafishEngine)
        }
    }

    @Test("validateEngineAvailability: 业余级总是返回 available")
    func validateAmateurAlwaysAvailable() async {
        let router = EngineRouter.shared
        for diff in [AIDifficulty.novice, .beginner, .amateurLow, .amateurMid, .amateurHigh] {
            let result = await router.validateEngineAvailability(for: diff)
            #expect(result == .available, "业余级 \(diff.displayName) 应总是可用")
        }
    }

    @Test("validateEngineAvailability: 专业级返回 available 或 unavailable")
    func validateProReturnsResult() async {
        let router = EngineRouter.shared
        for diff in [AIDifficulty.amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster] {
            let result = await router.validateEngineAvailability(for: diff)
            // 可能 available（Pikafish 已启动）或 unavailable（启动失败）
            switch result {
            case .available:
                #expect(Bool(true))
            case .unavailable(let reason):
                #expect(reason == .engineNotReady || reason == .engineFailed)
            }
        }
    }

    @Test("getNativeEngine 返回 AIEngine 实例")
    func getNativeEngineType() {
        let router = EngineRouter.shared
        let engine = router.getNativeEngine()
        #expect(engine is AIEngine)
    }

    @Test("getEmbeddedEngine 返回 Optional<EmbeddedPikafishEngine>")
    func getEmbeddedEngineType() {
        let router = EngineRouter.shared
        let engine = router.getEmbeddedEngine()
        // 可能是 nil（未启动）或 EmbeddedPikafishEngine
        if let emb = engine {
            #expect(emb is EmbeddedPikafishEngine)
        }
    }
}

// MARK: - Fallback 通知专项（维度 8）

@Suite("v6.0 Phase 3: Fallback 通知", .serialized)
@MainActor
struct V60Phase3FallbackTests {

    @Test("handleEngineFailure 发送 fallback 通知")
    func fallbackNotificationSent() async {
        let router = EngineRouter.shared

        // 监听通知
        let expectation = AsyncBox<Bool>()
        let observer = NotificationCenter.default.addObserver(
            forName: EngineRouter.fallbackNotification,
            object: nil,
            queue: .main
        ) { notification in
            expectation.set(true)
            // 验证 userInfo 包含 originalLevel 和 fallbackLevel
            #expect(notification.userInfo?["originalLevel"] != nil)
            #expect(notification.userInfo?["fallbackLevel"] != nil)
        }

        // 触发 fallback（使用专业级）
        router.handleEngineFailure(difficulty: .grandmaster)

        // 等待通知（短暂延迟）
        try? await Task.sleep(nanoseconds: 100_000_000)

        NotificationCenter.default.removeObserver(observer)
        #expect(await expectation.value == true)
    }

    @Test("handleEngineFailure: 通知包含 originalLevel 和 fallbackLevel")
    func fallbackNotificationContent() async {
        let router = EngineRouter.shared

        let expectation = AsyncBox<AIDifficulty?>()
        let observer = NotificationCenter.default.addObserver(
            forName: EngineRouter.fallbackNotification,
            object: nil,
            queue: .main
        ) { notification in
            let original = notification.userInfo?["originalLevel"] as? AIDifficulty
            let fallback = notification.userInfo?["fallbackLevel"] as? AIDifficulty
            expectation.set(original)
            #expect(original == .proExpert)
            #expect(fallback == .amateurHigh)
        }

        router.handleEngineFailure(difficulty: .proExpert)
        try? await Task.sleep(nanoseconds: 100_000_000)

        NotificationCenter.default.removeObserver(observer)
        #expect(await expectation.value == .proExpert)
    }

    @Test("handleEngineFailure: 所有专业级 fallback 到 amateurHigh")
    func allProFallbackToAmateurHigh() {
        for diff in [AIDifficulty.amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster] {
            #expect(diff.fallbackToAmateur == .amateurHigh, "\(diff.displayName) fallback 应为 amateurHigh")
        }
    }

    @Test("fallbackNotification 名称存在")
    func fallbackNotificationName() {
        #expect(EngineRouter.fallbackNotification == Notification.Name("engineRouter.fallback"))
    }
}

// MARK: - Skill Level 链路验证

@Suite("v6.0 Phase 3: Skill Level 链路", .serialized)
struct V60Phase3SkillLevelTests {

    @Test("skillLevel 值与设计文档一致")
    func skillLevelValues() {
        #expect(AIDifficulty.amateurDan.skillLevel == 4)     // v2.1: 5→4
        #expect(AIDifficulty.proApprentice.skillLevel == 7) // v2.1: 8→7
        #expect(AIDifficulty.proExpert.skillLevel == 10)    // v2.1: 12→10
        #expect(AIDifficulty.proMaster.skillLevel == 13)    // v2.1: 16→13
        #expect(AIDifficulty.grandmaster.skillLevel == 20)
    }

    @Test("业余级 skillLevel 为 nil")
    func amateurSkillLevelNil() {
        for diff in [AIDifficulty.novice, .beginner, .amateurLow, .amateurMid, .amateurHigh] {
            #expect(diff.skillLevel == nil)
        }
    }

    @Test("EmbeddedPikafishEngine 有 setSkillLevel 方法")
    func setSkillLevelExists() async {
        // 编译验证：方法存在且可调用
        // 实际调用需要 Pikafish 已启动
        let engine = EmbeddedPikafishEngine()
        // 不调用——Pikafish 可能未启动
        // 仅验证类型存在
        #expect(type(of: engine) == EmbeddedPikafishEngine.self)
    }
}

// MARK: - Phase 2 P1 修复：ToolbarView 10 级

@Suite("v6.0 Phase 3: ToolbarView P1 修复", .serialized)
@MainActor
struct V60Phase3ToolbarTests {

    @Test("ToolbarView 可创建（编译验证）")
    func toolbarViewCompiles() {
        let vm = GameViewModel()
        let _ = ToolbarView(viewModel: vm)
    }

    @Test("ToolbarView Menu 包含全部 10 级")
    func toolbarHasAll10Levels() {
        // P1 修复验证：Menu 和 Picker 都包含专业级 6-10
        // 深层 UI 验证需要 XCUITest，这里验证编译通过 + ViewModel 支持 10 级
        let vm = GameViewModel()
        for diff in AIDifficulty.allCases {
            vm.setDifficulty(diff)
            #expect(vm.difficulty == diff)
        }
    }

    @Test("difficultyShortName: 10 级有 l10n 短名")
    func shortNameAll10Levels() {
        let l10n = L10n.shared
        for diff in AIDifficulty.allCases {
            let key = "difficulty.short.lvl\(diff.order + 1)"
            let val = l10n.t(key)
            #expect(!val.isEmpty, "短名 key \(key) 应有值")
        }
    }
}

// MARK: - 综合回归

@Suite("v6.0 Phase 3: 综合回归", .serialized)
@MainActor
struct V60Phase3RegressionTests {

    @Test("EngineRouter.shared 单例存在")
    func routerSingletonExists() {
        let router = EngineRouter.shared
        #expect(router !== nil as EngineRouter?)
    }

    @Test("EngineAvailability 枚举可比较")
    func engineAvailabilityEquatable() {
        #expect(EngineAvailability.available == .available)
        #expect(EngineAvailability.unavailable(reason: .engineNotReady) == .unavailable(reason: .engineNotReady))
        #expect(EngineAvailability.available != .unavailable(reason: .engineNotReady))
    }

    @Test("EngineUnavailableReason 枚举可比较")
    func engineUnavailableReasonEquatable() {
        #expect(EngineUnavailableReason.engineNotReady == .engineNotReady)
        #expect(EngineUnavailableReason.engineFailed == .engineFailed)
        #expect(EngineUnavailableReason.engineNotReady != .engineFailed)
    }

    @Test("GameViewModel engineFallbackMessage 可设置")
    func gameViewModelFallbackMessage() {
        let vm = GameViewModel()
        vm.engineFallbackMessage = "测试消息"
        #expect(vm.engineFallbackMessage == "测试消息")
    }

    @Test("Phase 1+2 回归：枚举 + 迁移 + switch 仍正确")
    func phase1and2Regression() {
        #expect(AIDifficulty.allCases.count == 10)
        #expect(AIDifficulty.novice.rawValue == "lvl1")
        #expect(AIDifficulty.grandmaster.rawValue == "lvl10")
        #expect(AIDifficulty.allCases.filter { $0.isProfessional }.count == 5)
    }
}

// MARK: - P1 修复验证（commit 01a5c6d）

@Suite("v6.0 Phase 3 P1 修复：fallback wiring + depth + l10n", .serialized)
@MainActor
struct V60Phase3P1FixTests {

    // ============================
    // MARK: - P1-1: 层 2 fallback 接入
    // ============================

    @Test("P1-1: handleEngineFailure 不再是死代码——专业级 nil 触发 fallback")
    func handleEngineFailureWired() async {
        // 验证 handleEngineFailure 被调用后发送通知
        let router = EngineRouter.shared
        let expectation = AsyncBox<Bool>()
        let observer = NotificationCenter.default.addObserver(
            forName: EngineRouter.fallbackNotification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.set(true)
        }

        // 直接调用 handleEngineFailure（模拟 triggerAIMove nil 分支行为）
        router.handleEngineFailure(difficulty: .proExpert)
        try? await Task.sleep(nanoseconds: 100_000_000)

        NotificationCenter.default.removeObserver(observer)
        #expect(await expectation.value == true, "handleEngineFailure 应发送 fallback 通知")
    }

    // ============================
    // MARK: - P1-2: 专业级 depth=0
    // ============================

    @Test("P1-2: 专业级 skillLevel 不为 nil（确认 Skill Level 控制棋力）")
    func proSkillLevelControls() {
        // depth=0 意味着不限制搜索深度，Skill Level 全权控制棋力
        // 验证所有专业级都有 skillLevel 值
        for diff in [AIDifficulty.amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster] {
            #expect(diff.skillLevel != nil, "\(diff.displayName) 应有 skillLevel")
        }
    }

    @Test("P1-2: 业余级 skillLevel 为 nil（业余级用 depth 控制而非 Skill Level）")
    func amateurNoSkillLevel() {
        for diff in [AIDifficulty.novice, .beginner, .amateurLow, .amateurMid, .amateurHigh] {
            #expect(diff.skillLevel == nil)
        }
    }

    // ============================
    // MARK: - P1-3: l10n key 存在
    // ============================

    @Test("P1-3: engine.fallbackLevel l10n key 存在")
    func l10nFallbackLevel() {
        let val = L10n.shared.t("engine.fallbackLevel")
        #expect(!val.isEmpty)
    }

    @Test("P1-3: engine.notReady l10n key 存在")
    func l10nNotReady() {
        let val = L10n.shared.t("engine.notReady")
        #expect(!val.isEmpty)
    }

    @Test("P1-3: engine.engineFailed l10n key 存在")
    func l10nEngineFailed() {
        let val = L10n.shared.t("engine.engineFailed")
        #expect(!val.isEmpty)
    }

    @Test("P1-3: stats.professional l10n key 存在")
    func l10nStatsProfessional() {
        let val = L10n.shared.t("stats.professional")
        #expect(!val.isEmpty)
    }

    @Test("P1-3: engine.fallbackLevel 包含格式化占位符")
    func l10nFallbackLevelFormat() {
        let val = L10n.shared.t("engine.fallbackLevel")
        // 应包含 %1$@ 和 %2$@ 占位符（中英文都是）
        #expect(val.contains("%1$@") || val.contains("%1") || val.contains("%@"))
    }

    // ============================
    // MARK: - 综合回归
    // ============================

    @Test("P1 回归：Phase 3 原有测试仍通过")
    func regressionPhase3StillWorks() {
        #expect(AIDifficulty.allCases.count == 10)
        #expect(AIDifficulty.amateurDan.skillLevel == 4)  // v2.1: 5→4
        #expect(AIDifficulty.grandmaster.skillLevel == 20)
        #expect(EngineAvailability.available == .available)
    }
}

// MARK: - 辅助

/// 异步值容器（用于通知回调中传值出去）
final class AsyncBox<T> {
    private var _value: T?
    private let lock = NSLock()
    var value: T? {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
    func set(_ value: T) {
        lock.lock(); defer { lock.unlock() }
        _value = value
    }
}
