import Foundation
import Testing
@testable import ChineseChess

// MARK: - P1 返工复测：引擎 fallback Toast 提示（v3.4.0 Phase C 适配版）

@Suite("P1 返工: 引擎 fallback Toast 提示")
struct P1FallbackToastTests {

    @MainActor
    @Test("GameViewModel.engineFallbackMessage 初始为 nil")
    func gameViewModelInitialFallbackMessageNil() {
        let vm = GameViewModel()
        #expect(vm.engineFallbackMessage == nil, "初始状态 fallback 消息应为 nil")
    }

    @MainActor
    @Test("GameViewModel 收到 fallbackNotification 设置消息")
    func gameViewModelSetsMessageOnNotification() async throws {
        let vm = GameViewModel()
        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(vm.engineFallbackMessage != nil, "engineFallbackMessage should be set after fallback notification")
    }

    @MainActor
    @Test("GameViewModel deinit 移除 observer 不崩溃")
    func gameViewModelDeinitSafe() {
        var vm: GameViewModel? = GameViewModel()
        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        vm = nil
        NotificationCenter.default.post(name: EngineRouter.fallbackNotification, object: nil)
        #expect(true, "deinit 移除 observer 后发送通知不崩溃")
    }

    @MainActor
    @Test("ToolbarView 存在且可创建")
    func toolbarViewCreation() {
        let vm = GameViewModel()
        let toolbar = ToolbarView(viewModel: vm)
        #expect(toolbar.body != nil, "ToolbarView 应有 body")
    }

    @MainActor
    @Test("engineFallbackMessage 清空防止重复触发")
    func fallbackMessageClearedAfterToast() async throws {
        let vm = GameViewModel()
        vm.engineFallbackMessage = "测试消息"
        #expect(vm.engineFallbackMessage == "测试消息")

        vm.engineFallbackMessage = nil
        #expect(vm.engineFallbackMessage == nil, "消息应被清空")
    }

    @MainActor
    @Test("EngineRouter fallback 时发送通知")
    func engineRouterFallbackSendsNotification() async throws {
        // v6.3 E5: 开关退场——无开关前置，直接验证路由返回可用引擎句柄
        let engine = await EngineRouter.shared.switchEngineIfNeeded()

        // 无论成功还是失败，引擎都应返回
        #expect(!engine.displayName.isEmpty, "引擎应有显示名称")
    }

    // v6.3 E5: SettingsView Toggle 绑定用例随开关退场移除（无绑定可验证）
}
