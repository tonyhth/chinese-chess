import XCTest
@testable import VocabGame

final class ProgressRepositoryTests: XCTestCase {

    private var repo: ProgressRepository!
    private var testDir: URL!

    override func setUp() {
        super.setUp()
        // 使用临时目录避免污染真实数据
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VocabGameTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        repo = ProgressRepository(documentsDir: testDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        repo = nil
        super.tearDown()
    }

    // MARK: - 初始状态

    func testLoad_createsAll25Levels() {
        repo.load()
        XCTAssertEqual(repo.levelProgress.count, 25)
        for id in 1...25 {
            let lp = repo.levelProgress(for: id)
            XCTAssertFalse(lp.isCompleted)
            XCTAssertEqual(lp.stars, 0)
        }
    }

    // MARK: - 关卡解锁

    func testLevelUnlocked_level1_alwaysUnlocked() {
        repo.load()
        XCTAssertTrue(repo.isLevelUnlocked(1))
    }

    func testLevelUnlocked_level2_lockedByDefault() {
        repo.load()
        XCTAssertFalse(repo.isLevelUnlocked(2))
    }

    func testLevelUnlocked_level2_unlockedAfterCompletingLevel1() {
        repo.load()
        var lp = repo.levelProgress(for: 1)
        lp.isCompleted = true
        repo.updateLevelProgress(lp)
        XCTAssertTrue(repo.isLevelUnlocked(2))
    }

    func testLevelUnlocked_cascadeUnlock() {
        repo.load()
        // 完成关卡 1 → 解锁 2
        var lp1 = repo.levelProgress(for: 1)
        lp1.isCompleted = true
        repo.updateLevelProgress(lp1)

        // 完成关卡 2 → 解锁 3
        var lp2 = repo.levelProgress(for: 2)
        lp2.isCompleted = true
        repo.updateLevelProgress(lp2)

        XCTAssertTrue(repo.isLevelUnlocked(3))
        XCTAssertFalse(repo.isLevelUnlocked(4))
    }

    // MARK: - 单词进度

    func testWordProgress_nonexistent_returnsInitial() {
        repo.load()
        let wp = repo.wordProgress(for: 999)
        XCTAssertEqual(wp.wordId, 999)
        XCTAssertEqual(wp.mastery, .new)
    }

    func testUpdateWordProgress_persists() {
        repo.load()
        var wp = repo.wordProgress(for: 1)
        wp.mastery = .learning
        repo.updateWordProgress(wp)

        let loaded = repo.wordProgress(for: 1)
        XCTAssertEqual(loaded.mastery, .learning)
    }

    // MARK: - 错词本

    func testMistakeWords_emptyInitially() {
        repo.load()
        XCTAssertTrue(repo.mistakeWords().isEmpty)
    }

    func testMistakeWords_afterWrongAnswer() {
        repo.load()
        var wp = repo.wordProgress(for: 1)
        wp.wrongCount = 1
        repo.updateWordProgress(wp)

        let mistakes = repo.mistakeWords()
        XCTAssertEqual(mistakes.count, 1)
        XCTAssertEqual(mistakes[0].wordId, 1)
    }

    func testMistakeWords_consecutiveCorrect3_notIncluded() {
        repo.load()
        var wp = repo.wordProgress(for: 1)
        wp.wrongCount = 1
        wp.consecutiveCorrect = 3
        repo.updateWordProgress(wp)

        XCTAssertTrue(repo.mistakeWords().isEmpty, "连续答对 3 次应从错词本移除")
    }

    func testMistakeWords_consecutiveCorrect2_stillIncluded() {
        repo.load()
        var wp = repo.wordProgress(for: 1)
        wp.wrongCount = 1
        wp.consecutiveCorrect = 2
        repo.updateWordProgress(wp)

        XCTAssertEqual(repo.mistakeWords().count, 1)
    }

    // MARK: - 间隔重复

    func testWordsDueForReview_noneInitially() {
        repo.load()
        let due = repo.wordsDueForReview(now: Date())
        XCTAssertTrue(due.isEmpty)
    }

    func testWordsDueForReview_pastDue() {
        repo.load()
        var wp = repo.wordProgress(for: 1)
        wp.nextReviewDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        wp.mastery = .learning
        repo.updateWordProgress(wp)

        let due = repo.wordsDueForReview(now: Date())
        XCTAssertEqual(due.count, 1)
    }

    func testWordsDueForReview_masteredExcluded() {
        repo.load()
        var wp = repo.wordProgress(for: 1)
        wp.nextReviewDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        wp.mastery = .mastered
        repo.updateWordProgress(wp)

        let due = repo.wordsDueForReview(now: Date())
        XCTAssertTrue(due.isEmpty, "已掌握的词不应出现在复习列表")
    }

    // MARK: - 连续天数

    func testRecordPlay_firstPlay_setsStreak1() {
        repo.load()
        repo.recordPlay()
        XCTAssertEqual(repo.profile.currentStreak, 1)
        XCTAssertEqual(repo.profile.bestStreak, 1)
    }

    func testRecordPlay_sameDay_noDuplicate() {
        repo.load()
        repo.recordPlay()
        repo.recordPlay()
        XCTAssertEqual(repo.profile.currentStreak, 1)
    }

    // MARK: - 统计

    func testTotalWordsLearned() {
        repo.load()
        XCTAssertEqual(repo.totalWordsLearned, 0)

        // 标记几个词为已学
        for id in [1, 2, 3] {
            var wp = repo.wordProgress(for: id)
            wp.mastery = .learning
            repo.updateWordProgress(wp)
        }
        XCTAssertEqual(repo.totalWordsLearned, 3)
    }

    func testTotalStars() {
        repo.load()
        var lp1 = repo.levelProgress(for: 1)
        lp1.stars = 3
        repo.updateLevelProgress(lp1)

        var lp2 = repo.levelProgress(for: 2)
        lp2.stars = 2
        repo.updateLevelProgress(lp2)

        XCTAssertEqual(repo.totalStars, 5)
    }
}
