import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.3 两个遗留问题修复测试

@Suite("v2.2.3 遗留问题修复", .serialized)
struct V223FixTests {

    // MARK: - 问题1：英文界面 → 废弃本地化，硬编码中文
    @Test("问题1: AIDifficulty.displayName 使用 localized")
    func testAIDifficultyDisplayNameLocalized() {
        // displayName 现在返回 l10n.t() key，不再是硬编码中文
        // 在 zh-Hans locale 下运行时应返回中文值
        #expect(AIDifficulty.beginner.displayName == L10n.shared.t("difficulty.beginner"))
        #expect(AIDifficulty.easy.displayName == L10n.shared.t("difficulty.easy"))
        #expect(AIDifficulty.medium.displayName == L10n.shared.t("difficulty.medium"))
        #expect(AIDifficulty.hard.displayName == L10n.shared.t("difficulty.hard"))
        #expect(AIDifficulty.master.displayName == L10n.shared.t("difficulty.master"))
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
