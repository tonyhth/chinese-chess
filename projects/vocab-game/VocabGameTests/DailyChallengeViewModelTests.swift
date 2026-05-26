import XCTest
@testable import VocabGame

/// 测试 DailyChallengeViewModel 的状态流转：loading / error / empty / completed
/// 修复背景：selected 为空时静默 return 导致 UI 永远卡在"加载中"
@MainActor
final class DailyChallengeViewModelTests: XCTestCase {

    private var wordRepo: WordRepository!
    private var progressRepo: ProgressRepository!
    private var petRepo: PetRepository!
    private var testDir: URL!
    private let testKey = "dcvm_test_\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DCVMTests-\(UUID().uuidString)")
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

    // MARK: - 正常流程：isLoading → session 创建 → isLoading → false

    func testStart_normalFlow_isLoadingTransitionsCorrectly() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo,
            progressRepo: progressRepo,
            petRepo: petRepo
        )

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNil(vm.session)

        vm.start()

        XCTAssertFalse(vm.isLoading, "start() 完成后 isLoading 应为 false")
        XCTAssertNotNil(vm.session, "应创建 GameSession")
        XCTAssertNil(vm.errorMessage, "正常流程不应有错误消息")
    }

    func testStart_createsSessionWithCorrectMode() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo,
            progressRepo: progressRepo,
            petRepo: petRepo
        )
        vm.start()

        XCTAssertEqual(vm.session?.gameMode, .dailyChallenge)
        XCTAssertFalse(vm.session!.isCompleted)
        XCTAssertEqual(vm.session!.currentIndex, 0)
        XCTAssertEqual(vm.session!.score, 0)
    }

    // MARK: - todayCompleted = true：不进入 loading，直接显示已完成

    func testStart_todayCompleted_skipsLoading() {
        progressRepo.recordDailyCompletion(score: 500)

        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo,
            progressRepo: progressRepo,
            petRepo: petRepo
        )

        // todayCompleted 在 start() 中赋值，init 后默认 false
        vm.start()

        XCTAssertTrue(vm.todayCompleted, "start() 后应读取今日完成状态")
        XCTAssertNil(vm.session, "已完成状态不应创建新 session")
        XCTAssertFalse(vm.isLoading, "已完成状态不应进入 loading")
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.todayBestScore, 500, "应保留今日最高分")
    }

    func testStart_todayCompleted_preservesBestScore() {
        progressRepo.recordDailyCompletion(score: 300)
        progressRepo.recordDailyCompletion(score: 500)

        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo,
            progressRepo: progressRepo,
            petRepo: petRepo
        )
        vm.start()
        XCTAssertEqual(vm.todayBestScore, 500)
    }

    // MARK: - selected 为空（单词不够）：isLoading → false, errorMessage 非空

    func testStart_noWordsAvailable_setsErrorMessage() {
        let emptyWordRepo = WordRepository(words: [])

        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DCVMEmpty-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = DailyChallengeViewModel(
            wordRepo: emptyWordRepo,
            progressRepo: emptyProgressRepo,
            petRepo: petRepo
        )
        vm.start()

        XCTAssertFalse(vm.isLoading, "selected 为空后 isLoading 应恢复 false")
        XCTAssertNotNil(vm.errorMessage, "应设置错误消息")
        XCTAssertFalse(vm.errorMessage!.isEmpty, "错误消息不应为空")
        XCTAssertNil(vm.session, "不应创建 session")

        try? FileManager.default.removeItem(at: emptyDir)
    }

    func testStart_noWordsAvailable_errorMessageContainsHint() {
        let emptyWordRepo = WordRepository(words: [])

        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DCVMEmpty2-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = DailyChallengeViewModel(
            wordRepo: emptyWordRepo,
            progressRepo: emptyProgressRepo,
            petRepo: petRepo
        )
        vm.start()

        XCTAssertTrue(
            vm.errorMessage?.contains("单词") == true ||
            vm.errorMessage?.contains("学习") == true,
            "错误消息应提示用户学习单词"
        )

        try? FileManager.default.removeItem(at: emptyDir)
    }

    // MARK: - 错误恢复：errorMessage 设置后能被清除

    func testErrorMessage_canBeCleared() {
        let emptyWordRepo = WordRepository(words: [])

        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DCVMClear-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = DailyChallengeViewModel(
            wordRepo: emptyWordRepo,
            progressRepo: emptyProgressRepo,
            petRepo: petRepo
        )
        vm.start()
        XCTAssertNotNil(vm.errorMessage, "应先有错误消息")

        vm.errorMessage = nil
        XCTAssertNil(vm.errorMessage, "errorMessage 应可被清除")
        XCTAssertFalse(vm.isLoading, "清除后不应处于 loading")

        try? FileManager.default.removeItem(at: emptyDir)
    }

    // MARK: - 初始状态

    func testInitialState_allDefaults() {
        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo,
            progressRepo: progressRepo,
            petRepo: petRepo
        )

        XCTAssertNil(vm.session)
        XCTAssertNil(vm.selectedAnswer)
        XCTAssertEqual(vm.spelledAnswer, "")
        XCTAssertFalse(vm.showAnswerFeedback)
        XCTAssertFalse(vm.isAnswerCorrect)
        XCTAssertFalse(vm.isShowingResult)
        XCTAssertEqual(vm.remainingSeconds, 180)
        XCTAssertFalse(vm.todayCompleted)
        XCTAssertEqual(vm.todayBestScore, 0)
        XCTAssertEqual(vm.coinsEarned, 0)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - 正确答案辅助方法

    func testCorrectAnswer_selectMeaning() {
        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        let word = Word(id: 1, text: "hello", meaning: "你好", group: 1)
        XCTAssertEqual(vm.correctAnswer(for: Question(word: word, type: .selectMeaning, options: [])), "你好")
    }

    func testCorrectAnswer_selectWord() {
        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        let word = Word(id: 1, text: "hello", meaning: "你好", group: 1)
        XCTAssertEqual(vm.correctAnswer(for: Question(word: word, type: .selectWord, options: [])), "hello")
    }

    func testCorrectAnswer_spellWord() {
        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        let word = Word(id: 1, text: "apple", meaning: "苹果", group: 1)
        XCTAssertEqual(vm.correctAnswer(for: Question(word: word, type: .spellWord, options: [])), "apple")
    }

    func testCorrectAnswer_listenAndSelect() {
        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        let word = Word(id: 1, text: "hello", meaning: "你好", group: 1)
        XCTAssertEqual(vm.correctAnswer(for: Question(word: word, type: .listenAndSelect, options: [])), "hello")
    }

    // MARK: - 边界：只有少量学习单词（不足 15 个但有 fallback）

    func testStart_fewLearnedWords_stillCreatesSession() {
        let fewWords = [
            Word(id: 101, text: "cat", meaning: "猫", group: 1),
            Word(id: 102, text: "dog", meaning: "狗", group: 1),
            Word(id: 103, text: "bird", meaning: "鸟", group: 1),
        ]
        let smallWordRepo = WordRepository(words: fewWords)

        for word in fewWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = DailyChallengeViewModel(
            wordRepo: smallWordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage, "有 fallback 单词不应报错")
        XCTAssertNotNil(vm.session, "即使单词不足 15 也应创建 session")
    }

    // MARK: - 生成 15 题（不重复）

    func testStart_creates15Questions() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = DailyChallengeViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertEqual(vm.session?.questions.count, 15, "每日挑战应生成 15 道题")
    }

    // MARK: - Helpers

    nonisolated private static let sampleWords: [Word] = (1...20).map { i in
        Word(id: i, text: "word\(i)", meaning: "meaning\(i)", group: (i - 1) / 5 + 1)
    }
}
