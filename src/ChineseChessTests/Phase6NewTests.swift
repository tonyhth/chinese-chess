import Testing
import Foundation
@testable import ChineseChess

@Suite("Phase 6 段位系统 + 成就系统测试")
struct Phase6Tests {

    // MARK: - 段位系统测试

    @Test("段位排序正确")
    func rankOrdering() {
        #expect(Rank.student < Rank.scholar)
        #expect(Rank.scholar < Rank.juren)
        #expect(Rank.juren < Rank.jinshi)
        #expect(Rank.jinshi < Rank.hanlin)
        #expect(Rank.hanlin < Rank.master)
        #expect(Rank.master < Rank.sage)
    }

    @Test("段位升级条件")
    func rankRequirements() {
        #expect(Rank.student.requiredWins == 0)
        #expect(Rank.scholar.requiredWins == 5)
        #expect(Rank.juren.requiredWins == 15)
        #expect(Rank.jinshi.requiredWins == 30)
        #expect(Rank.jinshi.requiredPuzzles == 5)
        #expect(Rank.sage.requiredWins == 200)
        #expect(Rank.sage.requiredPuzzles == 40)
    }

    @Test("段位 next 链")
    func rankNext() {
        #expect(Rank.student.next == .scholar)
        #expect(Rank.scholar.next == .juren)
        #expect(Rank.sage.next == nil, "棋圣无下一段位")
    }

    @Test("段位图标")
    func rankIcons() {
        for rank in Rank.allCases {
            #expect(!rank.icon.isEmpty, "\(rank.rawValue) 应有图标")
        }
    }

    // MARK: - 玩家档案测试

    @Test("新玩家档案默认值")
    func newPlayerProfile() {
        let profile = PlayerProfile()
        #expect(profile.rank == .student)
        #expect(profile.totalWins == 0)
        #expect(profile.totalGames == 0)
        #expect(profile.unlockedAchievements.isEmpty)
    }

    @Test("升级检查：满足条件返回新段位")
    func checkRankUp() {
        var profile = PlayerProfile()
        profile.totalWins = 5
        #expect(profile.checkRankUp() == .scholar)

        profile.totalWins = 15
        #expect(profile.checkRankUp() == .juren)

        profile.totalWins = 30
        profile.puzzlesCompleted = 5
        #expect(profile.checkRankUp() == .jinshi)
    }

    @Test("升级检查：不满足条件返回 nil")
    func checkRankUpNotMet() {
        var profile = PlayerProfile()
        profile.totalWins = 4
        #expect(profile.checkRankUp() == nil)

        profile.totalWins = 30
        profile.puzzlesCompleted = 4  // 少一个残局
        #expect(profile.checkRankUp()?.order ?? 0 < Rank.jinshi.order)
    }

    @Test("累计制不降级")
    func noRankDown() {
        var profile = PlayerProfile()
        profile.rank = .juren
        profile.totalWins = 0  // 即使胜场不足
        #expect(profile.checkRankUp() == nil, "不应降级")
        #expect(profile.rank == .juren)
    }

    @Test("段位进度计算")
    func rankProgress() {
        var profile = PlayerProfile()
        // 学童 → 秀才：需 5 胜
        profile.totalWins = 3
        #expect(profile.rankProgress > 0.5)
        #expect(profile.rankProgress < 1.0)

        profile.totalWins = 5
        #expect(profile.rankProgress >= 0.99)
    }

    // MARK: - 档案存储测试

    @Test("存储和读取档案")
    func storeAndLoad() {
        let suite = UserDefaults(suiteName: "test_store_\(UUID().uuidString)")!
        let store = PlayerProfileStore(defaults: suite)
        var profile = PlayerProfile()
        profile.totalWins = 10
        store.save(profile)

        let loaded = store.profile
        #expect(loaded.totalWins == 10)
    }

    @Test("update 方法原子更新")
    func updateTransform() {
        let suite = UserDefaults(suiteName: "test_update_\(UUID().uuidString)")!
        let store = PlayerProfileStore(defaults: suite)
        let updated = store.update { profile in
            profile.totalWins += 1
        }
        #expect(updated.totalWins == 1)
        suite.removePersistentDomain(forName: suite.dictionaryRepresentation().keys.first ?? "")
    }

    // MARK: - 成就系统测试

    @Test("成就库包含 35 个成就")
    func achievementCount() {
        #expect(AchievementLibrary.all.count == 35, "应有 35 个成就")
        #expect(AchievementLibrary.bronze.count == 8)
        #expect(AchievementLibrary.silver.count == 9)
        #expect(AchievementLibrary.gold.count == 7)
        #expect(AchievementLibrary.diamond.count == 5)
        #expect(AchievementLibrary.hidden.count == 6)
    }

    @Test("成就 ID 唯一")
    func achievementIdsUnique() {
        let ids = AchievementLibrary.all.map { $0.id }
        #expect(Set(ids).count == ids.count, "所有成就 ID 应唯一")
    }

    @Test("成就解锁")
    func unlockAchievement() {
        let suite = UserDefaults(suiteName: "test_unlock_\(UUID().uuidString)")!
        let store = PlayerProfileStore(defaults: suite)
        let manager = AchievementManager(store: store)
        let result = manager.unlock("first_win")
        #expect(result == true, "首次解锁应返回 true")
        #expect(store.profile.unlockedAchievements.contains("first_win"))
    }

    @Test("重复解锁返回 false")
    func duplicateUnlock() {
        let suite = UserDefaults(suiteName: "test_dup_\(UUID().uuidString)")!
        let store = PlayerProfileStore(defaults: suite)
        let manager = AchievementManager(store: store)
        _ = manager.unlock("first_win")
        let result = manager.unlock("first_win")
        #expect(result == false, "重复解锁应返回 false")
    }

    @Test("批量检查解锁：首局")
    func checkFirstGame() {
        let suite = UserDefaults(suiteName: "test_first_\(UUID().uuidString)")!
        let store = PlayerProfileStore(defaults: suite)
        let manager = AchievementManager(store: store)
        var profile = store.profile
        profile.totalWins = 1
        let newIds = manager.checkAndUnlock(profile: profile)
        #expect(newIds.contains("first_game"), "首局应解锁")
    }

    @Test("批量检查解锁：教程完成")
    func checkTutorialDone() {
        let suite = UserDefaults(suiteName: "test_tut_\(UUID().uuidString)")!
        let store = PlayerProfileStore(defaults: suite)
        let manager = AchievementManager(store: store)
        var profile = store.profile
        profile.completedTutorials = true
        let newIds = manager.checkAndUnlock(profile: profile)
        #expect(newIds.contains("tutorial_done"), "教程完成应解锁")
    }

    @Test("隐藏成就描述在未解锁时隐藏")
    func hiddenAchievementDescription() {
        let hidden = AchievementLibrary.hidden[0]
        #expect(hidden.displayName == "?????")
        #expect(hidden.displayDescription == "?????")
    }

    @Test("非隐藏成就描述正常显示")
    func visibleAchievementDescription() {
        let bronze = AchievementLibrary.bronze[0]
        #expect(bronze.displayName == L10n.shared.t(bronze.nameKey))
        #expect(bronze.displayDescription == L10n.shared.t(bronze.descriptionKey))
    }

    // MARK: - Phase 5 联动

    @Test("教程完成触发成就和档案更新")
    func tutorialCompletionTriggers() {
        let suite = UserDefaults(suiteName: "test_tut_trigger_\(UUID().uuidString)")!
        let store = PlayerProfileStore(defaults: suite)

        store.update { profile in
            profile.completedTutorials = true
        }
        AchievementManager(store: store).unlock("tutorial_done")

        let profile = store.profile
        #expect(profile.completedTutorials == true)
        #expect(profile.unlockedAchievements.contains("tutorial_done"))
    }

    // MARK: - 集成验证

    @Test("完整段位升级流程")
    func fullRankProgression() {
        var profile = PlayerProfile()
        #expect(profile.rank == .student)

        profile.totalWins = 5
        if let newRank = profile.checkRankUp() { profile.rank = newRank }
        #expect(profile.rank == .scholar)

        profile.totalWins = 15
        if let newRank = profile.checkRankUp() { profile.rank = newRank }
        #expect(profile.rank == .juren)

        profile.totalWins = 30
        profile.puzzlesCompleted = 5
        if let newRank = profile.checkRankUp() { profile.rank = newRank }
        #expect(profile.rank == .jinshi)
    }
}
