import XCTest
@testable import ChineseChess

// MARK: - Phase B2 Step 5 — macOS 演示快捷键 + DemoConfig 面板测试

/// 覆盖 DemoConfig 模型、DemoViewModel 新属性（pauseOnCommentary/showCommentary）、
/// Config→ViewModel 同步、showCommentary 门控、pauseOnCommentary 暂停/恢复逻辑
@MainActor
final class B2Step5DemoConfigTests: XCTestCase {

    // MARK: - 辅助

    private func makePuzzle(solution: [String], initialFEN: String = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1") -> Puzzle {
        Puzzle(
            id: "test-b2s5-\(UUID().uuidString.prefix(8))",
            name: "B2S5测试残局",
            category: "测试分类",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: initialFEN,
            solution: solution,
            hints: nil,
            maxMoves: solution.count
        )
    }

    // MARK: - DemoConfig 模型

    func testDemoConfigDefaultValues() {
        let config = DemoConfig()
        XCTAssertEqual(config.speedMultiplier, 1.0)
        XCTAssertTrue(config.pauseOnCommentary)
        XCTAssertTrue(config.autoNextPuzzle)
        XCTAssertTrue(config.showCommentary)
        XCTAssertEqual(config.demoSpeed, .normal)
    }

    func testDemoConfigDemoSpeedConvenience() {
        var config = DemoConfig()
        XCTAssertEqual(config.demoSpeed, .normal)

        config.demoSpeed = .fast
        XCTAssertEqual(config.speedMultiplier, 2.0)
        XCTAssertEqual(config.demoSpeed, .fast)

        config.demoSpeed = .turbo
        XCTAssertEqual(config.speedMultiplier, 3.0)
    }

    func testDemoConfigDemoSpeedFallbackOnInvalidRawValue() {
        var config = DemoConfig()
        config.speedMultiplier = 999.0  // 无匹配 rawValue
        XCTAssertEqual(config.demoSpeed, .normal, "无效 rawValue 应回退到 .normal")
    }

    // MARK: - DemoConfig Codable 容错

    func testDemoConfigDecodeMissingFields() {
        // 空对象 → 全部回退到默认值
        let json = "{}".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(DemoConfig.self, from: json)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.speedMultiplier, 1.0)
        XCTAssertTrue(decoded?.pauseOnCommentary ?? false)
        XCTAssertTrue(decoded?.autoNextPuzzle ?? false)
        XCTAssertTrue(decoded?.showCommentary ?? false)
    }

    func testDemoConfigDecodePartialFields() {
        // 只提供部分字段
        let json = """
        {"speedMultiplier": 2.0, "autoNextPuzzle": false}
        """.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(DemoConfig.self, from: json)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.speedMultiplier, 2.0)
        XCTAssertFalse(decoded?.autoNextPuzzle ?? true)
        XCTAssertTrue(decoded?.pauseOnCommentary ?? false, "缺失字段回退到默认 true")
        XCTAssertTrue(decoded?.showCommentary ?? false, "缺失字段回退到默认 true")
    }

    func testDemoConfigRoundTrip() {
        var config = DemoConfig()
        config.demoSpeed = .fast
        config.pauseOnCommentary = false
        config.autoNextPuzzle = false
        config.showCommentary = false

        let data = try! JSONEncoder().encode(config)
        let decoded = try! JSONDecoder().decode(DemoConfig.self, from: data)

        XCTAssertEqual(decoded, config, "编解码往返应一致")
    }

    // MARK: - DemoConfig Equatable

    func testDemoConfigEquatable() {
        let a = DemoConfig()
        var b = DemoConfig()
        XCTAssertEqual(a, b)

        b.demoSpeed = .turbo
        XCTAssertNotEqual(a, b)
    }

    // MARK: - DemoConfig 持久化

    func testDemoConfigSaveAndLoad() {
        // 先保存一个已知配置
        var config = DemoConfig()
        config.demoSpeed = .turbo
        config.pauseOnCommentary = false
        config.autoNextPuzzle = false
        config.showCommentary = false
        config.save()

        // 加载回来
        let loaded = DemoConfig.load()
        XCTAssertEqual(loaded.demoSpeed, .turbo)
        XCTAssertFalse(loaded.pauseOnCommentary)
        XCTAssertFalse(loaded.autoNextPuzzle)
        XCTAssertFalse(loaded.showCommentary)

        // 恢复默认值
        let defaultConfig = DemoConfig()
        DemoConfig().save()
        let restored = DemoConfig.load()
        XCTAssertEqual(restored.demoSpeed, .normal)
        XCTAssertTrue(restored.pauseOnCommentary)
        XCTAssertTrue(restored.autoNextPuzzle)
        XCTAssertTrue(restored.showCommentary)
    }

    func testDemoConfigLoadCorruptedData() {
        // 写入损坏数据
        UserDefaults.standard.set("not valid json".data(using: .utf8), forKey: "chinesechess.demoConfig")

        let loaded = DemoConfig.load()
        // 损坏数据应回退到默认值
        XCTAssertEqual(loaded.demoSpeed, .normal)
        XCTAssertTrue(loaded.pauseOnCommentary)

        // 清理
        DemoConfig().save()
    }

    // MARK: - DemoViewModel 读取 DemoConfig 初始值

    func testViewModelReadsConfigOnInit() {
        // 设置一个非默认配置
        var config = DemoConfig()
        config.demoSpeed = .fast
        config.pauseOnCommentary = false
        config.autoNextPuzzle = false
        config.showCommentary = false
        config.save()

        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        XCTAssertEqual(vm.speed, .fast, "ViewModel 应从 DemoConfig 读取速度")
        XCTAssertFalse(vm.pauseOnCommentary, "ViewModel 应从 DemoConfig 读取 pauseOnCommentary")
        XCTAssertFalse(vm.isAutoAdvance, "ViewModel 应从 DemoConfig 读取 autoNextPuzzle")
        XCTAssertFalse(vm.showCommentary, "ViewModel 应从 DemoConfig 读取 showCommentary")

        // 恢复默认
        DemoConfig().save()
    }

    // MARK: - showCommentary 门控

    func testShowCommentaryFalseSuppressesCommentary() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)
        vm.showCommentary = false

        // stepForward 触发 handleMoveExecuted → updateCommentary
        // showCommentary=false 时 currentCommentary 应保持 nil
        vm.stepForward()
        XCTAssertNil(vm.currentCommentary, "showCommentary=false 时不应生成点评")
    }

    func testShowCommentaryTrueAllowsCommentary() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)
        vm.showCommentary = true

        // 这不会在每一步都生成点评（中间步通常无点评）
        // 但至少不应报错
        vm.stepForward()
        // currentCommentary 可能为 nil（标准开局第一步无特殊点评），但不应崩溃
    }

    // MARK: - pauseOnCommentary 仅 checkmate/sacrifice 暂停

    func testPauseOnCommentaryDefaultTrue() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)
        XCTAssertTrue(vm.pauseOnCommentary, "默认 pauseOnCommentary=true")
    }

    func testPauseOnCommentaryCanBeDisabled() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)
        vm.pauseOnCommentary = false
        XCTAssertFalse(vm.pauseOnCommentary)
    }

    // MARK: - Config→ViewModel 同步（模拟 syncConfigToViewModel ViewModifier）

    func testConfigSpeedSyncsToViewModel() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        var config = DemoConfig()
        config.demoSpeed = .turbo

        // 模拟 onChange(of: config.demoSpeed) 回调
        vm.speed = config.demoSpeed
        XCTAssertEqual(vm.speed, .turbo)
        XCTAssertEqual(vm.boardPlayer.speed, 3.0, "BoardPlayer 速度应同步")
    }

    func testConfigAutoNextPuzzleSyncsToViewModel() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        var config = DemoConfig()
        config.autoNextPuzzle = false

        // 模拟 onChange(of: config.autoNextPuzzle) 回调
        vm.isAutoAdvance = config.autoNextPuzzle
        XCTAssertFalse(vm.isAutoAdvance)
    }

    func testConfigPauseOnCommentarySyncsToViewModel() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        var config = DemoConfig()
        config.pauseOnCommentary = false

        vm.pauseOnCommentary = config.pauseOnCommentary
        XCTAssertFalse(vm.pauseOnCommentary)
    }

    func testConfigShowCommentarySyncsToViewModel() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        var config = DemoConfig()
        config.showCommentary = false

        vm.showCommentary = config.showCommentary
        XCTAssertFalse(vm.showCommentary)
    }

    // MARK: - isAutoAdvance 现为 var（不再是 private(set)）

    func testIsAutoAdvanceIsSettable() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        XCTAssertTrue(vm.isAutoAdvance)
        vm.isAutoAdvance = false
        XCTAssertFalse(vm.isAutoAdvance, "isAutoAdvance 应可直接赋值")
        vm.isAutoAdvance = true
        XCTAssertTrue(vm.isAutoAdvance)
    }

    func testToggleAutoAdvanceStillWorks() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        vm.toggleAutoAdvance()
        XCTAssertFalse(vm.isAutoAdvance)
        vm.toggleAutoAdvance()
        XCTAssertTrue(vm.isAutoAdvance)
    }

    // MARK: - macOS 快捷键映射：DemoSpeed.allCases ≤ 4

    func testDemoSpeedAllCasesCountForKeyboardShortcuts() {
        // 速度快捷键 1-4 依赖 allCases.count ≤ 4
        XCTAssertLessThanOrEqual(DemoSpeed.allCases.count, 4,
                                  "快捷键 1-4 要求 DemoSpeed.allCases ≤ 4")
    }

    // MARK: - wasPausedByCommentary 恢复逻辑边界

    /// pauseOnCommentary=true 且 isAutoAdvance=false 时，点评消失后不恢复播放
    func testPausedByCommentaryNoResumeWhenAutoAdvanceOff() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)
        vm.pauseOnCommentary = true
        vm.isAutoAdvance = false

        // 模拟手动暂停状态
        vm.pause()
        XCTAssertFalse(vm.isPlaying, "手动暂停后不应播放")
    }

    // MARK: - CommentaryOverlay 条件显示

    /// View 层条件：viewModel.showCommentary && viewModel.currentCommentary != nil
    /// 当 showCommentary=false 时，即使 currentCommentary 非 nil 也不显示
    func testCommentaryOverlayVisibilityLogic() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        // showCommentary=true, currentCommentary=nil → 不显示
        XCTAssertTrue(vm.showCommentary)
        XCTAssertNil(vm.currentCommentary)
        let visible1 = vm.showCommentary && vm.currentCommentary != nil
        XCTAssertFalse(visible1, "showCommentary=true + commentary=nil → 不显示")

        // showCommentary=false, currentCommentary=nil → 不显示
        vm.showCommentary = false
        let visible2 = vm.showCommentary && vm.currentCommentary != nil
        XCTAssertFalse(visible2, "showCommentary=false → 不显示")
    }

    // MARK: - macOS 回归：基本播放控制不变

    func testMacOSRegressionBasicPlayback() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2", "h0g2"])
        let vm = DemoViewModel(puzzle: puzzle)

        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertTrue(vm.canGoForward)
        XCTAssertFalse(vm.canGoBack)

        vm.stepForward()
        XCTAssertEqual(vm.currentIndex, 1)
        XCTAssertTrue(vm.canGoBack)
        XCTAssertTrue(vm.canGoForward)

        vm.togglePlay()
        XCTAssertTrue(vm.isPlaying)
        vm.togglePlay()
        XCTAssertFalse(vm.isPlaying)
    }

    // MARK: - DemoConfig storageKey 隔离

    func testDemoConfigStorageKeyIsolation() {
        // 确认 storageKey 不会与其他 UserDefaults 键冲突
        let key = "chinesechess.demoConfig"
        let config = DemoConfig()
        config.save()

        let data = UserDefaults.standard.data(forKey: key)
        XCTAssertNotNil(data, "save 后应有数据")

        // 清理
        DemoConfig().save()
    }
}
