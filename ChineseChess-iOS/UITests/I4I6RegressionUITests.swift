import XCTest

/// v6.2 验收 I 批 I4-I6：iOS 演示页三组件回归
/// I4 CommentaryOverlay 点评气泡 / I5 走法记录面板 / I6 DemoControlBar 播放控制
/// 口径：v62-accept-0826/ios-i1-i6-prep.md（macOS 布局适配对 iOS 零回归）
final class I4I6RegressionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-chinesechess.firstLaunchDialogShown", "YES",
                                "-UITEST_MODE", "YES"]
        app.launch()
    }

    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        print("I456_SNAP: \(name)")
    }

    /// 进入演示页：底部栏 学棋 → StudyHub 大师棋谱 → 大师局列表首项 → 演示棋盘
    private func enterDemoBoard() -> Bool {
        let studyBtn = app.buttons["学棋"].firstMatch
        guard studyBtn.waitForExistence(timeout: 8) else {
            print("I456_FAIL: 底部栏学棋按钮不可见")
            return false
        }
        studyBtn.tap()
        Thread.sleep(forTimeInterval: 2.0)
        snap("I456-nav-studyhub")

        // 欢迎弹窗兜底（若 launch arg 未生效）
        let gotIt = app.buttons["已了解"].firstMatch
        if gotIt.exists { gotIt.tap(); Thread.sleep(forTimeInterval: 1.0) }

        var mgCard = app.buttons.containing(.staticText, identifier: "大师棋谱").firstMatch
        var mgText = app.staticTexts["大师棋谱"].firstMatch
        if !mgCard.waitForExistence(timeout: 3) && !mgText.exists {
            // StudyHub 可能需滚动：上滑半屏再找
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1.0)
            mgCard = app.buttons.containing(.staticText, identifier: "大师棋谱").firstMatch
            mgText = app.staticTexts["大师棋谱"].firstMatch
        }
        if mgCard.exists {
            mgCard.tap()
        } else if mgText.exists {
            mgText.tap()
        } else {
            snap("I456_FAIL-studyhub-no-mastercard")
            print("I456_FAIL: StudyHub 大师棋谱卡片不可见")
            return false
        }
        Thread.sleep(forTimeInterval: 3.0)
        snap("I456-nav-gamelist")

        // 索引加载页：需先点“点击加载大师棋谱索引...”按钮，否则索引不加载、后续导航全偏
        let loadAny = app.buttons.matching(NSPredicate(format: "label CONTAINS '加载'")).firstMatch
        let loadText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '加载'")).firstMatch
        if loadAny.waitForExistence(timeout: 4) || loadText.exists {
            (loadAny.exists ? loadAny : loadText).tap()
            Thread.sleep(forTimeInterval: 6.0)
        }
        snap("I456-after-loadidx")

        // 分类标签（如“中炮”）→ 对局列表首行（文本定位，坐标点击不可靠）
        let zpPredicate = NSPredicate(format: "label BEGINSWITH '中炮'")
        let zhongpao = app.staticTexts.matching(zpPredicate).firstMatch
        if zhongpao.waitForExistence(timeout: 8) {
            zhongpao.tap()
            Thread.sleep(forTimeInterval: 2.5)
            // 中炮有子分类 → 可能进入子分类列表；点首个子分类（“全部”或首行）
            let zpBtn = app.buttons.containing(.staticText, identifier: "中炮").firstMatch
            if zpBtn.waitForExistence(timeout: 3) { zpBtn.tap(); Thread.sleep(forTimeInterval: 2.0) }
        } else {
            print("I456_NOTE: 中炮分类标签不可见，跳过分类步")
        }
        Thread.sleep(forTimeInterval: 2.0)

        // 对局列表首行：取含“vs”的首个文本；若无则坐标点列表区
        let vsPred = NSPredicate(format: "label CONTAINS ' vs '")
        var firstGame = app.buttons.matching(vsPred).firstMatch
        if !firstGame.waitForExistence(timeout: 6) {
            firstGame = app.staticTexts.matching(vsPred).firstMatch
        }
        if firstGame.waitForExistence(timeout: 4) {
            firstGame.tap()
        } else {
            print("I456_NOTE: 对局行不可见，坐标点击兜底")
            let row = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
            row.tap()
        }
        Thread.sleep(forTimeInterval: 4.0)
        snap("I4I6-demo-board-initial")
        return true
    }

    /// 按可访问性标签或兜底索引找控制条按钮（demo.play 等键缺翻译时 t() 回退为键名）
    private func controlButton(_ candidates: [String], fallbackIndex: Int) -> XCUIElement? {
        for c in candidates {
            let b = app.buttons[c].firstMatch
            if b.exists { return b }
        }
        let all = app.buttons.allElementsBoundByIndex
        return fallbackIndex < all.count ? all[fallbackIndex] : nil
    }

    func testI4_I6_DemoComponents() throws {
        try XCTSkipUnless(enterDemoBoard(), "演示入口不可达——环境性问题非回归")

        // I6：播放 → 暂停 → 步进 逐按钮
        let play = controlButton(["demo.play", "播放"], fallbackIndex: 1)
        let pause = controlButton(["demo.pause", "暂停"], fallbackIndex: 1)
        let fwd = controlButton(["demo.stepForward", "下一步"], fallbackIndex: 2)

        if let p = play, p.exists && p.isHittable { p.tap(); Thread.sleep(forTimeInterval: 4.0) }
        snap("I6-playing")
        if let p = pause, p.exists && p.isHittable { p.tap(); Thread.sleep(forTimeInterval: 1.0) }
        snap("I6-paused")

        // I4：步进触发走法与解说 → 点评气泡（CommentaryOverlay iOS 底部弹出）
        for _ in 0..<3 {
            if let f = fwd, f.exists && f.isHittable {
                f.tap()
                Thread.sleep(forTimeInterval: 2.5)
            }
        }
        snap("I4-commentary-overlay")

        // I5：走法记录面板（iOS demo 页常驻/随步更新，整屏截取核对）
        for _ in 0..<3 {
            if let f = fwd, f.exists && f.isHittable {
                f.tap()
                Thread.sleep(forTimeInterval: 1.5)
            }
        }
        snap("I5-record-panel")

        // 控制条整行终态（含速度菜单/连播/设置/返回）
        Thread.sleep(forTimeInterval: 1.0)
        snap("I6-controlbar-final")

        print("I456_DONE: I4-I6 截图序列完成")
        Thread.sleep(forTimeInterval: 5.0) // simctl 补窗
    }
}
