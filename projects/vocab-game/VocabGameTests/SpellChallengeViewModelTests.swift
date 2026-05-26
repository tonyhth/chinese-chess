import XCTest
@testable import VocabGame

/// 测试 SpellChallengeViewModel 的状态流转：loading → ready → playing → completed
/// 重点覆盖 loading/error/empty 三种边界状态（防止同类 bug）
@MainActor
final class SpellChallengeViewModelTests: XCTestCase {

    private var wordRepo: WordRepository!
    private var progressRepo: ProgressRepository!
    private var petRepo: PetRepository!
    private var testDir: URL!
    private let testKey = "scvm_test_\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SCVMTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        progressRepo = ProgressRepository(documentsDir: testDir)
        progressRepo.load()
        petRepo = PetRepository(testKey: testKey)

        wordRepo = WordRepository(words: Self.sampleWords)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialState_allDefaults() {
        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )

        XCTAssertTrue(vm.words.isEmpty)
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertEqual(vm.spelledAnswer, "")
        XCTAssertFalse(vm.showFeedback)
        XCTAssertFalse(vm.isCorrect)
        XCTAssertEqual(vm.score, 0)
        XCTAssertEqual(vm.combo, 0)
        XCTAssertEqual(vm.maxCombo, 0)
        XCTAssertFalse(vm.isCompleted)
        XCTAssertFalse(vm.hintUsed)
        XCTAssertFalse(vm.streakTitle)
        XCTAssertNil(vm.currentWord)
        XCTAssertEqual(vm.progress, 0)
    }

    // MARK: - 正常流程

    func testStart_normalFlow_populatesWords() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertFalse(vm.words.isEmpty, "start() 后应有单词")
        XCTAssertLessThanOrEqual(vm.words.count, 15, "最多 15 个单词")
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertFalse(vm.isCompleted)
        XCTAssertNotNil(vm.currentWord, "第一个单词应可访问")
        XCTAssertGreaterThanOrEqual(vm.progress, 0)
    }

    // MARK: - empty 状态：没有学习单词但有 fallback

    func testStart_noLearnedWords_usesFallback() {
        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertFalse(vm.words.isEmpty, "fallback 后应有单词")
        XCTAssertLessThanOrEqual(vm.words.count, 10, "fallback 最多 10 个")
        XCTAssertNotNil(vm.currentWord)
    }

    func testStart_emptyWordRepo_stillWorks() {
        let emptyWordRepo = WordRepository(words: [])

        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SCVMEmpty-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = SpellChallengeViewModel(
            wordRepo: emptyWordRepo, progressRepo: emptyProgressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertTrue(vm.words.isEmpty, "完全无单词时 words 应为空")
        XCTAssertNil(vm.currentWord)
        XCTAssertEqual(vm.progress, 0)

        try? FileManager.default.removeItem(at: emptyDir)
    }

    // MARK: - 空数据 errorMessage

    func testStart_emptyWordRepo_setsErrorMessage() {
        let emptyWordRepo = WordRepository(words: [])

        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SCVMErrMsg-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = SpellChallengeViewModel(
            wordRepo: emptyWordRepo, progressRepo: emptyProgressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertEqual(vm.errorMessage, "暂无题目数据", "完全无单词时应设置 errorMessage")
        XCTAssertNil(vm.currentWord)

        try? FileManager.default.removeItem(at: emptyDir)
    }

    func testStart_hasWords_noErrorMessage() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertNil(vm.errorMessage, "有单词时不应设置 errorMessage")
        XCTAssertFalse(vm.words.isEmpty)
        XCTAssertNotNil(vm.currentWord)
    }

    func testStart_emptyWordRepo_fallbackAlsoEmpty_setsErrorMessage() {
        // 0 learned words + 0 unlocked levels → fallback (allWords) is also empty
        let emptyWordRepo = WordRepository(words: [])
        let vm = SpellChallengeViewModel(
            wordRepo: emptyWordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertEqual(vm.errorMessage, "暂无题目数据")
    }

    // MARK: - completed 状态流转

    func testStart_resetsStateForNewGame() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        vm.isCompleted = true
        vm.score = 999
        vm.combo = 10
        vm.maxCombo = 10

        vm.start()

        XCTAssertFalse(vm.isCompleted, "重新 start 后 isCompleted 应重置")
        XCTAssertEqual(vm.score, 0, "分数应重置")
        XCTAssertEqual(vm.combo, 0)
        XCTAssertEqual(vm.maxCombo, 0)
    }

    // MARK: - playing 状态：submit 和 combo

    func testSubmit_correctAnswer_incrementsScoreAndCombo() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        guard let firstWord = vm.currentWord else {
            XCTFail("应有当前单词"); return
        }

        vm.spelledAnswer = firstWord.text
        vm.submit()

        XCTAssertTrue(vm.isCorrect)
        XCTAssertTrue(vm.showFeedback)
        XCTAssertGreaterThan(vm.score, 0)
        XCTAssertGreaterThanOrEqual(vm.combo, 1)
    }

    // MARK: - hint 功能

    func testHintDisplay_withoutHint() {
        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        XCTAssertEqual(vm.hintDisplay, "")

        vm.words = [Word(id: 1, text: "hello", meaning: "你好", group: 1)]
        XCTAssertEqual(vm.hintDisplay, "(5个字母)")
    }

    func testHintDisplay_afterHintUsed() {
        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.words = [Word(id: 1, text: "apple", meaning: "苹果", group: 1)]
        vm.hintUsed = true

        XCTAssertTrue(vm.hintDisplay.contains("A") || vm.hintDisplay.contains("a"))
        XCTAssertTrue(vm.hintDisplay.contains("5"))
    }

    func testUseHint_insufficientCoins_returnsFalse() {
        progressRepo.updateProfile { $0.coins = 0 }

        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.words = Self.sampleWords
        vm.hintUsed = false

        XCTAssertFalse(vm.useHint(), "金币不足时 useHint 应返回 false")
        XCTAssertFalse(vm.hintUsed)
    }

    func testUseHint_alreadyUsed_returnsFalse() {
        progressRepo.updateProfile { $0.coins = 100 }

        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.words = Self.sampleWords
        vm.hintUsed = true

        XCTAssertFalse(vm.useHint(), "已使用 hint 后再次调用应返回 false")
    }

    func testUseHint_sufficientCoins_returnsTrue() {
        progressRepo.updateProfile { $0.coins = 100 }

        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.words = Self.sampleWords
        vm.hintUsed = false

        XCTAssertTrue(vm.useHint(), "金币足够时 useHint 应返回 true")
        XCTAssertTrue(vm.hintUsed)
        XCTAssertEqual(progressRepo.profile.coins, 90, "应扣除 10 金币")
    }

    // MARK: - progress 计算

    func testProgress_emptyWords_returnsZero() {
        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        XCTAssertEqual(vm.progress, 0)
    }

    func testProgress_halfway() {
        let vm = SpellChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.words = Self.sampleWords
        vm.currentIndex = 10
        XCTAssertEqual(vm.progress, 0.5, accuracy: 0.01)
    }

    // MARK: - ⚠️ 发现的潜在问题

    func testStart_completelyEmpty_noErrorState() {
        let emptyWordRepo = WordRepository(words: [])

        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SCVMNoError-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = SpellChallengeViewModel(
            wordRepo: emptyWordRepo, progressRepo: emptyProgressRepo, petRepo: petRepo
        )
        vm.start()

        // ✅ 修复后：完全无单词时 errorMessage 被设置
        XCTAssertTrue(vm.words.isEmpty)
        XCTAssertEqual(vm.errorMessage, "暂无题目数据")

        try? FileManager.default.removeItem(at: emptyDir)
    }

    // MARK: - Helpers

    nonisolated private static let sampleWords: [Word] = (1...20).map { i in
        Word(id: i, text: "word\(i)", meaning: "meaning\(i)", group: (i - 1) / 5 + 1)
    }
}
