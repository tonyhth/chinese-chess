#!/usr/bin/env swift
// Standalone test runner for empty-data feedback fix validation
// Compiles and runs without Xcode project dependencies

import Foundation

// MARK: - Minimal model stubs (matching VocabGame)

struct Word: Equatable {
    let id: Int
    let text: String
    let meaning: String
    let group: Int
}

enum MasteryLevel: Int {
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

// MARK: - Minimal repository stubs (matching actual behavior)

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
    var levelProgressMap: [Int: Bool] = [:] // levelId → isUnlocked

    func updateWordProgress(_ wp: WordProgress) {
        wordProgressMap[wp.wordId] = wp
    }

    func wordProgress(for wordId: Int) -> WordProgress {
        wordProgressMap[wordId] ?? .initial(wordId: wordId)
    }

    func mistakeWords() -> [WordProgress] {
        wordProgressMap.values.filter { $0.wrongCount > 0 }
    }

    func isLevelUnlocked(_ levelId: Int) -> Bool {
        levelProgressMap[levelId] ?? false
    }
}

// MARK: - Test engine

var passed = 0
var failed = 0
var errors: [String] = []

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        errors.append("FAIL: \(message) (line \(line))")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    assert(a == b, "\(message) — expected \(b), got \(a)", file: file, line: line)
}

// MARK: - SpellChallengeViewModel start() logic (extracted)

func spellChallengeStart(wordRepo: WordRepository, progressRepo: ProgressRepository) -> (words: [Word], errorMessage: String?) {
    var words: [Word] = []

    let learned = progressRepo.wordProgressMap.values
        .filter { $0.mastery.rawValue >= MasteryLevel.learning.rawValue }
    let allWords = wordRepo.allWords
    words = learned.compactMap { wp -> Word? in
        allWords.first(where: { $0.id == wp.wordId })
    }.shuffled()

    if words.count < 10 {
        let learnedIds = Set(words.map { $0.id })
        let unlockedLevels = (1...25).filter { progressRepo.isLevelUnlocked($0) }
        let supplemental = unlockedLevels.flatMap { wordRepo.words(forLevel: $0) }
            .filter { !learnedIds.contains($0.id) }
            .shuffled()
        words.append(contentsOf: supplemental.prefix(10 - words.count))
    }

    words = Array(words.prefix(15))
    if words.isEmpty {
        words = Array(wordRepo.allWords.shuffled().prefix(10))
    }
    if words.isEmpty {
        return (words, "暂无题目数据")
    }

    words.shuffle()
    return (words, nil)
}

// MARK: - MatchGameViewModel start() logic (extracted)

func matchGameStart(wordRepo: WordRepository, progressRepo: ProgressRepository, levelId: Int?) -> (words: [Word], errorMessage: String?) {
    var candidates: [Word]

    if let levelId = levelId {
        let levelWords = wordRepo.words(forLevel: levelId)
        let unmastered = levelWords.filter { wp in
            let p = progressRepo.wordProgress(for: wp.id)
            return p.mastery != .mastered
        }
        candidates = unmastered.isEmpty ? levelWords : unmastered
    } else {
        let mistakes = progressRepo.mistakeWords()
        let mistakeWords = mistakes.compactMap { wp in
            wordRepo.allWords.first(where: { $0.id == wp.wordId })
        }
        let learned = progressRepo.wordProgressMap.values
            .filter { $0.mastery.rawValue >= MasteryLevel.learning.rawValue }
            .compactMap { wp in wordRepo.allWords.first(where: { $0.id == wp.wordId }) }

        candidates = mistakeWords
        candidates.append(contentsOf: learned.filter { w in
            !candidates.contains(where: { $0.id == w.id })
        })
    }

    let selected = Array(candidates.shuffled().prefix(8))
    guard selected.count >= 4 else {
        candidates = wordRepo.allWords.shuffled()
        let fallback = Array(candidates.prefix(8))
        if fallback.isEmpty {
            return ([], "暂无题目数据")
        }
        return (fallback, nil)
    }
    return (selected, nil)
}

// MARK: - GamePlayView startLevel() logic (extracted)

func gamePlayStartLevel(wordRepo: WordRepository, progressRepo: ProgressRepository, levelId: Int) -> (selected: [Word], errorMessage: String?) {
    let words = wordRepo.words(forLevel: levelId).shuffled()
    let allWords = wordRepo.allWords
    let selected = Array(words.prefix(10))

    guard !selected.isEmpty else {
        return ([], "暂无题目数据")
    }
    return (selected, nil)
}

// MARK: - GamePlayView startMistakeReview() logic (extracted)

func gamePlayStartMistakeReview(wordRepo: WordRepository, progressRepo: ProgressRepository) -> (questions: Int, errorMessage: String?) {
    let mistakes = progressRepo.mistakeWords()
    let allWords = wordRepo.allWords
    var count = 0
    for wp in mistakes.prefix(10) {
        guard let _ = allWords.first(where: { $0.id == wp.wordId }) else { continue }
        count += 1
    }
    if count > 0 {
        return (count, nil)
    } else {
        return (0, "暂无错题")
    }
}

// =============================================
// MARK: - TESTS
// =============================================

let sampleWords = (1...20).map { i in
    Word(id: i, text: "word\(i)", meaning: "meaning\(i)", group: (i - 1) / 5 + 1)
}

// MARK: SpellChallengeViewModel Tests

print("=== SpellChallengeViewModel ===")

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    let result = spellChallengeStart(wordRepo: emptyRepo, progressRepo: progressRepo)
    assertEqual(result.errorMessage, "暂无题目数据", "SCVM: empty wordRepo sets errorMessage")
    assert(result.words.isEmpty, "SCVM: empty wordRepo has empty words")
}

do {
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    for w in sampleWords {
        var wp = WordProgress.initial(wordId: w.id)
        wp.mastery = .learning
        progressRepo.updateWordProgress(wp)
    }
    let result = spellChallengeStart(wordRepo: wordRepo, progressRepo: progressRepo)
    assertNil(result.errorMessage, "SCVM: has learned words → no errorMessage")
    assert(!result.words.isEmpty, "SCVM: has learned words → words populated")
}
func assertNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
    assert(value == nil, message, file: file, line: line)
}

do {
    // No learned words, no unlocked levels → fallback to allWords
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    let result = spellChallengeStart(wordRepo: wordRepo, progressRepo: progressRepo)
    assertNil(result.errorMessage, "SCVM: no learned but has allWords → no errorMessage (fallback)")
    assert(!result.words.isEmpty, "SCVM: no learned but has allWords → words populated (fallback)")
}

do {
    // No learned words, no unlocked levels, empty allWords → error
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    // unlock some levels but repo still empty
    progressRepo.levelProgressMap[1] = true
    let result = spellChallengeStart(wordRepo: emptyRepo, progressRepo: progressRepo)
    assertEqual(result.errorMessage, "暂无题目数据", "SCVM: unlocked levels but empty repo → errorMessage")
}

// MARK: MatchGameViewModel Tests

print("=== MatchGameViewModel ===")

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    let result = matchGameStart(wordRepo: emptyRepo, progressRepo: progressRepo, levelId: nil)
    assertEqual(result.errorMessage, "暂无题目数据", "MGVM: empty wordRepo sets errorMessage")
    assert(result.words.isEmpty, "MGVM: empty wordRepo has empty words")
}

do {
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    for w in sampleWords {
        var wp = WordProgress.initial(wordId: w.id)
        wp.mastery = .learning
        progressRepo.updateWordProgress(wp)
    }
    let result = matchGameStart(wordRepo: wordRepo, progressRepo: progressRepo, levelId: nil)
    assertNil(result.errorMessage, "MGVM: has learned words → no errorMessage")
    assert(!result.words.isEmpty, "MGVM: has learned words → words populated")
}

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    let result = matchGameStart(wordRepo: emptyRepo, progressRepo: progressRepo, levelId: 1)
    assertEqual(result.errorMessage, "暂无题目数据", "MGVM: forLevel empty repo → errorMessage")
}

do {
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    for w in sampleWords {
        var wp = WordProgress.initial(wordId: w.id)
        wp.mastery = .learning
        progressRepo.updateWordProgress(wp)
    }
    let result = matchGameStart(wordRepo: wordRepo, progressRepo: progressRepo, levelId: 1)
    assertNil(result.errorMessage, "MGVM: forLevel with data → no errorMessage")
    assert(!result.words.isEmpty, "MGVM: forLevel with data → words populated")
}

do {
    // Only 3 learned words (< 4 threshold) → fallback
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    for w in sampleWords.prefix(3) {
        var wp = WordProgress.initial(wordId: w.id)
        wp.mastery = .learning
        progressRepo.updateWordProgress(wp)
    }
    let result = matchGameStart(wordRepo: wordRepo, progressRepo: progressRepo, levelId: nil)
    assertNil(result.errorMessage, "MGVM: few learned words falls back to allWords → no error")
    XCTAssertFalse(result.words.isEmpty, "MGVM: few learned words falls back → words populated")
}
func XCTAssertFalse(_ cond: Bool, _ message: String, file: String = #file, line: Int = #line) {
    assert(!cond, message, file: file, line: line)
}

// MARK: GamePlayView Tests

print("=== GamePlayView ===")

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    let result = gamePlayStartLevel(wordRepo: emptyRepo, progressRepo: progressRepo, levelId: 1)
    assertEqual(result.errorMessage, "暂无题目数据", "GPV: empty wordRepo startLevel → errorMessage")
    assert(result.selected.isEmpty, "GPV: empty wordRepo startLevel → empty selected")
}

do {
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    let result = gamePlayStartLevel(wordRepo: wordRepo, progressRepo: progressRepo, levelId: 1)
    assertNil(result.errorMessage, "GPV: has words startLevel → no errorMessage")
    assert(!result.selected.isEmpty, "GPV: has words startLevel → selected populated")
}

do {
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    let result = gamePlayStartLevel(wordRepo: wordRepo, progressRepo: progressRepo, levelId: 99)
    assertEqual(result.errorMessage, "暂无题目数据", "GPV: level 99 has no words → errorMessage")
}

do {
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    let result = gamePlayStartMistakeReview(wordRepo: wordRepo, progressRepo: progressRepo)
    assertEqual(result.errorMessage, "暂无错题", "GPV: no mistakes → errorMessage '暂无错题'")
}

do {
    let wordRepo = WordRepository(words: sampleWords)
    let progressRepo = ProgressRepository()
    var wp = WordProgress.initial(wordId: 1)
    wp.wrongCount = 2
    progressRepo.updateWordProgress(wp)
    let result = gamePlayStartMistakeReview(wordRepo: wordRepo, progressRepo: progressRepo)
    assertNil(result.errorMessage, "GPV: has mistakes → no errorMessage")
    assert(result.questions > 0, "GPV: has mistakes → questions generated")
}

do {
    let emptyRepo = WordRepository(words: [])
    let progressRepo = ProgressRepository()
    var wp = WordProgress.initial(wordId: 1)
    wp.wrongCount = 2
    progressRepo.updateWordProgress(wp)
    let result = gamePlayStartMistakeReview(wordRepo: emptyRepo, progressRepo: progressRepo)
    // Mistake exists but word not in repo → questions = 0
    assertEqual(result.errorMessage, "暂无错题", "GPV: mistake word not in repo → errorMessage")
}

// MARK: - Results

print("\n" + String(repeating: "=", count: 50))
print("TEST RESULTS: \(passed) passed, \(failed) failed")
if !errors.isEmpty {
    print("\nFAILURES:")
    for e in errors {
        print("  \(e)")
    }
}
exit(failed > 0 ? 1 : 0)
