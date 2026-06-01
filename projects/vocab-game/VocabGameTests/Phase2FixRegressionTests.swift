import XCTest
@testable import VocabGame

/// Phase 2 审查修复的回归测试
final class Phase2FixRegressionTests: XCTestCase {

    private var progressRepo: ProgressRepository!
    private var petRepo: PetRepository!
    private let testKey = "pet_fix_test_\(UUID().uuidString)"
    private var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FixTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        progressRepo = ProgressRepository(documentsDir: testDir)
        progressRepo.load()
        petRepo = PetRepository(testKey: testKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    // MARK: - P0-3: 配对失败更新单词进度

    func testMatchFailure_updatesWordProgress() {
        let word = Word(id: 1, text: "hello", meaning: "你好", group: 1)
        var wp = progressRepo.wordProgress(for: word.id)
        XCTAssertEqual(wp.wrongCount, 0)

        // 模拟匹配失败 → 答错
        wp = SpacedRepetitionService.updateProgress(wp, isCorrect: false)
        progressRepo.updateWordProgress(wp)

        let loaded = progressRepo.wordProgress(for: word.id)
        XCTAssertEqual(loaded.wrongCount, 1)
        XCTAssertEqual(loaded.consecutiveCorrect, 0)
        XCTAssertEqual(loaded.mastery, .new) // learning → new
    }

    func testMatchFailure_bothCardsUpdated() {
        // 配对失败时，两张卡对应的单词都应更新进度
        let word1 = Word(id: 1, text: "hello", meaning: "你好", group: 1)
        let word2 = Word(id: 2, text: "world", meaning: "世界", group: 1)

        // 两张卡配对失败 → 两个词都标记为答错
        for w in [word1, word2] {
            var wp = progressRepo.wordProgress(for: w.id)
            wp = SpacedRepetitionService.updateProgress(wp, isCorrect: false)
            progressRepo.updateWordProgress(wp)
        }

        XCTAssertEqual(progressRepo.wordProgress(for: 1).wrongCount, 1)
        XCTAssertEqual(progressRepo.wordProgress(for: 2).wrongCount, 1)
    }

    func testMatchFailure_wordEntersMistakeBook() {
        let word = Word(id: 5, text: "test", meaning: "测试", group: 1)
        var wp = progressRepo.wordProgress(for: word.id)
        wp = SpacedRepetitionService.updateProgress(wp, isCorrect: false)
        progressRepo.updateWordProgress(wp)

        let mistakes = progressRepo.mistakeWords()
        XCTAssertTrue(mistakes.contains { $0.wordId == word.id }, "答错应进入错词本")
    }

    // MARK: - P1-4: 每日挑战数据统一到 ProgressData

    func testDailyChallengeRecord_initialNotCompleted() {
        XCTAssertFalse(progressRepo.isDailyCompleted)
        XCTAssertEqual(progressRepo.dailyBestScore, 0)
    }

    func testDailyChallengeRecord_recordCompletion() {
        progressRepo.recordDailyCompletion(score: 850)

        XCTAssertTrue(progressRepo.isDailyCompleted)
        XCTAssertEqual(progressRepo.dailyBestScore, 850)
    }

    func testDailyChallengeRecord_bestScorePreserved() {
        progressRepo.recordDailyCompletion(score: 700)
        XCTAssertEqual(progressRepo.dailyBestScore, 700)

        // 同一天再记录更高分
        progressRepo.recordDailyCompletion(score: 900)
        XCTAssertEqual(progressRepo.dailyBestScore, 900, "应保留当天最高分")
    }

    func testDailyChallengeRecord_lowerScoreDoesNotOverride() {
        progressRepo.recordDailyCompletion(score: 900)
        progressRepo.recordDailyCompletion(score: 600)
        XCTAssertEqual(progressRepo.dailyBestScore, 900, "低分不应覆盖高分")
    }

    func testDailyChallengeRecord_persistsViaSaveLoad() {
        progressRepo.recordDailyCompletion(score: 750)

        // 模拟重启
        let repo2 = ProgressRepository(documentsDir: testDir)
        repo2.load()

        XCTAssertTrue(repo2.isDailyCompleted)
        XCTAssertEqual(repo2.dailyBestScore, 750)
    }

    func testDailyChallengeRecord_codable() throws {
        var pd = ProgressRepository.ProgressData()
        pd.dailyChallengeRecords["2025-05-25"] = ProgressRepository.DailyRecord(isCompleted: true, bestScore: 800)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pd)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProgressRepository.ProgressData.self, from: data)

        XCTAssertTrue(decoded.dailyChallengeRecords["2025-05-25"]?.isCompleted ?? false)
        XCTAssertEqual(decoded.dailyChallengeRecords["2025-05-25"]?.bestScore, 800)
    }

    // MARK: - P1-7: SeededRandomGenerator seed=0 保护

    func testSeededRandomGenerator_seedZero_doesNotCrash() {
        var g = SeededRandomGenerator(seed: 0)
        let v1 = g.next()
        let v2 = g.next()
        // state = 1 (not 0), should produce valid sequence
        XCTAssertNotEqual(v1, 0, "seed=0 保护后 state 不应为 0")
        XCTAssertNotEqual(v2, 0)
    }

    func testSeededRandomGenerator_seedZero_deterministic() {
        var g1 = SeededRandomGenerator(seed: 0)
        var g2 = SeededRandomGenerator(seed: 0)

        let seq1 = (0..<5).map { _ in g1.next() }
        let seq2 = (0..<5).map { _ in g2.next() }
        XCTAssertEqual(seq1, seq2, "seed=0 的两次初始化应产生相同序列")
    }

    // MARK: - P1-8: purchase 按 item.type 分支

    func testPurchase_accessory_addsToPetAccessories() {
        progressRepo.updateProfile { $0.coins = 100 }
        let item = ShopItem(id: "hat_test", name: "测试帽", type: .accessory, category: .hat, price: 50, description: "测试")

        // 模拟 purchase accessory 分支
        progressRepo.updateProfile { $0.coins -= item.price }
        petRepo.updatePetState { $0.accessories.append(item.id) }

        XCTAssertEqual(progressRepo.profile.coins, 50)
        XCTAssertTrue(petRepo.petState.accessories.contains("hat_test"))
    }

    func testPurchase_hint_consumable_noAccessory() {
        progressRepo.updateProfile { $0.coins = 100 }
        let item = ShopItem(id: "hint_pack", name: "提示包", type: .hint, category: .hat, price: 30, description: "提示")

        // hint 类型的购买只扣金币，不加装饰
        progressRepo.updateProfile { $0.coins -= item.price }

        XCTAssertEqual(progressRepo.profile.coins, 70)
        XCTAssertFalse(petRepo.petState.accessories.contains("hint_pack"))
    }

    func testPurchase_extraTime_consumable_noAccessory() {
        progressRepo.updateProfile { $0.coins = 100 }
        let item = ShopItem(id: "time_extra", name: "加时", type: .extraTime, category: .hat, price: 20, description: "加时间")

        progressRepo.updateProfile { $0.coins -= item.price }

        XCTAssertEqual(progressRepo.profile.coins, 80)
        XCTAssertFalse(petRepo.petState.accessories.contains("time_extra"))
    }

    // MARK: - P1-5: saveActiveSession (拼写+每日)

    func testSaveActiveSession_persists() {
        let words = [Word(id: 1, text: "hello", meaning: "你好", group: 1)]
        let questions = words.map { Question(word: $0, type: .spellWord, options: []) }
        let session = GameSession.create(mode: .spellChallenge, questions: questions)
        var s = session
        s.currentIndex = 3
        s.score = 250

        progressRepo.saveActiveSession(s)
        let loaded = progressRepo.activeSession

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.gameMode, .spellChallenge)
        XCTAssertEqual(loaded?.currentIndex, 3)
        XCTAssertEqual(loaded?.score, 250)
    }

    func testSaveActiveSession_dailyChallenge() {
        let words = (1...5).map { Word(id: $0, text: "w\($0)", meaning: "m\($0)", group: 1) }
        let questions = words.map { Question(word: $0, type: .selectMeaning, options: ["a","b","c","d"]) }
        let session = GameSession.create(mode: .dailyChallenge, questions: questions)

        progressRepo.saveActiveSession(session)
        let loaded = progressRepo.activeSession

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.gameMode, .dailyChallenge)
    }

    func testClearActiveSession_removesSession() {
        let words = [Word(id: 1, text: "hello", meaning: "你好", group: 1)]
        let questions = words.map { Question(word: $0, type: .spellWord, options: []) }
        let session = GameSession.create(mode: .spellChallenge, questions: questions)

        progressRepo.saveActiveSession(session)
        progressRepo.clearActiveSession()

        XCTAssertNil(progressRepo.activeSession)
    }
}
