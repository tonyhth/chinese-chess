import Foundation
import Testing
@testable import ChineseChess

@Suite("v3.6.0 Full 7-Item Tests", .serialized)
struct V360FullTests {

    // MARK: - 1. Phase 3.4 教练难度调节

    @Test("recommendedCoachDifficulty: 学童 → easy")
    func coachDifficultyStudent() {
        #expect(Rank.student.recommendedCoachDifficulty == .easy)
    }

    @Test("recommendedCoachDifficulty: 秀才 → medium")
    func coachDifficultyScholar() {
        #expect(Rank.scholar.recommendedCoachDifficulty == .medium)
    }

    @Test("recommendedCoachDifficulty: 举人 → hard")
    func coachDifficultyJuren() {
        #expect(Rank.juren.recommendedCoachDifficulty == .hard)
    }

    @Test("recommendedCoachDifficulty: 进士 → hard")
    func coachDifficultyJinshi() {
        #expect(Rank.jinshi.recommendedCoachDifficulty == .hard)
    }

    @Test("recommendedCoachDifficulty: 翰林 → master")
    func coachDifficultyHanlin() {
        #expect(Rank.hanlin.recommendedCoachDifficulty == .master)
    }

    @Test("recommendedCoachDifficulty: 国手 → master")
    func coachDifficultyMaster() {
        #expect(Rank.master.recommendedCoachDifficulty == .master)
    }

    @Test("recommendedCoachDifficulty: 棋圣 → master")
    func coachDifficultySage() {
        #expect(Rank.sage.recommendedCoachDifficulty == .master)
    }

    // MARK: - 2. Q2 段位升级奖励展示

    @Test("UnlockedFeature 有 iconName 和 localizedName")
    func unlockedFeatureProperties() {
        for feature in UnlockedFeature.allCases {
            #expect(!feature.iconName.isEmpty)
            #expect(!feature.localizedName.isEmpty)
        }
    }

    @Test("RankUpView 可创建")
    func rankUpViewExists() {
        let _ = RankUpView(newRank: .scholar, onDismiss: {})
    }

    @Test("BoardTheme 有 previewColor")
    func boardThemePreviewColor() {
        for theme in BoardTheme.allCases {
            let _ = theme.previewColor
        }
    }

    // MARK: - 3. Q3 continuous_check 成就

    @Test("continuous_check 成就存在于成就库")
    func continuousCheckExists() {
        let achievement = AchievementLibrary.find(id: "continuous_check")
        #expect(achievement != nil)
        #expect(achievement?.rarity == .silver)
    }

    @Test("continuous_check: maxConsecutiveChecks >= 3 → 解锁")
    func continuousCheckUnlock() {
        let result = GameResultInfo(
            isWin: true,
            difficulty: .medium,
            moveCount: 20,
            playerMoveCount: 10,
            elapsedSeconds: 120,
            usedHint: false,
            checkmatePattern: nil,
            maxMaterialDeficit: 0,
            maxConsecutiveChecks: 3
        )
        let unlocked = AchievementChecker.checkAfterGame(
            result: result, profile: PlayerProfile()
        )
        #expect(unlocked.contains("continuous_check"))
    }

    @Test("continuous_check: maxConsecutiveChecks < 3 → 不解锁")
    func continuousCheckNotUnlock() {
        let result = GameResultInfo(
            isWin: true,
            difficulty: .medium,
            moveCount: 20,
            playerMoveCount: 10,
            elapsedSeconds: 120,
            usedHint: false,
            checkmatePattern: nil,
            maxMaterialDeficit: 0,
            maxConsecutiveChecks: 2
        )
        let unlocked = AchievementChecker.checkAfterGame(
            result: result, profile: PlayerProfile()
        )
        #expect(!unlocked.contains("continuous_check"))
    }

    @Test("continuous_check: 输棋不解锁")
    func continuousCheckLoseNoUnlock() {
        let result = GameResultInfo(
            isWin: false,
            difficulty: .medium,
            moveCount: 20,
            playerMoveCount: 10,
            elapsedSeconds: 120,
            usedHint: false,
            checkmatePattern: nil,
            maxMaterialDeficit: 0,
            maxConsecutiveChecks: 5
        )
        let unlocked = AchievementChecker.checkAfterGame(
            result: result, profile: PlayerProfile()
        )
        #expect(!unlocked.contains("continuous_check"))
    }

    // MARK: - 4. 模式切换入口更显眼（P0）

    @Test("PuzzleSelectView 可创建")
    func puzzleSelectViewExists() {
        let _ = PuzzleSelectView()
    }

    // MARK: - 5. MaterialTracker 集成

    @Test("MaterialTracker: 初始 deficit 为 0")
    func materialTrackerInitial() {
        let tracker = MaterialTracker()
        #expect(tracker.maxDeficit == 0)
    }

    @Test("comeback_king: 兵力劣势 500+ 翻盘 → 解锁")
    func comebackKingUnlock() {
        let result = GameResultInfo(
            isWin: true,
            difficulty: .medium,
            moveCount: 40,
            playerMoveCount: 20,
            elapsedSeconds: 300,
            usedHint: false,
            checkmatePattern: nil,
            maxMaterialDeficit: -5,
            maxConsecutiveChecks: 0
        )
        let unlocked = AchievementChecker.checkAfterGame(
            result: result, profile: PlayerProfile()
        )
        #expect(unlocked.contains("comeback_king"))
    }

    @Test("comeback_king: 兵力劣势不足 → 不解锁")
    func comebackKingNotEnough() {
        let result = GameResultInfo(
            isWin: true,
            difficulty: .medium,
            moveCount: 40,
            playerMoveCount: 20,
            elapsedSeconds: 300,
            usedHint: false,
            checkmatePattern: nil,
            maxMaterialDeficit: -4,
            maxConsecutiveChecks: 0
        )
        let unlocked = AchievementChecker.checkAfterGame(
            result: result, profile: PlayerProfile()
        )
        #expect(!unlocked.contains("comeback_king"))
    }

    @Test("comeback_king: 输棋不解锁")
    func comebackKingLoseNoUnlock() {
        let result = GameResultInfo(
            isWin: false,
            difficulty: .medium,
            moveCount: 40,
            playerMoveCount: 20,
            elapsedSeconds: 300,
            usedHint: false,
            checkmatePattern: nil,
            maxMaterialDeficit: -10,
            maxConsecutiveChecks: 0
        )
        let unlocked = AchievementChecker.checkAfterGame(
            result: result, profile: PlayerProfile()
        )
        #expect(!unlocked.contains("comeback_king"))
    }

    // MARK: - 6. perfect_game_v2 available 保护

    @Test("perfect_game_v2 成就 available=false")
    func perfectGameV2NotAvailable() {
        let achievement = AchievementLibrary.find(id: "perfect_game_v2")
        #expect(achievement != nil)
        #expect(achievement?.available == false)
    }

    @Test("available=false 的成就 unlock 返回 false")
    func unavailableAchievementCannotUnlock() {
        let result = AchievementManager.shared.unlock("perfect_game_v2")
        #expect(result == false)
    }

    @Test("normal 成就 available=true")
    func normalAchievementAvailable() {
        let achievement = AchievementLibrary.find(id: "first_win")
        #expect(achievement?.available == true)
    }

    // MARK: - 7. 棋盘尺寸稳定性

    @Test("AIDifficulty 有所有枚举值")
    func aiDifficultyCases() {
        let cases = AIDifficulty.allCases
        #expect(cases.contains(.beginner))
        #expect(cases.contains(.easy))
        #expect(cases.contains(.medium))
        #expect(cases.contains(.hard))
        #expect(cases.contains(.master))
    }
}
