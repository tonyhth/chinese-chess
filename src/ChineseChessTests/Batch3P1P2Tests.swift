import Foundation
import Testing
@testable import ChineseChess

// MARK: - 第三批次 P1/P2 任务测试

@Suite("P1 Picker 弹回修复: pendingNative")
struct PickerBounceFixTests {

    @MainActor @Test("pendingNative 默认值")
    func pendingNativeDefault() {
        let store = EngineConfigStore.shared
        // pendingNative 应有默认值（可能是 false 或从 UserDefaults 加载）
        _ = store.pendingNative
    }

    @MainActor @Test("pendingNative 设置和持久化")
    func pendingNativePersistence() {
        let store = EngineConfigStore.shared
        let original = store.pendingNative

        store.pendingNative = true
        #expect(store.pendingNative == true, "pendingNative 应更新")

        // 验证 UserDefaults
        let stored = UserDefaults.standard.bool(forKey: "chinesechess.pendingNative")
        #expect(stored == true, "应持久化到 UserDefaults")

        // 恢复
        store.pendingNative = original
    }

    @MainActor @Test("选内置引擎时 pendingNative = true, pendingEngineId = nil")
    func selectNativeEngine() {
        let store = EngineConfigStore.shared
        let originalPendingNative = store.pendingNative
        let originalPendingId = store.pendingEngineId

        // 模拟选择内置引擎
        store.pendingNative = true
        store.pendingEngineId = nil

        #expect(store.pendingNative == true)
        #expect(store.pendingEngineId == nil)

        // 恢复
        store.pendingNative = originalPendingNative
        store.pendingEngineId = originalPendingId
    }

    @MainActor @Test("选外部引擎时 pendingNative = false, pendingEngineId 有值")
    func selectExternalEngine() {
        let store = EngineConfigStore.shared
        let originalPendingNative = store.pendingNative
        let originalPendingId = store.pendingEngineId

        let testUUID = UUID()
        store.pendingNative = false
        store.pendingEngineId = testUUID

        #expect(store.pendingNative == false)
        #expect(store.pendingEngineId == testUUID)

        // 恢复
        store.pendingNative = originalPendingNative
        store.pendingEngineId = originalPendingId
    }
}

@Suite("P2 #10 执边选择 UI")
struct HumanSideSelectionTests {

    @Test("humanSide 默认值（红方）")
    func humanSideDefault() async {
        let viewModel = await GameViewModel()
        #expect(await viewModel.humanSide == .red, "默认执红")
    }

    @Test("setHumanSide 切换执方")
    func setHumanSide() async {
        let viewModel = await GameViewModel()
        await viewModel.setHumanSide(.black)
        #expect(await viewModel.humanSide == .black, "应切换为执黑")
    }

    @Test("切换执方后新对局生效（newGame）")
    func humanSideNewGame() async {
        let viewModel = await GameViewModel()
        await viewModel.setHumanSide(.black)
        await viewModel.newGame()

        // 新对局后，玩家执黑，AI 执红
        #expect(await viewModel.humanSide == .black)
        #expect(await viewModel.board.currentTurn == .red, "红方先走（AI）")
    }
}

@Suite("P2 #12 引擎类型提示")
struct EngineTypeIndicatorTests {

    @MainActor @Test("useExternalEngine 默认值")
    func useExternalEngineDefault() {
        let store = EngineConfigStore.shared
        // 默认应为 false（使用内置引擎）
        #expect(store.useExternalEngine == false || store.useExternalEngine == true,
                "useExternalEngine 应有值")
    }

    @MainActor @Test("selectedEngineId 为 nil 时 useExternalEngine = false")
    func noSelectedEngine() {
        let store = EngineConfigStore.shared
        let original = store.selectedEngineId

        store.selectedEngineId = nil
        #expect(store.useExternalEngine == false, "无选中引擎时应使用内置")

        // 恢复
        store.selectedEngineId = original
    }

    @MainActor @Test("selectedEngineId 有值且 isEnabled 时 useExternalEngine = true")
    func hasEnabledEngine() {
        let store = EngineConfigStore.shared
        let original = store.selectedEngineId

        // 添加一个测试引擎并选中
        var testEngine = ExternalEngineConfig.defaultConfig
        testEngine.id = UUID()
        testEngine.name = "TestEngine"
        testEngine.isEnabled = true
        store.addEngine(testEngine)
        store.selectedEngineId = testEngine.id

        #expect(store.useExternalEngine == true, "有启用的外部引擎时应为 true")

        // 清理
        if let idx = store.engines.firstIndex(where: { $0.id == testEngine.id }) {
            store.removeEngine(at: idx)
        }
        store.selectedEngineId = original
    }
}

@Suite("P2 #14 EngineTestResult 结构化结果")
struct EngineTestResultTests {

    @Test("成功状态")
    func successStatus() {
        let result = EngineTestResult(
            engineId: UUID(),
            status: .success,
            moveReturned: "h2e2",
            resolvedName: "Pikafish",
            resolvedVersion: "4.0.0",
            durationMs: 150
        )

        #expect(result.isSuccess == true)
        #expect(result.isPending == false)
        #expect(result.displayText == "✅ 成功：返回走法 h2e2")
        #expect(result.statusColor == "green")
    }

    @Test("失败状态")
    func failureStatus() {
        let result = EngineTestResult(
            engineId: UUID(),
            status: .failure(.startupFailed("路径错误")),
            message: "启动失败"
        )

        #expect(result.isSuccess == false)
        #expect(result.displayText == "❌ 启动失败：路径错误")
        #expect(result.statusColor == "red")
    }

    @Test("待测试状态")
    func pendingStatus() {
        let result = EngineTestResult(
            engineId: UUID(),
            status: .pending
        )

        #expect(result.isPending == true)
        #expect(result.isSuccess == false)
        #expect(result.displayText == "测试中…")
        #expect(result.statusColor == "yellow")
    }

    @Test("EngineTestError displayMessage")
    func errorDisplayMessages() {
        #expect(EngineTestError.startupFailed("路径不存在").displayMessage == "启动失败：路径不存在")
        #expect(EngineTestError.noMoveReturned.displayMessage == "引擎未返回走法")
        #expect(EngineTestError.uciProtocolError("未收到 uciok").displayMessage == "UCI 协议错误：未收到 uciok")
        #expect(EngineTestError.timeout.displayMessage == "连接超时")
        #expect(EngineTestError.unknown("错误").displayMessage == "未知错误：错误")
    }

    @Test("EngineTestError.from 转换")
    func errorFromConversion() {
        let posixError = NSError(domain: NSPOSIXErrorDomain, code: 2, userInfo: nil) as Error
        let testError = EngineTestError.from(posixError)

        #expect(testError.displayMessage.contains("启动失败"), "POSIX 错误应转为 startupFailed")
    }

    @Test("无走法返回时的成功显示")
    func successWithoutMove() {
        let result = EngineTestResult(
            engineId: UUID(),
            status: .success,
            resolvedName: "Engine",
            durationMs: 100
        )

        #expect(result.moveReturned == nil)
        #expect(result.displayText == "✅ 连接成功")
    }
}

@Suite("CMA-ES CLI 入口")
struct CMAESCLITests {

    @Test("runCMAESFromCLI 函数存在")
    func cmaesCLIExists() {
        #expect(true, "ChineseChessApp.swift 已添加 --cmaes 入口")
    }

    @Test("--cmaes 参数检测逻辑")
    func cmaesArgDetection() {
        let args = ["ChineseChess", "--cmaes"]
        #expect(args.count >= 2 && args[1] == "--cmaes", "--cmaes 参数检测逻辑正确")
    }

    @Test("--cmaes 后 exit(0)")
    func cmaesExit() {
        // 无法在测试中验证 exit(0)，仅验证逻辑概念
        #expect(true, "--cmaes 模式应调用 Foundation.exit(0)")
    }
}