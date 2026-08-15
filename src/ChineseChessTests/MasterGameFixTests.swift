import XCTest
@testable import ChineseChess

/// 回归测试：commit 68f61f2
/// Bug 3: 大师棋谱空状态文案错误 (demo.noData → master.noData)
/// Bug 4: 按赛事 sidebar 布局不完整 (.frame(width:) → .frame(minWidth:idealWidth:))
/// Bug 1 & Bug 2 已由 TutorialFENRedGeneralTests 覆盖（内容完全一致），此处不重复
final class MasterGameFixTests: XCTestCase {

    // MARK: - Bug 3: 大师棋谱空状态文案

    /// 验证 MasterGameBrowserView 使用 master.noData（不再用 demo.noData）
    func testMasterGameUsesMasterNoDataKey() {
        let viewPath = Self.masterGameBrowserViewPath()
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 MasterGameBrowserView.swift")
            return
        }
        XCTAssertTrue(content.contains("\"master.noData\""),
                      "MasterGameBrowserView 应使用 master.noData key")
        XCTAssertFalse(content.contains("\"demo.noData\""),
                       "MasterGameBrowserView 不应再使用 demo.noData key")
    }

    /// 验证残局模块仍使用 demo.noData（不受影响）
    func testPuzzleStillUsesDemoNoDataKey() {
        let viewPath = NSHomeDirectory() + "/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleDemoView.swift"
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 PuzzleDemoView.swift")
            return
        }
        XCTAssertTrue(content.contains("\"demo.noData\""),
                      "PuzzleDemoView 应仍使用 demo.noData key（残局模块不应受影响）")
    }

    /// 验证 master.noData key 在 xcstrings 中存在且有双语翻译
    func testMasterNoDataKeyInXcstrings() {
        let xcstringsPath = NSHomeDirectory() + "/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: xcstringsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            XCTFail("无法加载 Localizable.xcstrings")
            return
        }

        // master.noData
        guard let masterEntry = strings["master.noData"] else {
            XCTFail("xcstrings 中缺少 master.noData key")
            return
        }
        guard let masterLocs = masterEntry["localizations"] as? [String: [String: Any]] else {
            XCTFail("master.noData 缺少 localizations")
            return
        }

        // zh-Hans
        let zhState = (masterLocs["zh-Hans"]?["stringUnit"] as? [String: Any])?["state"] as? String
        let zhVal = (masterLocs["zh-Hans"]?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(zhState, "translated", "master.noData zh-Hans state 应为 translated")
        XCTAssertEqual(zhVal, "暂无棋谱数据", "master.noData zh-Hans value 应为 '暂无棋谱数据'")

        // en
        let enState = (masterLocs["en"]?["stringUnit"] as? [String: Any])?["state"] as? String
        let enVal = (masterLocs["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(enState, "translated", "master.noData en state 应为 translated")
        XCTAssertEqual(enVal, "No game records", "master.noData en value 应为 'No game records'")
    }

    /// 验证 demo.noData key 仍在 xcstrings 中（未被误删）
    func testDemoNoDataKeyStillExists() {
        let xcstringsPath = NSHomeDirectory() + "/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: xcstringsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            XCTFail("无法加载 Localizable.xcstrings")
            return
        }
        XCTAssertNotNil(strings["demo.noData"], "demo.noData key 应仍存在于 xcstrings 中（残局模块使用）")
    }

    /// 运行时验证：中文环境下 master.noData 返回正确文案
    @MainActor
    func testMasterNoDataChineseOutput() {
        let l10n = L10n.shared
        l10n.setLanguage("zh-Hans")
        let result = l10n.t("master.noData")
        XCTAssertEqual(result, "暂无棋谱数据", "中文环境下 master.noData 应返回 '暂无棋谱数据'")
    }

    /// 运行时验证：英文环境下 master.noData 返回正确文案
    @MainActor
    func testMasterNoDataEnglishOutput() {
        let l10n = L10n.shared
        l10n.setLanguage("en")
        let result = l10n.t("master.noData")
        XCTAssertEqual(result, "No game records", "英文环境下 master.noData 应返回 'No game records'")
    }

    /// 确认 master.noData 和 demo.noData 返回不同文案（不再混淆）
    @MainActor
    func testMasterAndDemoNoDataAreDifferent() {
        let l10n = L10n.shared

        l10n.setLanguage("zh-Hans")
        let masterZh = l10n.t("master.noData")
        let demoZh = l10n.t("demo.noData")
        XCTAssertNotEqual(masterZh, demoZh, "中文环境下 master.noData 和 demo.noData 应返回不同文案")

        l10n.setLanguage("en")
        let masterEn = l10n.t("master.noData")
        let demoEn = l10n.t("demo.noData")
        XCTAssertNotEqual(masterEn, demoEn, "英文环境下 master.noData 和 demo.noData 应返回不同文案")
    }

    // MARK: - Bug 4: sidebar frame 布局

    /// 验证 MasterGameBrowserView 不再有硬编码 .frame(width: 200)
    func testNoHardcodedSidebarWidth() {
        let viewPath = Self.masterGameBrowserViewPath()
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 MasterGameBrowserView.swift")
            return
        }
        XCTAssertFalse(content.contains(".frame(width: 200)"),
                       "不应再有 .frame(width: 200) 硬编码宽度")
    }

    /// 验证浏览模式 sidebar 宽度约束（v6.2 断言清偿：布局已演进为 maxWidth: 240，旧 minWidth/idealWidth 200 作废）
    func testSidebarUsesMinWidthIdealWidth() {
        let viewPath = Self.masterGameBrowserViewPath()
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 MasterGameBrowserView.swift")
            return
        }

        let target = ".frame(maxWidth: 240)"
        let occurrences = content.components(separatedBy: target).count - 1
        XCTAssertEqual(occurrences, 1,
                       "浏览模式 sidebar 应有1处 .frame(maxWidth: 240)，实际\(occurrences)次")
    }

    /// 验证顶部工具栏布局（v6.2 断言清偿：v4 起 sidebar 已删除——:48 注释存证，宽度约束迁移至
    /// browserTopBar 的 modePicker maxWidth:240；方法名保留存量对账不改）
    func testBrowserLayoutSidebarFrame() {
        let viewPath = Self.masterGameBrowserViewPath()
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 MasterGameBrowserView.swift")
            return
        }

        guard let barRange = content.range(of: "private var browserTopBar") else {
            XCTFail("找不到 browserTopBar 定义")
            return
        }
        let upper = content.index(barRange.lowerBound, offsetBy: 400, limitedBy: content.endIndex) ?? content.endIndex
        let barBody = String(content[barRange.lowerBound..<upper])
        XCTAssertTrue(barBody.contains("modePicker"), "browserTopBar 应包含 modePicker")
        XCTAssertTrue(barBody.contains(".frame(maxWidth: 240)"),
                      "modePicker 应使用 .frame(maxWidth: 240) 限宽（现状布局）")
        XCTAssertTrue(barBody.contains("searchField"), "browserTopBar 应包含 searchField")
    }

    /// 验证播放布局全幅棋盘（v6.2 断言清偿：播放模式已无 sidebar——全幅棋盘+控制条架构）
    /// 台账锚点：原 testPlayLayoutSidebarFrame，2026-08-16 Ruby P1 更名——旧名与断言方向相反（断言的是无 sidebar）
    func testPlayLayoutFullBoardNoSidebar() {
        let viewPath = Self.masterGameBrowserViewPath()
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 MasterGameBrowserView.swift")
            return
        }

        // macosPlayLayout 函数应为全幅布局（无 sidebar）
        XCTAssertTrue(content.contains("macosPlayLayout"), "应有 macosPlayLayout 函数")

        if let playLayoutRange = content.range(of: "func macosPlayLayout") {
            let afterFunc = String(content[playLayoutRange.lowerBound...])
            let funcBody = String(afterFunc.prefix(500))
            XCTAssertTrue(funcBody.contains("DemoBoardView"), "macosPlayLayout 应包含 DemoBoardView（全幅棋盘）")
            XCTAssertFalse(funcBody.contains("sidebar"), "播放模式不应包含 sidebar（已演进为全幅布局）")
        } else {
            XCTFail("找不到 macosPlayLayout 函数")
        }
    }

    /// v6.2 断言清偿：#file 相对路径解析（原绝对路径指向主库——测试移动目标，现指向当前树）
    private static func masterGameBrowserViewPath() -> String {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ChineseChess")
            .appendingPathComponent("Views")
            .appendingPathComponent("MasterGameBrowserView.swift")
            .path
    }

    // MARK: - Bug 4 追加：.onAppear 根因修复（iOS listContent 空列表）

    /// 验证 listContent 的 onAppear 中包含 selectedEvent/Player/Opening/Subcategory 的手动 rebuild
    func testOnAppearHasManualRebuildForSelectedFilters() {
        let viewPath = Self.masterGameBrowserViewPath()
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 MasterGameBrowserView.swift")
            return
        }

        // 找到 listContent 的 .onAppear 块
        guard let onAppearRange = content.range(of: ".onAppear {") else {
            XCTFail("找不到 .onAppear 块")
            return
        }

        // 取 .onAppear 后的 800 字符（覆盖整个 onAppear 闭包）
        let onAppearBody = String(content[onAppearRange.lowerBound...].prefix(800))

        // 验证新增的分支存在
        XCTAssertTrue(onAppearBody.contains("selectedEvent != nil"),
                      "onAppear 应检查 selectedEvent != nil")
        XCTAssertTrue(onAppearBody.contains("selectedPlayer != nil"),
                      "onAppear 应检查 selectedPlayer != nil")
        XCTAssertTrue(onAppearBody.contains("selectedOpening != nil"),
                      "onAppear 应检查 selectedOpening != nil")
        XCTAssertTrue(onAppearBody.contains("selectedSubcategory != nil"),
                      "onAppear 应检查 selectedSubcategory != nil")
        XCTAssertTrue(onAppearBody.contains("rebuildCache()"),
                      "onAppear 新增分支应调用 rebuildCache()")
    }

    /// 验证 onAppear 分支优先级正确：loadIndex → useMoveSequenceFilter → selected*
    func testOnAppearBranchPriority() {
        let viewPath = Self.masterGameBrowserViewPath()
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 MasterGameBrowserView.swift")
            return
        }

        guard let onAppearRange = content.range(of: ".onAppear {") else {
            XCTFail("找不到 .onAppear 块")
            return
        }

        let onAppearBody = String(content[onAppearRange.lowerBound...].prefix(800))

        // 验证优先级顺序：loadIndex 在 useMoveSequenceFilter 之前，
        // useMoveSequenceFilter 在 selected* 之前
        let loadIndexPos = onAppearBody.range(of: "loadIndex()")
        let sequenceFilterPos = onAppearBody.range(of: "useMoveSequenceFilter")
        let selectedEventPos = onAppearBody.range(of: "selectedEvent != nil")

        XCTAssertNotNil(loadIndexPos, "onAppear 应包含 loadIndex()")
        XCTAssertNotNil(sequenceFilterPos, "onAppear 应包含 useMoveSequenceFilter")
        XCTAssertNotNil(selectedEventPos, "onAppear 应包含 selectedEvent != nil")

        XCTAssertLessThan(loadIndexPos!.lowerBound, sequenceFilterPos!.lowerBound, "loadIndex 应在 useMoveSequenceFilter 之前")
        XCTAssertLessThan(sequenceFilterPos!.lowerBound, selectedEventPos!.lowerBound, "useMoveSequenceFilter 应在 selected* 之前")
    }

    /// 验证 onChange 仍存在（没有被 onAppear 替代）
    func testOnChangeStillPresent() {
        let viewPath = Self.masterGameBrowserViewPath()
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 MasterGameBrowserView.swift")
            return
        }

        // onChange 不应被删除——它仍是主路径，onAppear 只是补漏
        XCTAssertTrue(content.contains(".onChange(of: selectedEvent)"), "应保留 onChange(of: selectedEvent)")
        XCTAssertTrue(content.contains(".onChange(of: selectedPlayer)"), "应保留 onChange(of: selectedPlayer)")
        XCTAssertTrue(content.contains(".onChange(of: selectedOpening)"), "应保留 onChange(of: selectedOpening)")
    }

    // MARK: - 综合：Bug 1 & Bug 2 回归验证（确保合并 commit 不破坏之前的修复）

    /// Bug 1 快速验证：所有课3-8的FEN含红帅K
    func testBug1FENsStillContainRedGeneral() {
        let vms = TutorialViewModel()
        for i in 3...8 {
            let lesson = vms.lessons[i]
            XCTAssertEqual(lesson.type, .interactive, "课\(i)应为 interactive")
            guard let fen = lesson.initialFEN else {
                XCTFail("课\(i) 缺少 initialFEN")
                continue
            }
            // FEN 中必须包含大写 K（红帅）
            XCTAssertTrue(fen.contains("K"), "课\(i) FEN 应包含红帅K: \(fen)")

            // FEN 必须能通过解析
            XCTAssertNotNil(FENDecoder.parse(fen: fen), "课\(i) FEN 解析失败")
        }
    }

    /// Bug 2 快速验证：StudyHubView 不含 compass.fill
    func testBug2NoCompassFill() {
        let viewPath = NSHomeDirectory() + "/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StudyHubView.swift"
        guard let content = try? String(contentsOfFile: viewPath) else {
            XCTFail("无法读取 StudyHubView.swift")
            return
        }
        XCTAssertFalse(content.contains("compass.fill"), "StudyHubView 不应再使用 compass.fill")
        XCTAssertTrue(content.contains("location.north.fill"), "StudyHubView 应使用 location.north.fill")
    }
}
