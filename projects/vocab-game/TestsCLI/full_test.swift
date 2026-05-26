#!/usr/bin/env swift
// Full functional test for VocabGame after root-cause fix (wordlist.json path)
// Validates: data loading, all game modes have content, Question generation, edge cases

import Foundation

// MARK: - Models (matching VocabGame)

struct Word: Equatable, Codable {
    let id: Int
    let text: String
    let meaning: String
    let group: Int
}

enum QuestionType: String, Codable {
    case selectMeaning
    case selectWord
    case listenAndSelect
    case spellWord
}

struct Question {
    let word: Word
    let type: QuestionType
    var options: [String]
    var isCorrect: Bool?

    static func create(word: Word, type: QuestionType, allWords: [Word]) -> Question {
        let options: [String]
        switch type {
        case .selectMeaning:
            var distractors = allWords
                .filter { $0.id != word.id }
                .shuffled()
                .prefix(3)
                .map { $0.meaning }
            distractors.append(word.meaning)
            options = distractors.shuffled()
        case .selectWord:
            var distractors = allWords
                .filter { $0.id != word.id }
                .shuffled()
                .prefix(3)
                .map { $0.text }
            distractors.append(word.text)
            options = distractors.shuffled()
        case .listenAndSelect:
            var distractors = allWords
                .filter { $0.id != word.id }
                .shuffled()
                .prefix(3)
                .map { $0.text }
            distractors.append(word.text)
            options = distractors.shuffled()
        case .spellWord:
            options = []
        }
        return Question(word: word, type: type, options: options)
    }
}

enum MasteryLevel: Int, Codable {
    case new = 0
    case learning = 1
    case familiar = 2
    case mastered = 3
}

struct WordProgress {
    let wordId: Int
    var mastery: MasteryLevel
    var correctCount: Int
    var consecutiveCorrect: Int
    var wrongCount: Int
    var lastReviewed: Date
    var nextReviewDate: Date
    static func initial(wordId: Int) -> WordProgress {
        WordProgress(wordId: wordId, mastery: .new, correctCount: 0, consecutiveCorrect: 0, wrongCount: 0, lastReviewed: .distantPast, nextReviewDate: .distantPast)
    }
}

// MARK: - Repositories (matching actual behavior)

class WordRepository {
    private(set) var allWords: [Word] = []
    private(set) var wordsByGroup: [Int: [Word]] = [:]

    init(words: [Word]) {
        self.allWords = words
        self.wordsByGroup = Dictionary(grouping: words, by: { $0.group })
    }

    func words(forLevel levelId: Int) -> [Word] {
        wordsByGroup[levelId] ?? []
    }
}

class ProgressRepository {
    var wordProgressMap: [Int: WordProgress] = [:]
    var levelProgressMap: [Int: Bool] = [:]

    func updateWordProgress(_ wp: WordProgress) { wordProgressMap[wp.wordId] = wp }
    func wordProgress(for wordId: Int) -> WordProgress { wordProgressMap[wordId] ?? .initial(wordId: wordId) }
    func mistakeWords() -> [WordProgress] { wordProgressMap.values.filter { $0.wrongCount > 0 } }
    func isLevelUnlocked(_ levelId: Int) -> Bool { levelProgressMap[levelId] ?? false }

    // Simulate: level 1 always unlocked after onboarding
    func simulateOnboarding() {
        levelProgressMap[1] = true
    }
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
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    assert(a == b, "\(message) — expected \(b), got \(a)", file: file, line: line)
}
func assertGreaterThan<T: Comparable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    assert(a > b, "\(message) — expected > \(b), got \(a)", file: file, line: line)
}
func XCTAssertNotNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
    assert(value != nil, message, file: file, line: line)
}

// MARK: - Load real wordlist.json

let wordlistPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("DevTeam/projects/vocab-game/VocabGame/Resources/Data/wordlist.json")
let wordData = try! Data(contentsOf: wordlistPath)
let allWords = try! JSONDecoder().decode([Word].self, from: wordData)

// MARK: - Business logic functions (extracted from actual ViewModels)

func gamePlayStartLevel(wordRepo: WordRepository, progressRepo: ProgressRepository, levelId: Int) -> (questions: [Question], errorMessage: String?) {
    let words = wordRepo.words(forLevel: levelId).shuffled()
    let allWords = wordRepo.allWords
    let selected = Array(words.prefix(10))
    guard !selected.isEmpty else { return ([], "暂无题目数据") }
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
    return (questions, nil)
}

func gamePlayStartMistakeReview(wordRepo: WordRepository, progressRepo: ProgressRepository) -> (questions: [Question], errorMessage: String?) {
    let mistakes = progressRepo.mistakeWords()
    let allWords = wordRepo.allWords
    var questions: [Question] = []
    for wp in mistakes.prefix(10) {
        guard let word = allWords.first(where: { $0.id == wp.wordId }) else { continue }
        questions.append(Question.create(word: word, type: .selectMeaning, allWords: allWords))
    }
    if !questions.isEmpty { return (questions, nil) }
    else { return ([], "暂无错题") }
}

func spellChallengeStart(wordRepo: WordRepository, progressRepo: ProgressRepository) -> (words: [Word], errorMessage: String?) {
    var words: [Word] = []
    let learned = progressRepo.wordProgressMap.values
        .filter { $0.mastery.rawValue >= MasteryLevel.learning.rawValue }
    let allWords = wordRepo.allWords
    words = learned.compactMap { wp in allWords.first(where: { $0.id == wp.wordId }) }.shuffled()
    if words.count < 10 {
        let learnedIds = Set(words.map { $0.id })
        let unlockedLevels = (1...25).filter { progressRepo.isLevelUnlocked($0) }
        let supplemental = unlockedLevels.flatMap { wordRepo.words(forLevel: $0) }
            .filter { !learnedIds.contains($0.id) }.shuffled()
        words.append(contentsOf: supplemental.prefix(10 - words.count))
    }
    words = Array(words.prefix(15))
    if words.isEmpty { words = Array(wordRepo.allWords.shuffled().prefix(10)) }
    if words.isEmpty { return (words, "暂无题目数据") }
    words.shuffle()
    return (words, nil)
}

func matchGameStart(wordRepo: WordRepository, progressRepo: ProgressRepository, levelId: Int?) -> (words: [Word], errorMessage: String?) {
    var candidates: [Word]
    if let levelId = levelId {
        let levelWords = wordRepo.words(forLevel: levelId)
        let unmastered = levelWords.filter { wp in progressRepo.wordProgress(for: wp.id).mastery != .mastered }
        candidates = unmastered.isEmpty ? levelWords : unmastered
    } else {
        let mistakes = progressRepo.mistakeWords()
        let mistakeWords = mistakes.compactMap { wp in wordRepo.allWords.first(where: { $0.id == wp.wordId }) }
        let learned = progressRepo.wordProgressMap.values
            .filter { $0.mastery.rawValue >= MasteryLevel.learning.rawValue }
            .compactMap { wp in wordRepo.allWords.first(where: { $0.id == wp.wordId }) }
        candidates = mistakeWords
        candidates.append(contentsOf: learned.filter { w in !candidates.contains(where: { $0.id == w.id }) })
    }
    let selected = Array(candidates.shuffled().prefix(8))
    guard selected.count >= 4 else {
        candidates = wordRepo.allWords.shuffled()
        let fallback = Array(candidates.prefix(8))
        if fallback.isEmpty { return ([], "暂无题目数据") }
        return (fallback, nil)
    }
    return (selected, nil)
}

// =============================================
// MARK: - TESTS
// =============================================

// MARK: 0. WordRepository data loading
print("=== 0. WordRepository 数据加载 ===")

do {
    assertEqual(allWords.count, 376, "wordlist.json 包含 376 个单词")
}

do {
    let repo = WordRepository(words: allWords)
    for level in 1...25 {
        let count = repo.words(forLevel: level).count
        assert(count >= 15, "Level \(level) 有 ≥15 个单词（实际 \(count)）")
    }
}

do {
    let repo = WordRepository(words: allWords)
    assertEqual(repo.allWords.count, 376, "allWords 加载完整")
    // No duplicate IDs
    let ids = repo.allWords.map(\.id)
    assertEqual(Set(ids).count, ids.count, "单词 ID 无重复")
    // No empty text/meaning
    let emptyText = repo.allWords.filter { $0.text.isEmpty || $0.meaning.isEmpty }
    assert(emptyText.isEmpty, "所有单词 text/meaning 非空")
}

// MARK: 1. GamePlayView — 闯关模式（核心流程）
print("=== 1. GamePlayView 闯关模式 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    progressRepo.simulateOnboarding()
    let (questions, error) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    assertNil(error, "Level 1 有数据 → 无 errorMessage")
    assertEqual(questions.count, 10, "Level 1 生成 10 题")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    for level in 1...25 {
        let (questions, error) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: level)
        assertNil(error, "Level \(level) 无错误")
        assertEqual(questions.count, 10, "Level \(level) 生成 10 题")
    }
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    let (questions, _) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    // Verify question type distribution: 4 selectMeaning + 3 selectWord + 2 listenAndSelect + 1 spellWord
    let typeCounts = Dictionary(grouping: questions, by: { $0.type }).mapValues { $0.count }
    assertEqual(typeCounts[.selectMeaning] ?? 0, 4, "4 道 selectMeaning")
    assertEqual(typeCounts[.selectWord] ?? 0, 3, "3 道 selectWord")
    assertEqual(typeCounts[.listenAndSelect] ?? 0, 2, "2 道 listenAndSelect")
    assertEqual(typeCounts[.spellWord] ?? 0, 1, "1 道 spellWord")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    let (questions, _) = gamePlayStartLevel(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    // Selection questions should have 4 options each
    for (i, q) in questions.enumerated() {
        if q.type != .spellWord {
            assertEqual(q.options.count, 4, "题目 \(i) (\(q.type.rawValue)) 有 4 个选项")
            let hasCorrect = q.type == .selectMeaning ? q.options.contains(q.word.meaning) : q.options.contains(q.word.text)
            assert(hasCorrect, "题目 \(i) 选项中包含正确答案")
        }
    }
}

// MARK: 2. GamePlayView — 错题复习
print("=== 2. GamePlayView 错题复习 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    // No mistakes yet
    let (questions, error) = gamePlayStartMistakeReview(wordRepo: repo, progressRepo: progressRepo)
    assertEqual(error, "暂无错题", "无错题 → '暂无错题'")
    assert(questions.isEmpty, "无错题 → questions 为空")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    // Add some mistake words
    for id in [1, 5, 10, 15, 20] {
        var wp = WordProgress.initial(wordId: id)
        wp.wrongCount = 3
        progressRepo.updateWordProgress(wp)
    }
    let (questions, error) = gamePlayStartMistakeReview(wordRepo: repo, progressRepo: progressRepo)
    assertNil(error, "有错题 → 无 errorMessage")
    assertEqual(questions.count, 5, "5 个错题 → 5 题")
    for q in questions {
        assertEqual(q.type, .selectMeaning, "错题复习题型为 selectMeaning")
    }
}

// MARK: 3. SpellChallenge 拼写挑战
print("=== 3. SpellChallenge 拼写挑战 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    // New user, no learned words → falls back to allWords
    let (words, error) = spellChallengeStart(wordRepo: repo, progressRepo: progressRepo)
    assertNil(error, "新用户 fallback 到 allWords → 无 errorMessage")
    XCTAssertNotNil(words.first, "有单词可用")
    assertEqual(words.count, 10, "fallback 最多 10 个")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    progressRepo.simulateOnboarding()
    // Mark 20 words as learning
    for id in 1...20 {
        var wp = WordProgress.initial(wordId: id)
        wp.mastery = .learning
        progressRepo.updateWordProgress(wp)
    }
    let (words, error) = spellChallengeStart(wordRepo: repo, progressRepo: progressRepo)
    assertNil(error, "有 learned words → 无 errorMessage")
    XCTAssertNotNil(words.first, "有单词")
    assertLessThanOrEqual(words.count, 15, "最多 15 个")
}
func assertLessThanOrEqual<T: Comparable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    assert(a <= b, "\(message) — expected ≤ \(b), got \(a)", file: file, line: line)
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    // Edge: learned words from unlocked level supplement
    progressRepo.levelProgressMap[1] = true
    let (words, error) = spellChallengeStart(wordRepo: repo, progressRepo: progressRepo)
    assertNil(error, "unlocked level 1 supplement → 无 error")
    XCTAssertNotNil(words.first, "有来自 level 1 的补充单词")
}

// MARK: 4. MatchGame 配对消消乐
print("=== 4. MatchGame 配对消消乐 ===")

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    // New user → falls back to allWords (≥8 words)
    let (words, error) = matchGameStart(wordRepo: repo, progressRepo: progressRepo, levelId: nil)
    assertNil(error, "新用户 fallback → 无 errorMessage")
    assertEqual(words.count, 8, "配对需要 8 个单词")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    // By level: level 1 has 15 words → enough
    progressRepo.simulateOnboarding()
    let (words, error) = matchGameStart(wordRepo: repo, progressRepo: progressRepo, levelId: 1)
    assertNil(error, "Level 1 配对 → 无 errorMessage")
    assertEqual(words.count, 8, "Level 1 配对 8 个单词")
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    // All 25 levels
    for level in 1...25 {
        let (words, error) = matchGameStart(wordRepo: repo, progressRepo: progressRepo, levelId: level)
        assertNil(error, "Level \(level) 配对 → 无 errorMessage")
        assertEqual(words.count, 8, "Level \(level) 配对 8 个单词")
    }
}

do {
    let repo = WordRepository(words: allWords)
    let progressRepo = ProgressRepository()
    // With learned words (no need for fallback)
    for id in 1...15 {
        var wp = WordProgress.initial(wordId: id)
        wp.mastery = .learning
        progressRepo.updateWordProgress(wp)
    }
    let (words, error) = matchGameStart(wordRepo: repo, progressRepo: progressRepo, levelId: nil)
    assertNil(error, "有 learned words → 无 errorMessage")
    assertGreaterThan(words.count, 0, "有单词")
}

// MARK: 5. Question quality validation
print("=== 5. Question 质量验证 ===")

do {
    let repo = WordRepository(words: allWords)
    for level in 1...25 {
        let levelWords = repo.words(forLevel: level)
        for word in levelWords.prefix(5) {
            let q = Question.create(word: word, type: .selectMeaning, allWords: repo.allWords)
            assert(q.options.count == 4, "Level \(level) word \(word.text) selectMeaning 4 选项")
            assert(q.options.contains(word.meaning), "Level \(level) 包含正确 meaning")
            // No duplicate options
            assertEqual(Set(q.options).count, 4, "Level \(level) word \(word.text) 选项无重复")
        }
    }
}

do {
    let repo = WordRepository(words: allWords)
    for level in 1...25 {
        let levelWords = repo.words(forLevel: level)
        for word in levelWords.prefix(5) {
            let q = Question.create(word: word, type: .selectWord, allWords: repo.allWords)
            assert(q.options.count == 4, "Level \(level) word \(word.text) selectWord 4 选项")
            assert(q.options.contains(word.text), "Level \(level) 包含正确 text")
            assertEqual(Set(q.options).count, 4, "选项无重复")
        }
    }
}

// MARK: 6. Empty data protection (regression from P0 fix)
print("=== 6. 空数据保护回归 ===")

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    let (_, error) = gamePlayStartLevel(wordRepo: emptyRepo, progressRepo: progressRepo, levelId: 1)
    assertEqual(error, "暂无题目数据", "空 repo startLevel → error")
}

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    let (_, error) = gamePlayStartMistakeReview(wordRepo: emptyRepo, progressRepo: progressRepo)
    assertEqual(error, "暂无错题", "空 repo startMistakeReview → error")
}

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    let (words, error) = spellChallengeStart(wordRepo: emptyRepo, progressRepo: progressRepo)
    assertEqual(error, "暂无题目数据", "空 repo spellChallenge → error")
}

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    let (words, error) = matchGameStart(wordRepo: emptyRepo, progressRepo: progressRepo, levelId: nil)
    assertEqual(error, "暂无题目数据", "空 repo matchGame → error")
}

// MARK: Results
print("\n" + String(repeating: "=", count: 50))
print("完整功能测试结果: \(passed) passed, \(failed) failed")
if !errors.isEmpty {
    print("\nFAILURES:")
    for e in errors { print("  \(e)") }
}
exit(failed > 0 ? 1 : 0)
