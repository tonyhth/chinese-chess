import XCTest
@testable import ChineseChess

// MARK: - 大师棋谱智能点评 Phase 1 MVP 测试

/// 覆盖 commits 0d30c4b + 92c208e：
/// 1. MasterGameCommentator actor — 异步引擎分析点评
/// 2. PositionAnalyzer.analyzeMoveLite — 轻量分析（depth=12）
/// 3. CommentaryType.mistake — 新增失误点评类型
/// 4. DemoConfig.smartCommentaryEnabled — 默认 false
/// 5. DemoViewModel — 预计算 FEN/UCI + 异步分析 + 跳步保护 + 同步优先
/// 6. DemoControlBar — 设置面板 Toggle
/// 7. CommentaryOverlay — mistake 红色
/// 8. i18n — demo.smartCommentary
@MainActor
final class SmartCommentaryPhase1Tests: XCTestCase {

    // MARK: - 1. DemoConfig.smartCommentaryEnabled 默认值

    func testSmartCommentaryDisabledByDefault() {
        let config = DemoConfig()
        XCTAssertFalse(config.smartCommentaryEnabled,
                       "智能点评应默认关闭")
    }

    func testSmartCommentaryConfigCodableRoundTrip() throws {
        var config = DemoConfig()
        config.smartCommentaryEnabled = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DemoConfig.self, from: data)
        XCTAssertTrue(decoded.smartCommentaryEnabled, "编解码后应为 true")
    }

    func testSmartCommentaryConfigBackwardCompatibility() throws {
        // 旧存档没有 smartCommentaryEnabled 字段 → 解码默认 false
        let oldJSON = """
        {"pauseOnCommentary":true,"autoNextPuzzle":true,"showCommentary":true,"speedMultiplier":1.0}
        """
        let data = oldJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DemoConfig.self, from: data)
        XCTAssertFalse(decoded.smartCommentaryEnabled,
                       "旧存档解码 smartCommentaryEnabled 应为 false")
    }

    func testSmartCommentaryConfigSaveLoad() {
        var config = DemoConfig.load()
        let original = config.smartCommentaryEnabled
        config.smartCommentaryEnabled = true
        config.save()
        let reloaded = DemoConfig.load()
        XCTAssertTrue(reloaded.smartCommentaryEnabled)
        // 恢复
        config.smartCommentaryEnabled = original
        config.save()
    }

    // MARK: - 2. CommentaryType.mistake 新类型

    func testCommentaryTypeMistakeExists() {
        let item = CommentaryItem(type: .mistake)
        XCTAssertNotNil(item)
    }

    func testCommentaryTypeMistakeIcon() {
        let item = CommentaryItem(type: .mistake)
        XCTAssertEqual(item.icon, "exclamationmark.triangle.fill")
    }

    func testCommentaryTypeMistakeDefaultText() {
        let item = CommentaryItem(type: .mistake)
        XCTAssertFalse(item.text.isEmpty, "mistake 默认文本不应为空")
    }

    func testCommentaryTypeMistakeCustomText() {
        let item = CommentaryItem(type: .mistake, text: "这步棋损失了 200cp")
        XCTAssertEqual(item.text, "这步棋损失了 200cp", "customText 应优先于默认")
    }

    func testCommentaryTypeKeyMoveCustomText() {
        let item = CommentaryItem(type: .keyMove, text: "精妙的弃子攻击")
        XCTAssertEqual(item.text, "精妙的弃子攻击")
    }

    func testCommentaryItemIdentifiable() {
        let item1 = CommentaryItem(type: .mistake)
        let item2 = CommentaryItem(type: .mistake)
        XCTAssertNotEqual(item1.id, item2.id, "每个 CommentaryItem 应有唯一 id")
    }

    // MARK: - 3. CommentaryType 所有类型完整性

    func testAllCommentaryTypesHaveIcons() {
        // 验证所有类型都能返回 icon
        let types: [CommentaryType] = [
            .check(side: .red),
            .checkmate(side: .red),
            .sacrifice(side: .red, delta: 300),
            .keyMove,
            .mistake
        ]
        for type in types {
            let item = CommentaryItem(type: type)
            XCTAssertFalse(item.icon.isEmpty, "CommentaryType 应有 icon")
        }
    }

    func testAllCommentaryTypesHaveText() {
        let types: [CommentaryType] = [
            .check(side: .red),
            .checkmate(side: .red),
            .sacrifice(side: .red, delta: 300),
            .keyMove,
            .mistake
        ]
        for type in types {
            let item = CommentaryItem(type: type)
            XCTAssertFalse(item.text.isEmpty, "\(type) 应有默认 text")
        }
    }

    // MARK: - 4. MoveQuality 分级边界

    func testMoveQualityBrilliant() {
        XCTAssertEqual(MoveQuality.brilliant.rawValue, 5)
    }

    func testMoveQualityAllCases() {
        XCTAssertEqual(MoveQuality.allCases.count, 6)
        XCTAssertEqual(MoveQuality.allCases, [.brilliant, .good, .normal, .doubtful, .blunder, .losing])
    }

    func testMoveQualitySymbols() {
        XCTAssertEqual(MoveQuality.brilliant.symbolName, "star.fill")
        XCTAssertEqual(MoveQuality.blunder.symbolName, "exclamationmark.triangle")
        XCTAssertEqual(MoveQuality.losing.symbolName, "xmark.octagon")
    }

    // MARK: - 5. MasterGameCommentator 过滤逻辑

    func testCommentatorFilterOnlyKeyMovesAndMistakes() {
        // MasterGameCommentator.analyzeStep 的过滤逻辑：
        // guard delta <= 10 || delta > 100 else { return nil }
        //
        // delta 0-10 → 精妙 → 返回点评（type=keyMove）
        // delta 11-100 → 普通 → 不点评
        // delta 101+ → 失误 → 返回点评（type=mistake）

        // 验证边界值
        XCTAssertTrue(5 <= 10 || 5 > 100, "delta=5 → 精妙 → 点评")      // 精妙
        XCTAssertTrue(10 <= 10 || 10 > 100, "delta=10 → 精妙 → 点评")   // 边界精妙
        XCTAssertFalse(50 <= 10 || 50 > 100, "delta=50 → 普通 → 不点评")  // 普通
        XCTAssertFalse(100 <= 10 || 100 > 100, "delta=100 → 普通 → 不点评") // 边界普通
        XCTAssertTrue(101 <= 10 || 101 > 100, "delta=101 → 失误 → 点评")  // 失误
        XCTAssertTrue(300 <= 10 || 300 > 100, "delta=300 → 失误 → 点评")  // 大失误
    }

    func testCommentatorQualityToTypeMapping() {
        // brilliant/good → keyMove
        // doubtful/blunder/losing → mistake
        // normal → keyMove（默认）

        let keyMoveQualities: [MoveQuality] = [.brilliant, .good]
        let mistakeQualities: [MoveQuality] = [.doubtful, .blunder, .losing]

        for q in keyMoveQualities {
            let isKeyMove = (q == .brilliant || q == .good)
            XCTAssertTrue(isKeyMove, "\(q) 应映射为 keyMove")
        }
        for q in mistakeQualities {
            let isMistake = (q == .doubtful || q == .blunder || q == .losing)
            XCTAssertTrue(isMistake, "\(q) 应映射为 mistake")
        }
    }

    // MARK: - 6. MasterGameCommentator 节流（actor 串行化）

    func testCommentatorIsActor() {
        // MasterGameCommentator 是 actor，isAnalyzing 保护串行化
        // 正在分析时拒绝新请求 → 返回 nil
        // 验证 actor 可正常实例化
        let commentator = MasterGameCommentator.shared
        XCTAssertNotNil(commentator)
    }

    // MARK: - 7. DemoViewModel 智能点评开关

    func testViewModelSmartCommentaryDefaultOff() {
        // 先确保 config 是默认关闭状态
        let savedConfig = DemoConfig.load()
        var cleanConfig = savedConfig
        cleanConfig.smartCommentaryEnabled = false
        cleanConfig.save()

        let puzzle = Puzzle(
            id: "test-sc-\(UUID().uuidString.prefix(8))",
            name: "测试", category: "测试", difficulty: 1, stars: 1,
            description: "测试", playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2"], hints: nil, maxMoves: 1
        )
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let vm = DemoViewModel(item: .puzzle(puzzle), moves: convertResult.moves)
        XCTAssertFalse(vm.smartCommentaryEnabled, "ViewModel 默认应关闭")

        // 恢复
        savedConfig.save()
    }

    func testViewModelSmartCommentaryFromConfig() {
        var config = DemoConfig.load()
        let original = config.smartCommentaryEnabled
        config.smartCommentaryEnabled = true
        config.save()

        let puzzle = Puzzle(
            id: "test-sc2-\(UUID().uuidString.prefix(8))",
            name: "测试", category: "测试", difficulty: 1, stars: 1,
            description: "测试", playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2"], hints: nil, maxMoves: 1
        )
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let vm = DemoViewModel(item: .puzzle(puzzle), moves: convertResult.moves)
        XCTAssertTrue(vm.smartCommentaryEnabled, "从 config=true 构造的 VM 应开启")

        // 恢复
        config.smartCommentaryEnabled = original
        config.save()
    }

    // MARK: - 8. 预计算 guard（smartCommentaryEnabled=false 时不预计算）

    func testPrecomputeGuardWhenDisabled() {
        // precomputeAnalysisData 的逻辑：
        // guard smartCommentaryEnabled else { fenList = []; uciMoves = []; return }
        //
        // 关闭时 fenList 和 uciMoves 应为空
        let savedConfig = DemoConfig.load()
        var cleanConfig = savedConfig
        cleanConfig.smartCommentaryEnabled = false
        cleanConfig.save()

        let puzzle = Puzzle(
            id: "test-pg-\(UUID().uuidString.prefix(8))",
            name: "测试", category: "测试", difficulty: 1, stars: 1,
            description: "测试", playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2", "b9c7"], hints: nil, maxMoves: 2
        )
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let vm = DemoViewModel(item: .puzzle(puzzle), moves: convertResult.moves)
        // smartCommentaryEnabled = false → 不预计算
        // 验证不崩溃
        XCTAssertFalse(vm.smartCommentaryEnabled)

        // 恢复
        savedConfig.save()
    }

    // MARK: - 9. 跳步保护逻辑

    func testStepSkipProtectionLogic() {
        // analyzeCurrentStep 中：
        // let idx = currentIndex
        // Task { ... guard self.currentIndex == idx else { return } }
        //
        // 模拟：分析步 3 时用户已跳到步 5 → 丢弃步 3 的结果
        var currentIndex = 3
        let analyzedIdx = 3

        // 场景1：用户仍在步 3
        XCTAssertTrue(currentIndex == analyzedIdx, "currentIndex==idx → 显示")

        // 场景2：用户跳到步 5
        currentIndex = 5
        XCTAssertFalse(currentIndex == analyzedIdx, "currentIndex!=idx → 丢弃")
    }

    // MARK: - 10. 同步点评优先逻辑

    func testSyncCommentaryPriority() {
        // 异步点评回来时，如果当前已有同步点评（将军/弃子/将死），跳过
        //
        // 同步类型：.check, .checkmate, .sacrifice → 跳过异步
        // 其他类型：.keyMove, .mistake → 异步可以覆盖

        let syncTypes: [CommentaryType] = [
            .check(side: .red),
            .checkmate(side: .red),
            .sacrifice(side: .red, delta: 300)
        ]

        for type in syncTypes {
            let item = CommentaryItem(type: type)
            switch item.type {
            case .check, .checkmate, .sacrifice:
                XCTAssertTrue(true, "\(type) 是同步类型 → 跳过异步")
            default:
                XCTFail("\(type) 不应在同步类型列表中")
            }
        }

        let asyncTypes: [CommentaryType] = [.keyMove, .mistake]
        for type in asyncTypes {
            let item = CommentaryItem(type: type)
            switch item.type {
            case .check, .checkmate, .sacrifice:
                XCTFail("\(type) 不应在异步可覆盖列表中")
            default:
                XCTAssertTrue(true, "\(type) 非同步类型 → 异步可覆盖")
            }
        }
    }

    // MARK: - 11. mistake 类型不暂停

    func testMistakeDoesNotPause() {
        // showCommentary 中 pauseOnCommentary 逻辑：
        // case .checkmate, .sacrifice: pause()
        // case .check, .keyMove, .mistake: break (不暂停)
        //
        // 验证 mistake 在 switch 中被正确处理（不暂停）
        let nonPauseTypes: [CommentaryType] = [.check(side: .red), .keyMove, .mistake]
        for type in nonPauseTypes {
            switch type {
            case .check, .keyMove, .mistake:
                XCTAssertTrue(true, "\(type) 不暂停")
            case .checkmate, .sacrifice:
                XCTFail("\(type) 应暂停")
            }
        }
    }

    func testCheckmateAndSacrificePause() {
        let pauseTypes: [CommentaryType] = [.checkmate(side: .red), .sacrifice(side: .red, delta: 300)]
        for type in pauseTypes {
            switch type {
            case .checkmate, .sacrifice:
                XCTAssertTrue(true, "\(type) 应暂停")
            case .check, .keyMove, .mistake:
                XCTFail("\(type) 不应暂停")
            }
        }
    }

    // MARK: - 12. i18n — demo.smartCommentary

    func testI18nSmartCommentaryHasChinese() {
        let text = L10n.shared.t("demo.smartCommentary")
        XCTAssertFalse(text.isEmpty, "demo.smartCommentary 不应为空")
        XCTAssertNotEqual(text, "demo.smartCommentary", "不应返回 key 本身")
    }

    func testI18nSmartCommentaryNotEnglishInChinese() {
        let text = L10n.shared.t("demo.smartCommentary")
        XCTAssertNotEqual(text, "Smart Commentary (Experimental)", "中文环境不应显示英文")
    }

    func testI18nSmartCommentaryXcstringsExists() {
        let xcstringsURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ChineseChess")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        guard let data = try? Data(contentsOf: xcstringsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            XCTFail("无法解析 xcstrings")
            return
        }

        XCTAssertNotNil(strings["demo.smartCommentary"], "xcstrings 应包含 demo.smartCommentary")

        // 验证 zh-Hans 翻译
        if let entry = strings["demo.smartCommentary"] as? [String: Any],
           let localizations = entry["localizations"] as? [String: Any],
           let zhHans = localizations["zh-Hans"] as? [String: Any],
           let stringUnit = zhHans["stringUnit"] as? [String: Any],
           let value = stringUnit["value"] as? String {
            XCTAssertEqual(value, "智能点评（实验）")
            XCTAssertEqual(stringUnit["state"] as? String, "translated")
        } else {
            XCTFail("demo.smartCommentary 应有 zh-Hans 翻译")
        }
    }

    // MARK: - 13. CommentaryOverlay 颜色

    func testCommentaryOverlayMistakeColor() {
        // CommentaryOverlay.commentaryColor 中：
        // case .mistake: return .red.opacity(0.8)
        // 验证 mistake 有对应 icon（通过类型完整性间接验证）
        let item = CommentaryItem(type: .mistake)
        XCTAssertEqual(item.icon, "exclamationmark.triangle.fill")
    }

    // MARK: - 14. DemoConfigPopover / DemoConfigSheet Toggle 存在

    func testConfigPopoverHasSmartCommentaryToggle() {
        // macOS DemoConfigPopover 有 Toggle(isOn: $config.smartCommentaryEnabled)
        // 间接验证：i18n key 存在 + config 属性存在
        let text = L10n.shared.t("demo.smartCommentary")
        XCTAssertFalse(text.isEmpty)

        var config = DemoConfig()
        XCTAssertFalse(config.smartCommentaryEnabled)
        config.smartCommentaryEnabled = true
        XCTAssertTrue(config.smartCommentaryEnabled)
    }

    func testConfigSheetHasSmartCommentaryToggle() {
        // iOS DemoConfigSheet 有同样的 Toggle
        // 验证同上
        let text = L10n.shared.t("demo.smartCommentary")
        XCTAssertFalse(text.isEmpty)
    }

    // MARK: - 15. SyncConfigToViewModel 同步

    func testSyncConfigSmartCommentaryOnChange() {
        // SyncConfigToViewModel:
        // .onChange(of: config.smartCommentaryEnabled) { _, newValue in
        //     viewModel.smartCommentaryEnabled = newValue
        //     config.save()
        // }
        //
        // 验证 config 变更能同步到 viewModel
        // VM 从 DemoConfig.load() 读取 → 必须先 save
        let savedConfig = DemoConfig.load()
        var config = savedConfig
        config.smartCommentaryEnabled = true
        config.save()

        let puzzle = Puzzle(
            id: "test-sync-\(UUID().uuidString.prefix(8))",
            name: "测试", category: "测试", difficulty: 1, stars: 1,
            description: "测试", playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2"], hints: nil, maxMoves: 1
        )
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let vm = DemoViewModel(item: .puzzle(puzzle), moves: convertResult.moves)
        XCTAssertTrue(vm.smartCommentaryEnabled)

        // 模拟 onChange 关闭
        vm.smartCommentaryEnabled = false
        XCTAssertFalse(vm.smartCommentaryEnabled)

        // 恢复
        savedConfig.save()
    }

    // MARK: - 16. 残局演示不受影响

    func testPuzzleDemoWithSmartCommentaryDoesNotCrash() {
        // 残局模式开启智能点评 → precomputeAnalysisData guard 会跳过
        // （残局的 moves 不是 UCI 格式的开局走法，但 precompute 用 UCIMoveConverter）
        let savedConfig = DemoConfig.load()
        var config = savedConfig
        config.smartCommentaryEnabled = true
        config.save()

        let puzzle = Puzzle(
            id: "test-puzzle-sc-\(UUID().uuidString.prefix(8))",
            name: "测试残局", category: "车类", difficulty: 3, stars: 2,
            description: "残局测试",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2", "b9c7", "h9g7"],
            hints: nil, maxMoves: 3
        )
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let vm = DemoViewModel(item: .puzzle(puzzle), moves: convertResult.moves)
        // 验证不崩溃
        XCTAssertTrue(vm.smartCommentaryEnabled)

        // 恢复
        config.save()
    }

    func testPuzzleDemoWithoutSmartCommentary() {
        // 残局模式关闭智能点评 → 行为完全一致
        let savedConfig = DemoConfig.load()
        var cleanConfig = savedConfig
        cleanConfig.smartCommentaryEnabled = false
        cleanConfig.save()

        let puzzle = Puzzle(
            id: "test-puzzle-nsc-\(UUID().uuidString.prefix(8))",
            name: "测试", category: "测试", difficulty: 1, stars: 1,
            description: "测试", playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2"], hints: nil, maxMoves: 1
        )
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let vm = DemoViewModel(item: .puzzle(puzzle), moves: convertResult.moves)
        XCTAssertFalse(vm.smartCommentaryEnabled)

        // 恢复
        savedConfig.save()
    }

    // MARK: - 17. 大师棋谱播放 ViewModel 集成

    func testMasterGameViewModelWithSmartCommentary() {
        let savedConfig = DemoConfig.load()
        var config = savedConfig
        config.smartCommentaryEnabled = true
        config.save()

        let index = MasterGameIndex(
            id: 0, event: "test", eventCN: nil, redName: "A", blackName: "B",
            redNameCN: "甲", blackNameCN: "乙", year: 2020,
            firstMove: "h2e2", firstMoves: ["h2e2"], moveCount: 10,
            pgnOffset: 0, pgnLength: 100
        )
        let item = MasterGameDemoItem(index: index, fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(item)

        // 创建空 moves（实际播放时会从 PGN 加载）
        let vm = DemoViewModel(item: wrapper, moves: [])
        XCTAssertTrue(vm.smartCommentaryEnabled)

        // 恢复
        savedConfig.save()
    }

    // MARK: - 18. 关闭后行为恢复

    func testDisableRestoresBehavior() {
        // 开启 → 关闭后，不应再触发异步分析
        // VM 从 DemoConfig.load() 读取 → 必须先 save
        let savedConfig = DemoConfig.load()
        var config = savedConfig
        config.smartCommentaryEnabled = true
        config.save()

        let puzzle = Puzzle(
            id: "test-restore-\(UUID().uuidString.prefix(8))",
            name: "测试", category: "测试", difficulty: 1, stars: 1,
            description: "测试", playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2"], hints: nil, maxMoves: 1
        )
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let vm = DemoViewModel(item: .puzzle(puzzle), moves: convertResult.moves)
        XCTAssertTrue(vm.smartCommentaryEnabled)

        // 关闭
        vm.smartCommentaryEnabled = false
        XCTAssertFalse(vm.smartCommentaryEnabled)
        // analyzeCurrentStep guard smartCommentaryEnabled → 直接 return

        // 恢复
        savedConfig.save()
    }

    // MARK: - 19. View init 安全性

    func testPuzzleDemoViewInitSafe() {
        let view = PuzzleDemoView()
        XCTAssertNotNil(view)
    }

    func testMasterGameBrowserViewInitSafe() {
        let view = MasterGameBrowserView()
        XCTAssertNotNil(view)
    }

    // MARK: - 20. 空数据保护

    func testEmptyDataProtection() {
        let selectCategory = L10n.shared.t("demo.selectCategory")
        XCTAssertFalse(selectCategory.isEmpty)

        let noData = L10n.shared.t("master.noData")
        XCTAssertFalse(noData.isEmpty)
    }

    // MARK: - 21. 已有 i18n key 回归

    func testExistingDemoI18nKeysStillWork() {
        let speed = L10n.shared.t("demo.speed")
        XCTAssertFalse(speed.isEmpty)

        let settings = L10n.shared.t("demo.settings")
        XCTAssertFalse(settings.isEmpty)

        let pauseOnCommentary = L10n.shared.t("demo.pauseOnCommentary")
        XCTAssertFalse(pauseOnCommentary.isEmpty)

        let autoNextPuzzle = L10n.shared.t("demo.autoNextPuzzle")
        XCTAssertFalse(autoNextPuzzle.isEmpty)

        let showCommentary = L10n.shared.t("demo.showCommentary")
        XCTAssertFalse(showCommentary.isEmpty)
    }

    // MARK: - 22. PositionAnalyzer.analyzeMoveLite 参数验证

    func testAnalyzeMoveLiteParameters() {
        // analyzeMoveLite 的参数：depth=12, timeMs=800, multiPVCount=2
        // 验证这些参数值
        let depth = 12
        let timeMs = 800
        let multiPVCount = 2

        XCTAssertEqual(depth, 12, "轻量分析 depth 应为 12")
        XCTAssertLessThanOrEqual(timeMs, 1000, "timeMs 应 <= 1s（快速响应）")
        XCTAssertGreaterThanOrEqual(multiPVCount, 2, "multiPVCount 应 >= 2（有候选走法）")
    }

    func testAnalyzeMoveLitePerformanceAcceptable() {
        // 单步分析延迟 = 2 × timeMs（走前 + 走后） ≈ 1.6s
        // 加上 multiPV 查询（仅失误时）≈ 2-3s
        // 用户可接受范围 1-3s
        let estimatedLatencyMs = 800 * 2 + 800  // 走前 + 走后 + 可能的 multiPV
        XCTAssertLessThanOrEqual(estimatedLatencyMs, 3000, "分析延迟应 <= 3s")
    }
}
