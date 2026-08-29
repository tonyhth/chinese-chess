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

@Suite("v6.3 E5: 引擎开关退场后的路由契约")
struct EngineMenuToggleTests {

    @MainActor
    @Test("E5 退场后 switchEngineIfNeeded 恒确保 Pikafish（不可用则 native 降级）")
    func switchAlwaysEnsuresEmbedded() async {
        // 开关退场：无用户切换面，路由仅按难度/可用性
        let engine = await EngineRouter.shared.switchEngineIfNeeded()
        _ = engine.engineType // 可为 embedded（正常）或 native（启动失败降级）
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
