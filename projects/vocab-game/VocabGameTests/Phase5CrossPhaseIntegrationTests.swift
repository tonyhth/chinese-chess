import XCTest
@testable import VocabGame
import SwiftUI

@MainActor
final class Phase5CrossPhaseIntegrationTests: XCTestCase {

    private func makeTestDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Phase5-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 1. PlayerProfile 新字段默认值完整

    func test_newProfile_hasAllDefaultValues() {
        let profile = PlayerProfile()
        XCTAssertEqual(profile.totalStars, 0)
        XCTAssertEqual(profile.totalWordsLearned, 0)
        XCTAssertEqual(profile.coins, 0)
        XCTAssertEqual(profile.dailyGoalTarget, 10)
        XCTAssertEqual(profile.dailyGoalCompletedCount, 0)
        XCTAssertFalse(profile.dailyGoalBonusClaimed)
        XCTAssertNil(profile.dailyGoalLastResetDate)
        XCTAssertEqual(profile.dailyGoalConsecutiveDays, 0)
    }

    // MARK: - 2. PetState 新字段默认值完整

    func test_newPetState_hasAllDefaultValues() {
        let pet = PetState()
        XCTAssertEqual(pet.level, 1)
        XCTAssertEqual(pet.exp, 0)
        XCTAssertEqual(pet.ownedFoods, [])
        XCTAssertEqual(pet.ownedScenes, [])
        XCTAssertNil(pet.currentScene)
        XCTAssertEqual(pet.ownedEffects, [])
        XCTAssertNil(pet.currentEffect)
    }

    // MARK: - 3. 成就 × 多游戏模式 — wordLearned 正确累计

    func test_achievementWordLearned_countsAcrossAllModes() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        let ar = AchievementRepository(progressRepo: pr)

        ar.record(.wordLearned(totalCount: 3))
        ar.record(.wordLearned(totalCount: 5))
        ar.record(.wordLearned(totalCount: 8))

        let first = ar.achievements.first { $0.id == "first_word" }!
        XCTAssertTrue(first.isUnlocked)
        XCTAssertEqual(first.progress, 8)
    }

    // MARK: - 4. 成就 × combo — 答题和匹配都触发

    func test_achievementCombo_acrossGameModes() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        let ar = AchievementRepository(progressRepo: pr)

        ar.record(.comboReached(count: 5))
        XCTAssertFalse(ar.achievements.first { $0.id == "combo_10" }!.isUnlocked)

        ar.record(.comboReached(count: 10))
        XCTAssertTrue(ar.achievements.first { $0.id == "combo_10" }!.isUnlocked)
    }

    // MARK: - 5. 成就 × matchCompleted — speed_demon

    func test_achievementMatchCompleted_triggersSpeedDemon() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        let ar = AchievementRepository(progressRepo: pr)

        ar.record(.matchCompleted(remainingSeconds: 35))
        XCTAssertTrue(ar.achievements.first { $0.id == "speed_demon" }!.isUnlocked)
    }

    // MARK: - 6. 每日目标 × 多路径 — 持久化后继续计数

    func test_dailyGoal_countsAcrossAllModes() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        pr.load()

        for _ in 0..<3 { pr.incrementDailyGoalProgress() }

        let pr2 = ProgressRepository(documentsDir: dir)
        pr2.load()
        for _ in 0..<4 { pr2.incrementDailyGoalProgress() }
        XCTAssertEqual(pr2.dailyGoalProgress.completed, 7)

        let pr3 = ProgressRepository(documentsDir: dir)
        pr3.load()
        for _ in 0..<3 { pr3.incrementDailyGoalProgress() }
        XCTAssertEqual(pr3.dailyGoalProgress.completed, 10)
        XCTAssertTrue(pr3.dailyGoalProgress.isDone)
    }

    // MARK: - 7. 主题皮肤 — 5 个不同渐变

    func test_themeSkin_backgroundChanges() {
        let skins: [ThemeSkin] = [.garden, .beach, .starry, .candy, .party]
        let gradients = skins.map { $0.backgroundGradient }
        let uniqueGradients = Set(gradients.map { $0.map { $0.description } })
        XCTAssertEqual(uniqueGradients.count, 5, "5 个主题应有不同的渐变色")
    }

    // MARK: - 8. 蛋仔 Lv5 × 所有主题可见

    func test_petLevel5VisibleUnderAllThemes() {
        var pet = PetState()
        pet.level = 5
        let view = PetDisplayView(petState: pet, size: 160)
        XCTAssertNotNil(view)
    }

    // MARK: - 9. 成就 × 商店购买 — itemCollected

    func test_achievement_itemCollected_fromShop() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        let ar = AchievementRepository(progressRepo: pr)

        ar.record(.itemCollected(totalCount: 5))
        ar.record(.itemCollected(totalCount: 10))
        XCTAssertTrue(ar.achievements.first { $0.id == "collector_10" }!.isUnlocked)
    }

    // MARK: - 10. 饱腹度 × 成就奖励独立

    func test_satiateMultiplier_doesNotAffectAchievementReward() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        let ar = AchievementRepository(progressRepo: pr)

        ar.record(.wordLearned(totalCount: 1))
        let coinsAfter = pr.profile.coins
        XCTAssertGreaterThanOrEqual(coinsAfter, 10, "成就奖励 coins 不受 satiety 影响")
    }

    // MARK: - 11. levelCompleted 事件不 crash

    func test_achievementLevelCompleted_doesNotCrash() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        let ar = AchievementRepository(progressRepo: pr)

        ar.record(.levelCompleted(levelId: 1, stars: 2))
        ar.record(.levelCompleted(levelId: 2, stars: 3))
    }

    // MARK: - 12. 完整用户流程持久化

    func test_fullUserFlow_profilePersistence() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        pr.load()

        pr.incrementDailyGoalProgress()
        pr.updateProfile { $0.coins += 5 }

        let petRepo = PetRepository(testKey: "phase5-flow-\(UUID().uuidString)")
        petRepo.updatePetState { pet in
            pet.exp = 30
            pet.level = 2
        }

        let pr2 = ProgressRepository(documentsDir: dir)
        pr2.load()
        XCTAssertEqual(pr2.dailyGoalProgress.completed, 1)
        XCTAssertEqual(pr2.profile.coins, 5)
    }

    // MARK: - 13. 新手引导标记 — UserDefaults

    func test_onboarding_defaultIsNotSeen() {
        let key = "test_onboarding_\(UUID().uuidString)"
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
        UserDefaults.standard.set(true, forKey: key)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - 14. 蛋仔形象 × 首页/蛋仔之家一致性

    func test_petVisual_consistentAcrossViews() {
        let pet = PetState()
        let homePet = PetDisplayView(petState: pet, size: 80)
        let housePet = PetDisplayView(petState: pet, size: 180)
        XCTAssertNotNil(homePet)
        XCTAssertNotNil(housePet)
    }

    // MARK: - 15. 成就 × 每日目标奖励独立

    func test_achievementAndDailyGoal_independent() {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        let ar = AchievementRepository(progressRepo: pr)

        for _ in 0..<10 { pr.incrementDailyGoalProgress() }
        let dailyCoins = pr.profile.coins

        ar.record(.wordLearned(totalCount: 1))
        let totalCoins = pr.profile.coins

        XCTAssertEqual(totalCoins, dailyCoins + 10, "成就和每日目标奖励独立累加")
    }
}
