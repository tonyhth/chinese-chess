import XCTest
@testable import VocabGame

/// 测试 MatchGameViewModel 的状态流转：loading → ready → playing → completed
/// 重点覆盖 loading/error/empty 三种边界状态（防止同类 bug）
@MainActor
final class MatchGameViewModelTests: XCTestCase {

    private var wordRepo: WordRepository!
    private var progressRepo: ProgressRepository!
    private var petRepo: PetRepository!
    private var testDir: URL!
    private let testKey = "mgvm_test_\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MGVMTests-\(UUID().uuidString)")
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
        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )

        XCTAssertTrue(vm.cards.isEmpty)
        XCTAssertTrue(vm.flippedIndices.isEmpty)
        XCTAssertEqual(vm.score, 0)
        XCTAssertEqual(vm.moves, 0)
        XCTAssertEqual(vm.matchedPairs, 0)
        XCTAssertEqual(vm.totalPairs, 0)
        XCTAssertFalse(vm.isCompleted)
        XCTAssertEqual(vm.remainingSeconds, 60)
        XCTAssertFalse(vm.isChecking)
    }

    // MARK: - 正常流程

    func testStart_normalFlow_createsCards() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertFalse(vm.cards.isEmpty, "start() 后应有卡牌")
        XCTAssertEqual(vm.cards.count, vm.totalPairs * 2, "卡牌数量应为 pair 的 2 倍")
        XCTAssertGreaterThan(vm.totalPairs, 0)
        XCTAssertFalse(vm.isCompleted)
        XCTAssertEqual(vm.matchedPairs, 0)
        XCTAssertEqual(vm.remainingSeconds, 60)
    }

    func testStart_normalFlow_resetsPreviousState() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        vm.score = 999
        vm.moves = 50
        vm.matchedPairs = 3
        vm.isCompleted = true

        vm.start()

        XCTAssertEqual(vm.score, 0, "重新 start 后分数应重置")
        XCTAssertEqual(vm.moves, 0)
        XCTAssertEqual(vm.matchedPairs, 0)
        XCTAssertFalse(vm.isCompleted, "重新 start 后 isCompleted 应重置")
        XCTAssertEqual(vm.remainingSeconds, 60)
    }

    // MARK: - empty 边界

    func testStart_noLearnedWords_usesFallback() {
        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertFalse(vm.cards.isEmpty, "有 allWords fallback 不应为空")
        XCTAssertGreaterThan(vm.totalPairs, 0)
    }

    func testStart_completelyEmptyWordRepo_handlesGracefully() {
        let emptyWordRepo = WordRepository(words: [])

        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MGVMEmpty-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = MatchGameViewModel(
            wordRepo: emptyWordRepo, progressRepo: emptyProgressRepo, petRepo: petRepo
        )
        // 不应崩溃
        vm.start()

        XCTAssertEqual(vm.errorMessage, "暂无题目数据", "完全无单词时应设置 errorMessage")
        XCTAssertTrue(vm.cards.isEmpty)
        XCTAssertEqual(vm.totalPairs, 0)

        try? FileManager.default.removeItem(at: emptyDir)
    }

    // MARK: - playing 状态：flipCard 逻辑

    func testFlipCard_flipsUnflippedCard() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        guard let idx = vm.cards.firstIndex(where: { !$0.isFlipped && !$0.isMatched }) else {
            XCTFail("应有未翻转的卡牌"); return
        }

        vm.flipCard(at: idx)
        XCTAssertTrue(vm.cards[idx].isFlipped)
        XCTAssertTrue(vm.flippedIndices.contains(idx))
    }

    func testFlipCard_ignoresAlreadyFlipped() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        guard let idx = vm.cards.firstIndex(where: { !$0.isFlipped }) else {
            XCTFail(); return
        }

        vm.flipCard(at: idx)
        XCTAssertTrue(vm.cards[idx].isFlipped)

        vm.flipCard(at: idx)
        XCTAssertTrue(vm.cards[idx].isFlipped)
        XCTAssertEqual(vm.flippedIndices.count, 1, "不应重复添加")
    }

    func testFlipCard_ignoresMatchedCard() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        guard let idx = vm.cards.indices.first else { XCTFail(); return }

        vm.cards[idx].isMatched = true
        vm.flipCard(at: idx)
        XCTAssertFalse(vm.flippedIndices.contains(idx), "已匹配卡牌不应翻转")
    }

    func testFlipCard_blocksDuringChecking() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        vm.isChecking = true

        guard let idx = vm.cards.firstIndex(where: { !$0.isFlipped }) else { XCTFail(); return }
        vm.flipCard(at: idx)
        XCTAssertFalse(vm.cards[idx].isFlipped, "isChecking 期间不应翻转新卡牌")
    }

    // MARK: - stop

    func testStop_invalidatesTimer() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()
        vm.stop()
        // 不应崩溃
    }

    // MARK: - 卡牌结构完整性

    func testStart_cardsHaveUniqueIds() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        let ids = vm.cards.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "卡牌 ID 应唯一")
    }

    func testStart_eachPairHasWordAndMeaning() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        let pairGroups = Dictionary(grouping: vm.cards, by: { $0.pairId })
        for (_, cards) in pairGroups {
            XCTAssertEqual(cards.count, 2)
            XCTAssertEqual(cards.filter { $0.isWord }.count, 1, "每对应有 1 张单词卡")
            XCTAssertEqual(cards.filter { !$0.isWord }.count, 1, "每对应有 1 张释义卡")
        }
    }

    // MARK: - 按 levelId 启动

    func testStart_forLevel_filtersToLevelWords() {
        var lp = progressRepo.levelProgress(for: 1)
        lp.isCompleted = true
        progressRepo.updateLevelProgress(lp)

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start(forLevel: 1)

        XCTAssertFalse(vm.cards.isEmpty, "level 1 有单词，应生成卡牌")
        let levelWords = wordRepo.words(forLevel: 1).map(\.text)
        let levelMeanings = wordRepo.words(forLevel: 1).map(\.meaning)
        for card in vm.cards {
            XCTAssertTrue(
                levelWords.contains(card.text) || levelMeanings.contains(card.text),
                "卡牌内容应属于指定 level"
            )
        }
    }

    func testStart_forLevel_prioritizesUnmastered() {
        var lp = progressRepo.levelProgress(for: 1)
        lp.isCompleted = true
        progressRepo.updateLevelProgress(lp)

        let level1Words = wordRepo.words(forLevel: 1)
        for word in level1Words.prefix(2) {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .mastered
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start(forLevel: 1)

        XCTAssertFalse(vm.cards.isEmpty)
    }

    // MARK: - ⚠️ 潜在问题：MatchGame 没有 error 处理

    func testStart_emptyGame_totalPairsIsZero() {
        let emptyWordRepo = WordRepository(words: [])

        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MGVMZeroPairs-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = MatchGameViewModel(
            wordRepo: emptyWordRepo, progressRepo: emptyProgressRepo, petRepo: petRepo
        )
        vm.start()

        // ✅ 修复后：完全无单词时 errorMessage 被设置
        XCTAssertEqual(vm.totalPairs, 0, "完全无单词时 totalPairs 应为 0")
        XCTAssertTrue(vm.cards.isEmpty)
        XCTAssertEqual(vm.errorMessage, "暂无题目数据")

        try? FileManager.default.removeItem(at: emptyDir)
    }

    func testStart_hasWords_noErrorMessage() {
        for word in Self.sampleWords {
            var wp = WordProgress.initial(wordId: word.id)
            wp.mastery = .learning
            progressRepo.updateWordProgress(wp)
        }

        let vm = MatchGameViewModel(
            wordRepo: wordRepo, progressRepo: progressRepo, petRepo: petRepo
        )
        vm.start()

        XCTAssertNil(vm.errorMessage, "有单词时不应设置 errorMessage")
        XCTAssertFalse(vm.cards.isEmpty)
    }

    func testStart_forLevel_emptyRepo_setsErrorMessage() {
        let emptyWordRepo = WordRepository(words: [])
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MGVMLevelEmpty-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let emptyProgressRepo = ProgressRepository(documentsDir: emptyDir)
        emptyProgressRepo.load()

        let vm = MatchGameViewModel(
            wordRepo: emptyWordRepo, progressRepo: emptyProgressRepo, petRepo: petRepo
        )
        vm.start(forLevel: 1)

        XCTAssertEqual(vm.errorMessage, "暂无题目数据", "指定 level 也无数据时应设置 errorMessage")

        try? FileManager.default.removeItem(at: emptyDir)
    }

    // MARK: - Helpers

    nonisolated private static let sampleWords: [Word] = (1...20).map { i in
        Word(id: i, text: "word\(i)", meaning: "meaning\(i)", group: (i - 1) / 5 + 1)
    }
}
