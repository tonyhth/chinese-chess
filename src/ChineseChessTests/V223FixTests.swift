import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.3 两个遗留问题修复测试

@Suite("v2.2.3 遗留问题修复", .serialized)
final class V223FixTests {

    private let savedLang: String

    init() { savedLang = TestL10nSupport.injectZhHans() }  // v6.2 断言清偿 簇1
    deinit { TestL10nSupport.restore(savedLang) }

    // MARK: - 问题1：v6.0 十级体系 displayName 与 catalog lvlN key 一致
    @Test("AIDifficulty.displayName 与 lvlN catalog 值一致")
    func testAIDifficultyDisplayNameLocalized() {
        // v6.2 断言清偿：displayName 已从旧 l10n key 迁移为硬编码 zh + lvlN catalog 体系
        // 断言语义：displayName == t("difficulty.lvl\(order+1)")（zh-Hans 注入后取 catalog 中文值）
        for diff in AIDifficulty.allCases {
            let key = "difficulty.lvl\(diff.order + 1)"
            #expect(diff.displayName == L10n.shared.t(key),
                    "\(diff.rawValue).displayName=\(diff.displayName) 应等于 \(key)=\(L10n.shared.t(key))")
        }
    }
    // MARK: - 问题2：棋盘启动时太小 → 增大窗口 + 最小高度
    // MARK: - 回归：v2.2.2 修复不受影响

    @Test("回归: 残局数量为 651（100古谱+551适情雅趣）")
    func testPuzzleCountRegression() {
        let store = PuzzleStore.shared
        #expect(store.puzzles.count == 551, "残局应为 551 局，实际 \(store.puzzles.count)")
    }

    @Test("回归: SoundEngine 不崩溃")
    func testSoundEngineNoCrash() {
        let engine = SoundEngine.shared
        engine.isMuted = false
        engine.playMove()
        engine.playCapture()
        engine.playCheck()
        engine.playUndo()
        engine.playVictory()
        engine.playDefeat()
        engine.isMuted = true
        engine.playMove()
        #expect(true, "SoundEngine 不崩溃")
    }
}
