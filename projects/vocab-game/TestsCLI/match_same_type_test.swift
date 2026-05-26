#!/usr/bin/env swift
// MatchGame same-type card flip test + ESC regression for v1.2 merged build

import Foundation

// MARK: - Models

struct Word: Equatable, Codable {
    let id: Int; let text: String; let meaning: String; let group: Int
}

struct MatchCard: Equatable {
    let id: Int; let text: String; let pairId: Int; let isWord: Bool
    var isFlipped = false; var isMatched = false
}

// MARK: - ViewModel logic (extracted)

class MatchGameVM {
    var cards: [MatchCard] = []
    var flippedIndices: Set<Int> = []
    var moves = 0
    var matchedPairs = 0
    var totalPairs = 0
    var isChecking = false
    var sameTypeFlip = false
    var isCompleted = false
    var remainingSeconds = 60

    private let wordRepo: [Word]

    init(words: [Word]) {
        self.wordRepo = words
    }

    func start(forLevel levelId: Int) {
        let levelWords = wordRepo.filter { $0.group == levelId }.prefix(8)
        var newCards: [MatchCard] = []
        for (i, word) in levelWords.enumerated() {
            newCards.append(MatchCard(id: i * 2, text: word.text, pairId: i, isWord: true))
            newCards.append(MatchCard(id: i * 2 + 1, text: word.meaning, pairId: i, isWord: false))
        }
        cards = newCards.shuffled()
        flippedIndices = []; moves = 0; matchedPairs = 0
        totalPairs = levelWords.count; isChecking = false; sameTypeFlip = false; isCompleted = false
    }

    func flipCard(at index: Int) {
        guard !isChecking else { return }
        guard !cards[index].isFlipped && !cards[index].isMatched else { return }
        guard flippedIndices.count < 2 else { return }

        cards[index].isFlipped = true
        flippedIndices.insert(index)

        if flippedIndices.count == 2 {
            isChecking = true
            checkMatch()
        }
    }

    func checkMatch() {
        let indices = Array(flippedIndices)
        guard indices.count == 2 else { return }
        let card1 = cards[indices[0]]
        let card2 = cards[indices[1]]

        if card1.isWord == card2.isWord {
            // Same type: flip back, no move counted
            cards[indices[0]].isFlipped = false
            cards[indices[1]].isFlipped = false
            flippedIndices = []; isChecking = false; sameTypeFlip = true
        } else if card1.pairId == card2.pairId {
            // Match!
            cards[indices[0]].isMatched = true
            cards[indices[1]].isMatched = true
            matchedPairs += 1; moves += 1
            flippedIndices = []; isChecking = false; sameTypeFlip = false
            if matchedPairs == totalPairs { isCompleted = true }
        } else {
            // Mismatch
            cards[indices[0]].isFlipped = false
            cards[indices[1]].isFlipped = false
            moves += 1
            flippedIndices = []; isChecking = false; sameTypeFlip = false
        }
    }
}

// MARK: - Test engine

var passed = 0; var failed = 0; var errors: [String] = []

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 } else { failed += 1; errors.append("FAIL: \(message) (line \(line))") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    assert(a == b, "\(message) — expected \(b), got \(a)", file: file, line: line)
}
func XCTAssertFalse(_ cond: Bool, _ message: String, file: String = #file, line: Int = #line) {
    assert(!cond, message, file: file, line: line)
}

// Load data
let wordlistPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("DevTeam/projects/vocab-game/VocabGame/Resources/Data/wordlist.json")
let allWords = try! JSONDecoder().decode([Word].self, from: Data(contentsOf: wordlistPath))

// =============================================
print("=== 1. 同类型卡片：两张英文 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)
    assertEqual(vm.cards.count, 16, "8 对 = 16 张卡片")

    // Find two word cards (isWord = true)
    let wordIndices = vm.cards.enumerated().compactMap { i, c in c.isWord && !c.isMatched ? i : nil }
    guard wordIndices.count >= 2 else { fatalError("Need at least 2 word cards") }

    vm.flipCard(at: wordIndices[0])
    XCTAssertFalse(vm.sameTypeFlip, "翻第一张后 sameTypeFlip=false")
    XCTAssertFalse(vm.isChecking, "翻第一张后 isChecking=false")
    assertEqual(vm.flippedIndices.count, 1, "翻第一张后 1 张翻转")

    vm.flipCard(at: wordIndices[1])
    // After flipCard → checkMatch fires synchronously in our model
    assert(vm.sameTypeFlip, "两张英文 → sameTypeFlip=true")
    XCTAssertFalse(vm.isChecking, "翻回后 isChecking=false")
    assertEqual(vm.flippedIndices.count, 0, "翻回后 无翻转卡片")
    assertEqual(vm.moves, 0, "同类型不计步数")
}

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    // Find two meaning cards
    let meaningIndices = vm.cards.enumerated().compactMap { i, c in !c.isWord && !c.isMatched ? i : nil }
    vm.flipCard(at: meaningIndices[0])
    vm.flipCard(at: meaningIndices[1])

    assert(vm.sameTypeFlip, "两张中文 → sameTypeFlip=true")
    assertEqual(vm.moves, 0, "两张中文不计步数")
}

print("=== 2. 正常配对：一英一中匹配 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    // Find a word card and its matching meaning card (same pairId)
    let wordIdx = vm.cards.firstIndex(where: { $0.isWord && !$0.isMatched })!
    let pairId = vm.cards[wordIdx].pairId
    let meaningIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId == pairId })!

    vm.flipCard(at: wordIdx)
    vm.flipCard(at: meaningIdx)

    XCTAssertFalse(vm.sameTypeFlip, "正确配对 → sameTypeFlip=false")
    assertEqual(vm.moves, 1, "正确配对计 1 步")
    assertEqual(vm.matchedPairs, 1, "matchedPairs=1")
    XCTAssertFalse(vm.isChecking, "匹配后 isChecking=false")
    assert(vm.cards[wordIdx].isMatched, "word card 标记已匹配")
    assert(vm.cards[meaningIdx].isMatched, "meaning card 标记已匹配")
}

print("=== 3. 不匹配：一英一中但不同 pairId ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    let wordIdx = vm.cards.firstIndex(where: { $0.isWord })!
    let wordPairId = vm.cards[wordIdx].pairId
    let meaningIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId != wordPairId })!

    vm.flipCard(at: wordIdx)
    vm.flipCard(at: meaningIdx)

    XCTAssertFalse(vm.sameTypeFlip, "不匹配 → sameTypeFlip=false")
    assertEqual(vm.moves, 1, "不匹配计 1 步")
    assertEqual(vm.matchedPairs, 0, "matchedPairs=0")
    XCTAssertFalse(vm.cards[wordIdx].isFlipped, "word card 翻回")
    XCTAssertFalse(vm.cards[meaningIdx].isFlipped, "meaning card 翻回")
}

print("=== 4. sameTypeFlip 重置后可继续正常操作 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    // Trigger sameTypeFlip
    let wordIndices = vm.cards.enumerated().compactMap { i, c in c.isWord ? i : nil }
    vm.flipCard(at: wordIndices[0])
    vm.flipCard(at: wordIndices[1])
    assert(vm.sameTypeFlip, "sameTypeFlip triggered")

    // Reset (simulating View's onChange timer)
    vm.sameTypeFlip = false

    // Now make a valid match
    let pairId = vm.cards[wordIndices[0]].pairId
    let meaningIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId == pairId })!
    let wordIdx = wordIndices[0]

    vm.flipCard(at: wordIdx)
    vm.flipCard(at: meaningIdx)

    XCTAssertFalse(vm.sameTypeFlip, "重置后正常配对 → sameTypeFlip=false")
    assertEqual(vm.moves, 1, "正常配对计步")
    assertEqual(vm.matchedPairs, 1, "matchedPairs=1")
}

print("=== 5. 已匹配/已翻转卡片不可再翻 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    let wordIdx = vm.cards.firstIndex(where: { $0.isWord })!
    let pairId = vm.cards[wordIdx].pairId
    let meaningIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId == pairId })!

    // Match them
    vm.flipCard(at: wordIdx)
    vm.flipCard(at: meaningIdx)
    assert(vm.cards[wordIdx].isMatched, "word matched")

    // Try to flip matched card
    let movesBefore = vm.moves
    vm.flipCard(at: wordIdx)
    assertEqual(vm.moves, movesBefore, "已匹配卡片不可翻")
}

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    // Flip one card, then try to flip same card
    let wordIdx = vm.cards.firstIndex(where: { $0.isWord })!
    vm.flipCard(at: wordIdx)
    vm.flipCard(at: wordIdx)
    assertEqual(vm.flippedIndices.count, 1, "已翻转卡片不可重复翻")
}

print("=== 6. isChecking 期间不可操作 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    // Manually set isChecking (simulating async delay)
    let wordIdx = vm.cards.firstIndex(where: { $0.isWord })!
    vm.flipCard(at: wordIdx)
    vm.isChecking = true // Simulate the delay before checkMatch completes

    let otherIdx = vm.cards.firstIndex(where: { $0.isWord && $0.id != vm.cards[wordIdx].id })!
    vm.flipCard(at: otherIdx)
    XCTAssertFalse(vm.cards[otherIdx].isFlipped, "isChecking 期间不可翻第三张")
}

print("=== 7. 完成全部配对 → isCompleted ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    while !vm.isCompleted && vm.moves < 100 {
        // Find an unmatched pair
        let pairIds = Set(vm.cards.compactMap { c in !c.isMatched ? c.pairId : nil })
        guard let pid = pairIds.first else { break }
        let wordIdx = vm.cards.firstIndex(where: { $0.isWord && $0.pairId == pid && !$0.isMatched })!
        let meaningIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId == pid && !$0.isMatched })!
        vm.flipCard(at: wordIdx)
        vm.flipCard(at: meaningIdx)
    }

    assert(vm.isCompleted, "全部配对完成 → isCompleted=true")
    assertEqual(vm.matchedPairs, vm.totalPairs, "matchedPairs == totalPairs")
    XCTAssertFalse(vm.isChecking, "完成后 isChecking=false")
}

// MARK: Results

print("\n" + String(repeating: "=", count: 50))
print("配对游戏 + 同类型卡片测试结果: \(passed) passed, \(failed) failed")
if !errors.isEmpty {
    print("\nFAILURES:")
    for e in errors { print("  \(e)") }
}
exit(failed > 0 ? 1 : 0)
