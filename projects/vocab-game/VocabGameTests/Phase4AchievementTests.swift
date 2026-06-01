import XCTest
@testable import VocabGame
import SwiftUI

@MainActor
final class Phase4AchievementTests: XCTestCase {

    private func makeTestDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Phase4Ach-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeRepos() -> (ProgressRepository, AchievementRepository) {
        let dir = makeTestDir()
        let pr = ProgressRepository(documentsDir: dir)
        let ar = AchievementRepository(progressRepo: pr)
        return (pr, ar)
    }

    // MARK: - 1. 成就目录完整性

    func testAchievementCatalog_countIs7() {
        XCTAssertEqual(Achievement.catalog.count, 7)
    }

    func testAchievementCatalog_ids() {
        let ids = Set(Achievement.catalog.map { $0.id })
        let expected: Set<String> = [
            "first_word", "word_master_50", "streak_7",
            "combo_10", "pet_max", "collector_10", "speed_demon"
        ]
        XCTAssertEqual(ids, expected)
    }

    func testAchievementCatalog_categories() {
        let categories = Set(Achievement.catalog.map { $0.category })
        let expected: Set<AchievementCategory> = [.learning, .streak, .combo, .pet, .game, .collection]
        XCTAssertEqual(categories, expected)
    }

    func testAchievementCatalog_allHavePositiveReward() {
        for a in Achievement.catalog {
            XCTAssertGreaterThan(a.reward, 0, "\(a.id) reward should be positive")
        }
    }

    // MARK: - 2. wordLearned → first_word 解锁

    func test_wordLearned_1_word_unlocks_first_word() {
        let (pr, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 1))
        let first = ar.achievements.first { $0.id == "first_word" }!
        XCTAssertTrue(first.isUnlocked)
        XCTAssertEqual(first.progress, 1)
        XCTAssertNotNil(first.unlockedAt)
    }

    func test_wordLearned_0_words_doesNotUnlock() {
        let (_, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 0))
        let first = ar.achievements.first { $0.id == "first_word" }!
        XCTAssertFalse(first.isUnlocked)
    }

    func test_wordLearned_grants_10_coins() {
        let (pr, ar) = makeRepos()
        let before = pr.profile.coins
        ar.record(.wordLearned(totalCount: 1))
        let after = pr.profile.coins
        XCTAssertEqual(after - before, 10, "first_word reward = 10 coins")
    }

    // MARK: - 3. wordLearned → word_master_50

    func test_wordLearned_50_words_unlocks_word_master() {
        let (_, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 50))
        let master = ar.achievements.first { $0.id == "word_master_50" }!
        XCTAssertTrue(master.isUnlocked)
        XCTAssertEqual(master.progress, 50)
    }

    func test_wordLearned_49_words_doesNotUnlock_word_master() {
        let (_, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 49))
        let master = ar.achievements.first { $0.id == "word_master_50" }!
        XCTAssertFalse(master.isUnlocked)
        XCTAssertEqual(master.progress, 49)
    }

    // MARK: - 4. streakDay → streak_7

    func test_streakDay_7_unlocks_streak_7() {
        let (_, ar) = makeRepos()
        ar.record(.streakDay(count: 7))
        let streak = ar.achievements.first { $0.id == "streak_7" }!
        XCTAssertTrue(streak.isUnlocked)
    }

    func test_streakDay_6_doesNotUnlock() {
        let (_, ar) = makeRepos()
        ar.record(.streakDay(count: 6))
        let streak = ar.achievements.first { $0.id == "streak_7" }!
        XCTAssertFalse(streak.isUnlocked)
    }

    // MARK: - 5. comboReached → combo_10

    func test_comboReached_10_unlocks_combo_10() {
        let (_, ar) = makeRepos()
        ar.record(.comboReached(count: 10))
        let combo = ar.achievements.first { $0.id == "combo_10" }!
        XCTAssertTrue(combo.isUnlocked)
    }

    func test_comboReached_9_doesNotUnlock() {
        let (_, ar) = makeRepos()
        ar.record(.comboReached(count: 9))
        let combo = ar.achievements.first { $0.id == "combo_10" }!
        XCTAssertFalse(combo.isUnlocked)
    }

    // MARK: - 6. petLevelUp → pet_max

    func test_petLevelUp_5_unlocks_pet_max() {
        let (_, ar) = makeRepos()
        ar.record(.petLevelUp(level: 5))
        let pet = ar.achievements.first { $0.id == "pet_max" }!
        XCTAssertTrue(pet.isUnlocked)
    }

    func test_petLevelUp_4_doesNotUnlock() {
        let (_, ar) = makeRepos()
        ar.record(.petLevelUp(level: 4))
        let pet = ar.achievements.first { $0.id == "pet_max" }!
        XCTAssertFalse(pet.isUnlocked)
    }

    // MARK: - 7. itemCollected → collector_10

    func test_itemCollected_10_unlocks_collector() {
        let (_, ar) = makeRepos()
        ar.record(.itemCollected(totalCount: 10))
        let col = ar.achievements.first { $0.id == "collector_10" }!
        XCTAssertTrue(col.isUnlocked)
    }

    func test_itemCollected_9_doesNotUnlock() {
        let (_, ar) = makeRepos()
        ar.record(.itemCollected(totalCount: 9))
        let col = ar.achievements.first { $0.id == "collector_10" }!
        XCTAssertFalse(col.isUnlocked)
    }

    // MARK: - 8. matchCompleted → speed_demon

    func test_matchCompleted_30sRemaining_unlocks() {
        let (_, ar) = makeRepos()
        ar.record(.matchCompleted(remainingSeconds: 30))
        let speed = ar.achievements.first { $0.id == "speed_demon" }!
        XCTAssertTrue(speed.isUnlocked)
    }

    func test_matchCompleted_29sRemaining_doesNotUnlock() {
        let (_, ar) = makeRepos()
        ar.record(.matchCompleted(remainingSeconds: 29))
        let speed = ar.achievements.first { $0.id == "speed_demon" }!
        XCTAssertFalse(speed.isUnlocked)
    }

    // MARK: - 9. 重复解锁不发双倍奖励

    func test_doubleRecord_doesNotDoubleReward() {
        let (pr, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 1))
        let coinsAfterFirst = pr.profile.coins
        ar.record(.wordLearned(totalCount: 2))
        let coinsAfterSecond = pr.profile.coins
        XCTAssertEqual(coinsAfterFirst, coinsAfterSecond, "已解锁成就不应重复发奖")
    }

    // MARK: - 10. newlyUnlocked 弹出

    func test_unlock_setsNewlyUnlocked_afterDelay() async {
        let (_, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 1))
        // newlyUnlocked is set in a Task, wait briefly
        try? await Task.sleep(for: .seconds(0.1))
        XCTAssertNotNil(ar.newlyUnlocked)
        XCTAssertEqual(ar.newlyUnlocked?.id, "first_word")
    }

    // MARK: - 11. 成就持久化

    func test_achievementPersistsAcrossReload() {
        let (pr, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 1))
        ar.record(.streakDay(count: 7))

        let newRepo = AchievementRepository(progressRepo: pr)
        newRepo.load()

        let first = newRepo.achievements.first { $0.id == "first_word" }!
        XCTAssertTrue(first.isUnlocked)

        let streak = newRepo.achievements.first { $0.id == "streak_7" }!
        XCTAssertTrue(streak.isUnlocked)
    }

    // MARK: - 12. 成就墙 — 已解锁 vs 未解锁

    func test_achievementWall_unlockedCount() {
        let (_, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 50))
        ar.record(.comboReached(count: 10))
        // wordLearned(50) also triggers first_word (50 >= 1) → 3 unlocked
        let unlocked = ar.achievements.filter { $0.isUnlocked }
        XCTAssertEqual(unlocked.count, 3)
    }

    func test_achievementWall_lockedItems_progressVisible() {
        let (_, ar) = makeRepos()
        ar.record(.wordLearned(totalCount: 30))
        let master = ar.achievements.first { $0.id == "word_master_50" }!
        XCTAssertFalse(master.isUnlocked)
        XCTAssertEqual(master.progress, 30, "进度应更新但未解锁")
    }
}
