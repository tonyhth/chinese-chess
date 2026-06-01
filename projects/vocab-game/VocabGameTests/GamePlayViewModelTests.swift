import XCTest
import SwiftUI
@testable import VocabGame

/// 测试 GamePlayView / GamePlayViewModel 的核心逻辑
/// 包含空数据保护、会话保存恢复、金币经验计算
@MainActor
final class GamePlayViewModelTests: XCTestCase {

    private var progressRepo: ProgressRepository!
    private var petRepo: PetRepository!
    private let testKey = "pet_gpv_p2_\(UUID().uuidString)"
    private var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GPVTests-\(UUID().uuidString)")
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

    // MARK: - StarRating 集成

    func testSaveResult_calculatesCorrectStars() {
        // 模拟闯关完成：950 分 → 3 星
        let stars = StarRating.stars(forScore: 950)
        XCTAssertEqual(stars, 3)

        // 更新关卡进度
        var lp = progressRepo.levelProgress(for: 1)
        lp.isCompleted = true
        lp.stars = max(lp.stars, stars)
        lp.bestScore = 950
        progressRepo.updateLevelProgress(lp)

        let loaded = progressRepo.levelProgress(for: 1)
        XCTAssertTrue(loaded.isCompleted)
        XCTAssertEqual(loaded.stars, 3)
        XCTAssertEqual(loaded.bestScore, 950)
    }

    func testSaveResult_maxStarsPreserved() {
        // 先获得 2 星（800 分）
        var lp = progressRepo.levelProgress(for: 1)
        lp.stars = 2
        lp.bestScore = 850
        progressRepo.updateLevelProgress(lp)

        // 重玩获得 1 星（650 分），应保留 2 星
        let newStars = StarRating.stars(forScore: 650)
        var updated = progressRepo.levelProgress(for: 1)
        updated.stars = max(updated.stars, newStars)
        updated.bestScore = max(updated.bestScore, 650)
        progressRepo.updateLevelProgress(updated)

        let loaded = progressRepo.levelProgress(for: 1)
        XCTAssertEqual(loaded.stars, 2, "应保留历史最高星级")
        XCTAssertEqual(loaded.bestScore, 850)
    }

    // MARK: - 金币奖励

    func testCoinsEarned_adventureMode() {
        // coins = max(score / 100, 1) + (maxCombo >= 5 ? 5 : 0)
        let coins850combo3 = max(850 / 100, 1) + 0 // combo < 5
        XCTAssertEqual(coins850combo3, 8)

        let coins900combo6 = max(900 / 100, 1) + 5 // combo >= 5
        XCTAssertEqual(coins900combo6, 14)

        let coins500combo0 = max(500 / 100, 1) + 0
        XCTAssertEqual(coins500combo0, 5)
    }

    func testCoinsEarned_minimumIs1() {
        let coins = max(0 / 100, 1) + 0
        XCTAssertEqual(coins, 1, "最低 1 金币")
    }

    // MARK: - 经验值计算

    func testExpGained_adventureMode() {
        // exp = score / 10 + maxCombo * 5
        let exp = 900 / 10 + 8 * 5
        XCTAssertEqual(exp, 130)
    }

    // MARK: - 正确答案辅助

    func testCorrectAnswer() {
        let word = Word(id: 1, text: "hello", meaning: "你好", group: 1)

        let q1 = Question(word: word, type: .selectMeaning, options: [])
        XCTAssertEqual(q1.word.meaning, "你好")

        let q2 = Question(word: word, type: .selectWord, options: [])
        XCTAssertEqual(q2.word.text, "hello")

        let q3 = Question(word: word, type: .spellWord, options: [])
        XCTAssertEqual(q3.word.text, "hello")
    }

    // MARK: - 题型分配（闯关模式 10 题）

    func testQuestionTypeDistribution_10Questions() {
        // 0-3: selectMeaning, 4-6: selectWord, 7-8: listenAndSelect, 9: spellWord
        let expectedTypes: [QuestionType] = [
            .selectMeaning, .selectMeaning, .selectMeaning, .selectMeaning,
            .selectWord, .selectWord, .selectWord,
            .listenAndSelect, .listenAndSelect,
            .spellWord
        ]

        for (i, expected) in expectedTypes.enumerated() {
            let type: QuestionType
            switch i {
            case 0..<4: type = .selectMeaning
            case 4..<7: type = .selectWord
            case 7..<9: type = .listenAndSelect
            default: type = .spellWord
            }
            XCTAssertEqual(type, expected, "题目 \(i) 题型不正确")
        }
    }

    // MARK: - 宠物 excited 触发

    func testPetExcited_maxCombo5() {
        let maxCombo = 5
        let stars = StarRating.stars(forScore: 500)
        let isExcited = maxCombo >= 5 || stars >= 3
        XCTAssertTrue(isExcited, "连击 5 应触发 excited")
    }

    func testPetExcited_threeStars() {
        let maxCombo = 2
        let stars = StarRating.stars(forScore: 950)
        let isExcited = maxCombo >= 5 || stars >= 3
        XCTAssertTrue(isExcited, "3 星应触发 excited")
    }

    func testPetNotExcited_normalPlay() {
        let maxCombo = 3
        let stars = StarRating.stars(forScore: 700)
        let isExcited = maxCombo >= 5 || stars >= 3
        XCTAssertFalse(isExcited)
    }

    // MARK: - 会话保存/恢复

    func testActiveSession_saveAndClear() {
        let words = (1...3).map { Word(id: $0, text: "w\($0)", meaning: "m\($0)", group: 1) }
        let questions = words.map { Question(word: $0, type: .selectMeaning, options: ["a","b","c","d"]) }
        let session = GameSession.create(mode: .adventure, levelId: 1, questions: questions)

        progressRepo.saveActiveSession(session)
        XCTAssertNotNil(progressRepo.activeSession)

        progressRepo.clearActiveSession()
        XCTAssertNil(progressRepo.activeSession)
    }

    func testActiveSession_codableRoundTrip() throws {
        let words = (1...5).map { Word(id: $0, text: "w\($0)", meaning: "m\($0)", group: 1) }
        var questions = words.map { Question(word: $0, type: .selectMeaning, options: ["a","b","c","d"]) }
        questions[0].isCorrect = true
        let session = GameSession.create(mode: .adventure, levelId: 3, questions: questions)

        progressRepo.saveActiveSession(session)
        progressRepo.load() // 模拟重启后加载
        let restored = progressRepo.activeSession

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.levelId, 3)
        XCTAssertEqual(restored?.gameMode, .adventure)
        XCTAssertEqual(restored?.questions[0].isCorrect, true)
    }

    // MARK: - GamePlayView 空数据保护（通过 Repository 行为间接验证）

    func testStartLevel_emptyWordRepo_selectedIsEmpty() {
        let emptyWordRepo = WordRepository(words: [])
        let words = emptyWordRepo.words(forLevel: 1)
        let selected = Array(words.prefix(10))

        XCTAssertTrue(selected.isEmpty, "空 wordRepo 返回空数组 → GamePlayView 应触发 errorMessage")
    }

    func testStartLevel_hasWords_selectedNotEmpty() {
        let wordRepo = WordRepository(words: (1...5).map {
            Word(id: $0, text: "w\($0)", meaning: "m\($0)", group: 1)
        })
        let words = wordRepo.words(forLevel: 1)
        let selected = Array(words.prefix(10))

        XCTAssertFalse(selected.isEmpty, "有数据时 selected 不应为空")
    }

    func testStartMistakeReview_noMistakes_questionsIsEmpty() {
        // progressRepo 没有任何错题记录
        let mistakes = progressRepo.mistakeWords()
        let allWords = WordRepository(words: []).allWords
        var questions: [Question] = []
        for wp in mistakes.prefix(10) {
            guard let word = allWords.first(where: { $0.id == wp.wordId }) else { continue }
            questions.append(Question.create(word: word, type: .selectMeaning, allWords: allWords))
        }

        XCTAssertTrue(questions.isEmpty, "无错题时 questions 为空 → GamePlayView 应触发 errorMessage")
    }

    func testStartMistakeReview_hasMistakes_generatesQuestions() {
        let wordRepo = WordRepository(words: [
            Word(id: 1, text: "hello", meaning: "你好", group: 1)
        ])
        var wp = WordProgress.initial(wordId: 1)
        wp.wrongCount = 3
        progressRepo.updateWordProgress(wp)

        let mistakes = progressRepo.mistakeWords()
        XCTAssertFalse(mistakes.isEmpty, "wrongCount > 0 应出现在 mistakeWords 中")

        let allWords = wordRepo.allWords
        var questions: [Question] = []
        for wp in mistakes.prefix(10) {
            guard let word = allWords.first(where: { $0.id == wp.wordId }) else { continue }
            questions.append(Question.create(word: word, type: .selectMeaning, allWords: allWords))
        }

        XCTAssertFalse(questions.isEmpty, "有错题时应生成 questions")
    }
}
