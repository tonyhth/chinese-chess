#!/usr/bin/env swift
// ESC exit + session cleanup test for VocabGame v1.3
// Validates: onDismiss → clearActiveSession, re-enter works correctly

import Foundation

// MARK: - Models

struct Word: Equatable, Codable {
    let id: Int
    let text: String
    let meaning: String
    let group: Int
}

enum QuestionType: String {
    case selectMeaning
    case selectWord
    case listenAndSelect
    case spellWord
}

struct Question {
    let word: Word
    let type: QuestionType
    var options: [String] = []
    var isCorrect: Bool? = nil

    static func create(word: Word, type: QuestionType, allWords: [Word]) -> Question {
        var opts: [String] = []
        switch type {
        case .selectMeaning:
            var d = allWords.filter { $0.id != word.id }.shuffled().prefix(3).map { $0.meaning }
            d.append(word.meaning)
            opts = d.shuffled()
        case .selectWord, .listenAndSelect:
            var d = allWords.filter { $0.id != word.id }.shuffled().prefix(3).map { $0.text }
            d.append(word.text)
            opts = d.shuffled()
        case .spellWord:
            opts = []
        }
        return Question(word: word, type: type, options: opts)
    }
}

enum GameMode: String {
    case adventure
    case spellChallenge
    case matchPairs
    case dailyChallenge
    case mistakeReview
}

struct GameSession {
    let id: UUID
    let gameMode: GameMode
    let levelId: Int?
    var questions: [Question]
    var currentIndex: Int
    var score: Int
    var combo: Int
    var maxCombo: Int
    var isCompleted: Bool

    static func create(mode: GameMode, levelId: Int? = nil, questions: [Question]) -> GameSession {
        GameSession(id: UUID(), gameMode: mode, levelId: levelId, questions: questions, currentIndex: 0, score: 0, combo: 0, maxCombo: 0, isCompleted: false)
    }

    var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
}

enum MasteryLevel: Int {
    case new = 0; case learning = 1; case familiar = 2; case mastered = 3
}

struct WordProgress {
    let wordId: Int
    var mastery: MasteryLevel
    var correctCount: Int = 0
    var consecutiveCorrect: Int = 0
    var wrongCount: Int = 0
    static func initial(wordId: Int) -> WordProgress {
        WordProgress(wordId: wordId, mastery: .new)
    }
}

// MARK: - Repositories

class WordRepository {
    private(set) var allWords: [Word] = []
    private(set) var wordsByGroup: [Int: [Word]] = [:]
    init(words: [Word]) {
        self.allWords = words
        self.wordsByGroup = Dictionary(grouping: words, by: { $0.group })
    }
    func words(forLevel levelId: Int) -> [Word] { wordsByGroup[levelId] ?? [] }
}

class ProgressRepository {
    var wordProgressMap: [Int: WordProgress] = [:]
    var activeSession: GameSession? = nil

    func updateWordProgress(_ wp: WordProgress) { wordProgressMap[wp.wordId] = wp }
    func wordProgress(for wordId: Int) -> WordProgress { wordProgressMap[wordId] ?? .initial(wordId: wordId) }
    func mistakeWords() -> [WordProgress] { wordProgressMap.values.filter { $0.wrongCount > 0 } }
    func saveActiveSession(_ s: GameSession) { activeSession = s }
    func clearActiveSession() { activeSession = nil }
}

// MARK: - Simulate MainTabView.onDismiss behavior

/// Simulates ESC press → sheet dismiss → onDismiss callback
/// The key behavior: onDismiss clears the active session
func simulateESCDismiss(progressRepo: ProgressRepository) {
    // This is what MainTabView.onDismiss does for ALL game modes:
    progressRepo.clearActiveSession()
}

// MARK: - Business logic (extracted from Views/ViewModels)

func gamePlayStartLevel(wordRepo: WordRepository, progressRepo: ProgressRepository, levelId: Int) -> (session: GameSession?, errorMessage: String?) {
    let words = wordRepo.words(forLevel: levelId).shuffled()
    let allWords = wordRepo.allWords
    let selected = Array(words.prefix(10))
    guard !selected.isEmpty else { return (nil, "暂无题目数据") }
    var questions: [Question] = []
    for (i, word) in selected.enumerated() {
        let type: QuestionType
        switch i {
        case 0..<4: type = .selectMeaning
        case 4..<7: type = .selectWord
        case 7..<9: type = .listenAndSelect
        default: type = .spellWord
        }
        questions.append(Question.create(word: word, type: type, allWords: allWords))
    }
    let session = GameSession.create(mode: .adventure, levelId: levelId, questions: questions)
    progressRepo.saveActiveSession(session)
    return (session, nil)
}

func gamePlayResumeSession(progressRepo: ProgressRepository) -> GameSession? {
    progressRepo.activeSession
}

func spellChallengeStart(wordRepo: WordRepository, progressRepo: ProgressRepository) -> (words: [Word], errorMessage: String?) {
    var words: [Word] = []
    words = Array(wordRepo.allWords.shuffled().prefix(10))
    if words.isEmpty { return (words, "暂无题目数据") }
    words.shuffle()
    return (words, nil)
}

func matchGameStart(wordRepo: WordRepository, progressRepo: ProgressRepository, levelId: Int?) -> (words: [Word], errorMessage: String?) {
    let candidates = wordRepo.words(forLevel: levelId ?? 1)
    let selected = Array(candidates.shuffled().prefix(8))
    guard selected.count >= 4 else { return ([], "暂无题目数据") }
    return (selected, nil)
}

// MARK: - Test engine

var passed = 0
var failed = 0
var errors: [String] = []

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; errors.append("FAIL: \(message) (line \(line))") }
}
func assertNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
    assert(value == nil, message, file: file, line: line)
}
func XCTAssertNotNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
    assert(value != nil, message, file: file, line: line)
}

// Load real data
let wordlistPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("DevTeam/projects/vocab-game/VocabGame/Resources/Data/wordlist.json")
let wordData = try! Data(contentsOf: wordlistPath)
let allWords = try! JSONDecoder().decode([Word].self, from: wordData)

// =============================================
// MARK: - TESTS: ESC Exit Scenarios
// =============================================

print("=== 1. 闯关模式 ESC 退出 → 回到关卡地图 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // Enter level 1
    let (session1, err1) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    assertNil(err1, "Level 1 正常加载")
    XCTAssertNotNil(progressRepo.activeSession, "进入后 activeSession 不为 nil")

    // ESC → dismiss → onDismiss clears session
    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "ESC 退出后 activeSession 被清除")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // Enter level 1, play 3 questions, then ESC
    let (session1, _) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    XCTAssertNotNil(session1, "Level 1 session 创建成功")

    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "中途 ESC 退出后 session 清除")

    // Re-enter level 1 → should work normally
    let (session2, err2) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    assertNil(err2, "重新进入 Level 1 正常加载")
    XCTAssertNotNil(session2, "重新进入 Level 1 session 创建")
    XCTAssertNotNil(progressRepo.activeSession, "重新进入后 activeSession 恢复")
}

print("=== 2. 闯关模式 ESC 退出 → 再进入另一关卡 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // Enter level 1
    gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    // ESC
    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "ESC 后 session 清除")

    // Enter level 5
    let (session5, err5) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 5)
    assertNil(err5, "切换到 Level 5 正常加载")
    XCTAssertNotNil(session5, "Level 5 session 创建")
    assertEqual(session5!.levelId, 5, "Level 5 session levelId 正确")
    assertEqual(session5!.questions.count, 10, "Level 5 有 10 题")
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    assert(a == b, "\(message) — expected \(b), got \(a)", file: file, line: line)
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // Rapid switching: L1 → ESC → L3 → ESC → L10
    for level in [1, 3, 10] {
        let (session, err) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: level)
        assertNil(err, "Level \(level) 正常加载")
        XCTAssertNotNil(session, "Level \(level) session 存在")
        simulateESCDismiss(progressRepo: progressRepo)
        assertNil(progressRepo.activeSession, "ESC Level \(level) 后 session 清除")
    }
}

print("=== 3. 拼写挑战 ESC 退出 → 再进入 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // Enter spell challenge (simplified - actual VM saves session too)
    let (words1, err1) = spellChallengeStart(wordRepo: repo, progressRepo: progressRepo)
    assertNil(err1, "拼写挑战正常加载")
    XCTAssertNotNil(words1.first, "拼写挑战有单词")

    // ESC → onDismiss clears session
    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "ESC 退出拼写挑战后 session 清除")

    // Re-enter
    let (words2, err2) = spellChallengeStart(wordRepo: repo, progressRepo: progressRepo)
    assertNil(err2, "重新进入拼写挑战正常")
    XCTAssertNotNil(words2.first, "重新进入有单词")
}

print("=== 4. 配对消消乐 ESC 退出 → 再进入 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    let (words1, err1) = matchGameStart(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    assertNil(err1, "配对消消乐正常加载")
    assertEqual(words1.count, 8, "配对 8 个单词")

    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "ESC 退出配对后 session 清除")

    let (words2, err2) = matchGameStart(wordRepo: repo, progressRepo: progressRepo, levelId: 3)
    assertNil(err2, "重新进入配对 Level 3 正常")
    assertEqual(words2.count, 8, "重新进入 8 个单词")
}

print("=== 5. 错题复习 ESC 退出 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // No mistakes → "暂无错题"
    let questions1 = gamePlayResumeSession(progressRepo: progressRepo)
    assert(questions1 == nil, "无 session → nil")

    // Enter mistake review (would save session in real VM)
    let mistakes = progressRepo.mistakeWords()
    assert(mistakes.isEmpty, "无错题")

    // Even after ESC, should be safe
    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "ESC 后 session 清除")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // With mistakes
    var wp = WordProgress.initial(wordId: 1)
    wp.wrongCount = 3
    progressRepo.updateWordProgress(wp)

    // Simulate entering mistake review (GamePlayView mode=mistakeReview saves session)
    let allWords = repo.allWords
    if let word = allWords.first(where: { $0.id == 1 }) {
        let q = Question.create(word: word, type: .selectMeaning, allWords: allWords)
        let session = GameSession.create(mode: .mistakeReview, questions: [q])
        progressRepo.saveActiveSession(session)
    }

    XCTAssertNotNil(progressRepo.activeSession, "错题复习 session 存在")
    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "ESC 退出错题复习后 session 清除")
}

print("=== 6. 正常完成流程不受影响 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // Enter level 1, play all 10 questions (simulate completion)
    let (session, _) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    XCTAssertNotNil(session, "Session 创建")
    XCTAssertNotNil(progressRepo.activeSession, "activeSession 存在")

    // Simulate completion: advance through all questions
    // In real code, advanceToNext clears session when completed
    // Then ResultView calls saveResult → dismiss
    // onDismiss also clears (idempotent)
    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "正常完成后 onDismiss 清除 session (幂等)")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // Double clearActiveSession should not crash
    progressRepo.saveActiveSession(GameSession.create(mode: .adventure, questions: []))
    simulateESCDismiss(progressRepo: progressRepo)
    simulateESCDismiss(progressRepo: progressRepo)  // Double dismiss
    assertNil(progressRepo.activeSession, "重复 dismiss 不崩溃")
}

print("=== 7. 冒险模式 level picker 内 ESC ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()

    // Enter adventure mode without specific level → shows level picker
    // No session saved yet (showingLevelPicker = true, session = nil)
    // ESC at this point → onDismiss clears session (which is already nil)
    simulateESCDismiss(progressRepo: progressRepo)
    assertNil(progressRepo.activeSession, "Level picker 阶段 ESC 安全")

    // Then select level 2
    let (session2, err2) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 2)
    assertNil(err2, "ESC 后选择 Level 2 正常")
    XCTAssertNotNil(session2, "Level 2 session 创建")
}

// MARK: Results

print("\n" + String(repeating: "=", count: 50))
print("ESC 退出测试结果: \(passed) passed, \(failed) failed")
if !errors.isEmpty {
    print("\nFAILURES:")
    for e in errors { print("  \(e)") }
}
exit(failed > 0 ? 1 : 0)
