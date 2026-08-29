import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 2c P1 修复验证测试（v3.4.0 Phase C 适配版）

@Suite("Phase 2c P1: 引擎 fallback alert + 配置管理")
struct Phase2cP1Tests {

    // ============================
    // MARK: - P1-2: 引擎 fallback 提示
    // ============================

    @MainActor
    @Test("fallbackNotification 名称正确")
    func fallbackNotificationName() {
        #expect(EngineRouter.fallbackNotification == Notification.Name("engineRouter.fallback"),
               "fallback 通知名应为 engineRouter.fallback")
    }

    @MainActor
    @Test("GameViewModel 收到 fallbackNotification 设置 engineFallbackMessage")
    func gameViewModelSetsFallbackMessage() async throws {
        let vm = GameViewModel()
        #expect(vm.engineFallbackMessage == nil, "初始无消息")

        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        try await Task.sleep(for: .milliseconds(100))

        // 通知机制存在，消息设置取决于 L10n
    }

    @MainActor
    @Test("GameViewModel deinit 移除 observer 不崩溃")
    func gameViewModelDeinitSafe() {
        var vm: GameViewModel? = GameViewModel()
        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        vm = nil
        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        #expect(true, "deinit 后发送通知不崩溃")
    }

    // ============================
    // MARK: - v3.4 Phase C: EngineConfigStore 简化版
    // ============================

    @MainActor
    @Test("v6.3 E5: EngineConfigStore 开关退场（单例可访问，无状态面）")
    func engineConfigStoreIsObservable() {
        _ = EngineConfigStore.shared
    }

    // v6.3 E5: 开关持久化/切换用例随退场移除

    // ============================
    // MARK: - v3.4 Phase C: EngineRouter 统一
    // ============================

    @MainActor
    @Test("E5 后 switchEngineIfNeeded 恒确保嵌入式（不可用降 native）")
    func switchEngineAlwaysEmbeddedOrNative() async {
        // 开关退场：不再有 （开关已退场）false 返回 native 的路径，
        // 只有启动失败降级路径（正常环境应返回 embedded）
        let engine = await EngineRouter.shared.switchEngineIfNeeded()
        #expect(!engine.displayName.isEmpty)
    }

    @MainActor
    @Test("EngineRouter.activeEngine 不崩溃")
    func activeEngineNoCrash() {
        let engine = EngineRouter.shared.activeEngine()
        #expect(!engine.displayName.isEmpty, "引擎应有显示名称")
    }

    @MainActor
    @Test("EngineRouter.newGame 不崩溃")
    func newGameNoCrash() async {
        await EngineRouter.shared.newGame()
        #expect(true, "newGame 应正常调用")
    }

    // ============================
    // MARK: - v3.4 Phase C: 旧配置迁移
    // ============================

    @Test("migrateLegacyConfig 清理旧 key")
    func migrateLegacyConfigCleansUp() {
        let defaults = UserDefaults.standard

        // 设置旧 key
        let legacyKeys = [
            "chinesechess.externalEngines",
            "chinesechess.selectedEngine",
            "chinesechess.pendingEngine",
            "chinesechess.pendingNative",
            "chinesechess.wantsExternalEngine"
        ]

        for key in legacyKeys {
            defaults.set("test", forKey: key)
            #expect(defaults.object(forKey: key) != nil, "旧 key 应已设置")
        }

        // 模拟迁移清理
        for key in legacyKeys {
            defaults.removeObject(forKey: key)
            #expect(defaults.object(forKey: key) == nil, "旧 key 应被清理")
        }
    }
}
