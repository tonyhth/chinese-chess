import XCTest
@testable import ChineseChess

// MARK: - Phase B2 Step 4 — iOS DemoControlBar 紧凑布局测试

/// 覆盖 DemoControlBar/DemoInfoBar iOS 布局涉及的 ViewModel 逻辑、
/// DemoItemWrapper 属性、DemoSpeed 全量遍历、toggleAutoAdvance 绑定语义
@MainActor
final class B2Step4DemoControlBarTests: XCTestCase {

    // MARK: - 辅助

    private func makePuzzle(solution: [String], initialFEN: String = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1") -> Puzzle {
        Puzzle(
            id: "test-b2s4-\(UUID().uuidString.prefix(8))",
            name: "B2S4测试残局",
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

    // MARK: - toggleAutoAdvance 绑定语义（iOS Toggle 使用 get/set 绑定）

    /// Toggle 绑定：set 忽略传入值，依赖 toggleAutoAdvance() 翻转
    /// 验证多次 toggle 后状态正确
    func testToggleAutoAdvanceBindingSemantics() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        // 初始：isAutoAdvance = true
        XCTAssertTrue(vm.isAutoAdvance)

        // 模拟 Toggle 的 Binding set {_ in toggleAutoAdvance() }
        // Toggle 可能传入 true 或 false，但 set 被忽略
        vm.toggleAutoAdvance()
        XCTAssertFalse(vm.isAutoAdvance, "第一次 toggle 应关闭")

        vm.toggleAutoAdvance()
        XCTAssertTrue(vm.isAutoAdvance, "第二次 toggle 应开启")

        // 连续快速切换
        vm.toggleAutoAdvance()
        vm.toggleAutoAdvance()
        XCTAssertTrue(vm.isAutoAdvance, "快速双 toggle 应回到原状态")
    }

    /// Toggle 绑定 get 与实际状态一致
    func testToggleBindingGetMatchesState() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2"])
        let vm = DemoViewModel(puzzle: puzzle)

        // 模拟 Toggle Binding get: { viewModel.isAutoAdvance }
        var bindingGet = vm.isAutoAdvance
        XCTAssertTrue(bindingGet, "Binding get 应返回 true")

        vm.toggleAutoAdvance()
        bindingGet = vm.isAutoAdvance
        XCTAssertFalse(bindingGet, "toggle 后 Binding get 应返回 false")
    }

    // MARK: - DemoSpeed 全量遍历（Menu 替代 Segmented 后仍使用 allCases）

    /// Menu 遍历 DemoSpeed.allCases，验证顺序与内容完整
    func testDemoSpeedAllCasesComplete() {
        let allCases = DemoSpeed.allCases
        XCTAssertEqual(allCases.count, 4, "应有 4 个速度档位")
        XCTAssertEqual(allCases[0], .slow)
        XCTAssertEqual(allCases[1], .normal)
        XCTAssertEqual(allCases[2], .fast)
        XCTAssertEqual(allCases[3], .turbo)
    }

    /// 验证每个速度档位的 label 非空且唯一
    func testDemoSpeedLabelsUniqueAndNonEmpty() {
        let labels = DemoSpeed.allCases.map { $0.label }
        for label in labels {
            XCTAssertFalse(label.isEmpty, "速度 label 不应为空")
        }
        let uniqueLabels = Set(labels)
        XCTAssertEqual(uniqueLabels.count, labels.count, "速度 label 应唯一")
    }

    /// Menu 显示当前选中速度的 label
    func testSpeedMenuDisplaysCurrentSpeed() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        XCTAssertEqual(vm.speed, .normal, "默认速度应为 normal")
        XCTAssertEqual(vm.speed.label, "1x", "默认 label 应为 1x")

        vm.speed = .fast
        XCTAssertEqual(vm.speed.label, "2x", "切换后 label 应更新")
    }

    /// 速度切换后 BoardPlayer 速度同步
    func testSpeedChangeSyncsToBoardPlayer() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2"])
        let vm = DemoViewModel(puzzle: puzzle)

        vm.speed = .turbo
        XCTAssertEqual(vm.boardPlayer.speed, 3.0, "BoardPlayer.speed 应与 DemoSpeed.turbo.rawValue 一致")

        vm.speed = .slow
        XCTAssertEqual(vm.boardPlayer.speed, 0.5, "BoardPlayer.speed 应与 DemoSpeed.slow.rawValue 一致")
    }

    // MARK: - DemoItemWrapper 属性（DemoInfoBar 使用的 demoTitle/demoCategory/demoSubtitle）

    func testDemoItemWrapperPuzzleProperties() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let wrapper = DemoItemWrapper.puzzle(puzzle)

        XCTAssertFalse(wrapper.demoTitle.isEmpty, "demoTitle 不应为空")
        XCTAssertFalse(wrapper.demoCategory.isEmpty, "demoCategory 不应为空")
        XCTAssertFalse(wrapper.demoSubtitle.isEmpty, "demoSubtitle 不应为空")
        XCTAssertEqual(wrapper.initialFEN, puzzle.initialFEN, "initialFEN 应一致")
    }

    // MARK: - onBackToList 闭包传递（DemoInfoBar 新增参数）

    /// DemoInfoBar 新增 onBackToList 可选闭包，验证 DemoViewModel 不直接参与
    /// 这是一个 View 层连接测试，在 macOS 编译中验证
    func testDemoInfoBarBackButtonDoesNotAffectViewModel() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        // ViewModel 没有返回列表的方法——这是 View 层的职责
        // 但 ViewModel 有 cleanup 相关方法
        vm.pause()
        XCTAssertFalse(vm.isPlaying, "pause 后应停止播放")

        // resultDisplayTimer 应在 cleanupViewModel 时被 cancel
        // 测试 ViewModel 的 pause 不影响 isAutoAdvance
        XCTAssertTrue(vm.isAutoAdvance, "pause 不应影响 isAutoAdvance")
    }

    // MARK: - iOS 进度条边界：totalSteps=0 时 max(totalSteps, 1)

    func testProgressBarTotalStepsZero() {
        let puzzle = makePuzzle(solution: [])
        let vm = DemoViewModel(puzzle: puzzle)

        XCTAssertEqual(vm.totalSteps, 0, "空 solution totalSteps=0")
        // ProgressView total: max(0, 1) = 1，不会除以零
        let progressTotal = Double(max(vm.totalSteps, 1))
        XCTAssertEqual(progressTotal, 1.0, "totalSteps=0 时 ProgressView total 应为 1")
    }

    func testProgressBarTotalStepsNormal() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2"])
        let vm = DemoViewModel(puzzle: puzzle)

        XCTAssertEqual(vm.totalSteps, 2)
        let progressTotal = Double(max(vm.totalSteps, 1))
        XCTAssertEqual(progressTotal, 2.0)
    }

    func testProgressBarValueAtStart() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2"])
        let vm = DemoViewModel(puzzle: puzzle)

        let progressValue = Double(vm.currentIndex)
        XCTAssertEqual(progressValue, 0.0, "初始进度值为 0")
    }

    func testProgressBarValueAtEnd() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        vm.stepForward()
        let progressValue = Double(vm.currentIndex)
        let progressTotal = Double(max(vm.totalSteps, 1))
        XCTAssertEqual(progressValue / progressTotal, 1.0, "末尾进度比应为 1.0")
    }

    // MARK: - 按钮禁用状态（stepBack/stepForward disabled 绑定）

    func testStepBackDisabledAtStart() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)
        XCTAssertFalse(vm.canGoBack, "初始 canGoBack=false → stepBack 按钮 disabled")
    }

    func testStepForwardDisabledAtEnd() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)
        vm.stepForward()
        XCTAssertFalse(vm.canGoForward, "末尾 canGoForward=false → stepForward 按钮 disabled")
    }

    func testStepButtonsEnabledInMiddle() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2", "h0g2"])
        let vm = DemoViewModel(puzzle: puzzle)
        vm.stepForward()
        XCTAssertTrue(vm.canGoBack, "中间步 canGoBack=true")
        XCTAssertTrue(vm.canGoForward, "中间步 canGoForward=true")
    }

    // MARK: - play/pause 图标切换逻辑（isPlaying → pause.fill / play.fill）

    func testPlayPauseIconToggle() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2"])
        let vm = DemoViewModel(puzzle: puzzle)

        XCTAssertFalse(vm.isPlaying, "初始 isPlaying=false → 显示 play.fill")

        vm.togglePlay()
        XCTAssertTrue(vm.isPlaying, "togglePlay 后 isPlaying=true → 显示 pause.fill")

        vm.togglePlay()
        XCTAssertFalse(vm.isPlaying, "再次 togglePlay → 显示 play.fill")
    }

    // MARK: - macOS 布局不受影响

    /// DemoInfoBar 新增 onBackToList 参数是可选的（默认 nil）
    /// macOS 布局在 onBackToList=nil 时仍显示 Text（非按钮）
    /// 此测试验证 ViewModel 层面无回归
    func testMacOSLayoutNoRegression() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        // 所有 ViewModel API 应正常工作
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertTrue(vm.canGoForward)
        XCTAssertFalse(vm.canGoBack)
        XCTAssertTrue(vm.isAutoAdvance)
        XCTAssertEqual(vm.speed, .normal)
        XCTAssertFalse(vm.isPlaying)
        XCTAssertEqual(vm.totalSteps, 1)

        vm.stepForward()
        XCTAssertEqual(vm.currentIndex, 1)
        XCTAssertFalse(vm.canGoForward)
    }

    // MARK: - DemoSpeed Identifiable / CaseIterable 一致性

    func testDemoSpeedIdentifiableUsesRawValue() {
        for speed in DemoSpeed.allCases {
            XCTAssertEqual(speed.id, speed.rawValue, "DemoSpeed.id 应等于 rawValue")
        }
    }

    func testDemoSpeedStepIntervalConsistency() {
        for speed in DemoSpeed.allCases {
            XCTAssertEqual(speed.stepInterval, 1.0 / speed.rawValue, accuracy: 0.01,
                           "stepInterval 应等于 1/rawValue")
        }
    }
}
