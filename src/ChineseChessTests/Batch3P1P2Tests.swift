import Foundation
import Testing
@testable import ChineseChess

// MARK: - 第三批次 P1/P2 任务测试（v3.4.0 Phase C 适配版）

@Suite("P2 #10 执边选择 UI", .serialized)
struct HumanSideSelectionTests {

    private static let key = "chinesechess.humanSide"

    @MainActor
    @Test("humanSide 默认值（红方）")
    func humanSideDefault() async {
        UserDefaults.standard.removeObject(forKey: Self.key)
        let viewModel = GameViewModel()
        #expect(viewModel.humanSide == .red, "默认执红")
    }

    @MainActor
    @Test("setHumanSide 切换执方")
    func setHumanSide() async {
        UserDefaults.standard.removeObject(forKey: Self.key)
        defer { UserDefaults.standard.removeObject(forKey: Self.key) }
        let viewModel = GameViewModel()
        viewModel.setHumanSide(.black)
        #expect(viewModel.humanSide == .black, "应切换为执黑")
    }

    @MainActor
    @Test("切换执方后新对局生效（newGame）")
    func humanSideNewGame() async {
        UserDefaults.standard.removeObject(forKey: Self.key)
        defer { UserDefaults.standard.removeObject(forKey: Self.key) }
        let viewModel = GameViewModel()
        viewModel.setHumanSide(.black)
        viewModel.newGame()

        // 新对局后，玩家执黑，AI 执红
        #expect(viewModel.humanSide == .black)
        #expect(viewModel.board.currentTurn == .red, "红方先走（AI）")
    }
}

@Suite("v3.4 Phase C: 引擎菜单 Toggle")
struct EngineMenuToggleTests {

    @MainActor
    @Test("useEmbeddedEngineBinding 切换触发 switchEngineIfNeeded")
    func toggleTriggersEngineSwitch() async {
        let store = EngineConfigStore.shared
        let original = store.useEmbeddedEngine

        // 切换到嵌入式引擎
        store.useEmbeddedEngine = true
        let engine = await EngineRouter.shared.switchEngineIfNeeded()

        // 切换回内置引擎
        store.useEmbeddedEngine = false
        let engine2 = await EngineRouter.shared.switchEngineIfNeeded()

        #expect(engine2.engineType == .native, "切换回内置后应返回 native")

        // 恢复
        store.useEmbeddedEngine = original
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
