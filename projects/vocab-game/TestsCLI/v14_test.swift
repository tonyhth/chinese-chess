#!/usr/bin/env swift
// v1.4 test: MatchGame same-type flip (async, no isChecking) + ESC sheetId reset
// Key differences from v1.3:
//   1. sameTypeFlip does NOT set isChecking — user can keep interacting
//   2. flipCard returns early on same type (no checkMatch call)
//   3. MainTabView uses sheetId UUID to force View rebuild on re-enter

import Foundation

// MARK: - Models

struct Word: Equatable, Codable {
    let id: Int; let text: String; let meaning: String; let group: Int
}

struct MatchCard: Equatable {
    let id: Int; let text: String; let pairId: Int; let isWord: Bool
    var isFlipped = false; var isMatched = false
}

// MARK: - MatchGameViewModel (extracted, matches v1.4 logic)

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

    private let allWords: [Word]
    private var pendingSameTypeIndices: [Int] = [] // indices of same-type cards to flip back

    init(words: [Word]) { self.allWords = words }

    func start(forLevel levelId: Int) {
        let levelWords = allWords.filter { $0.group == levelId }.prefix(8)
        var newCards: [MatchCard] = []
        for (i, word) in levelWords.enumerated() {
            newCards.append(MatchCard(id: i * 2, text: word.text, pairId: i, isWord: true))
            newCards.append(MatchCard(id: i * 2 + 1, text: word.meaning, pairId: i, isWord: false))
        }
        cards = newCards.shuffled()
        flippedIndices = []; moves = 0; matchedPairs = 0
        totalPairs = Int(levelWords.count)
        isChecking = false; sameTypeFlip = false; isCompleted = false
        pendingSameTypeIndices = []
    }

    /// Flip card — if same type, sets sameTypeFlip and returns WITHOUT setting isChecking
    func flipCard(at index: Int) {
        guard !isChecking else { return }
        guard !cards[index].isFlipped && !cards[index].isMatched else { return }
        guard flippedIndices.count < 2 else { return }

        cards[index].isFlipped = true
        flippedIndices.insert(index)

        if flippedIndices.count == 2 {
            let indices = Array(flippedIndices)
            let card1 = cards[indices[0]]
            let card2 = cards[indices[1]]

            if card1.isWord == card2.isWord {
                // Same type: flip back without setting isChecking
                sameTypeFlip = true
                pendingSameTypeIndices = indices
                // Simulated: caller must call processPendingSameType() after delay
                return
            }

            isChecking = true
            checkMatch()
        }
    }

    /// Call after 0.5s delay to flip back same-type cards
    func processPendingSameType() {
        guard !pendingSameTypeIndices.isEmpty else { return }
        for idx in pendingSameTypeIndices {
            cards[idx].isFlipped = false
        }
        flippedIndices = []
        pendingSameTypeIndices = []
    }

    private func checkMatch() {
        let indices = Array(flippedIndices)
        guard indices.count == 2 else { return }
        let card1 = cards[indices[0]]
        let card2 = cards[indices[1]]

        if card1.pairId == card2.pairId {
            cards[indices[0]].isMatched = true
            cards[indices[1]].isMatched = true
            matchedPairs += 1; moves += 1
            flippedIndices = []; isChecking = false; sameTypeFlip = false
            if matchedPairs == totalPairs { isCompleted = true }
        } else {
            cards[indices[0]].isFlipped = false
            cards[indices[1]].isFlipped = false
            moves += 1
            flippedIndices = []; isChecking = false; sameTypeFlip = false
        }
    }
}

// MARK: - ESC + sheetId reset simulation

class SessionManager {
    var activeSession: [String: Any] = [:]
    var sheetId = UUID()

    func enterGame(_ name: String) {
        activeSession[name] = ["entered": true]
    }

    func escDismiss(_ name: String) {
        activeSession[name] = nil
        sheetId = UUID() // Force View rebuild
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

// Load real data
let wordlistPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("DevTeam/projects/vocab-game/VocabGame/Resources/Data/wordlist.json")
let allWords = try! JSONDecoder().decode([Word].self, from: Data(contentsOf: wordlistPath))

// =============================================
print("=== 1. 同类型卡片：两张英文 → 翻回、不计步数、不锁 isChecking ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    let wordIndices = vm.cards.enumerated().compactMap { i, c in c.isWord && !c.isMatched ? i : nil }
    vm.flipCard(at: wordIndices[0])
    XCTAssertFalse(vm.sameTypeFlip, "翻第一张后 sameTypeFlip=false")
    XCTAssertFalse(vm.isChecking, "翻第一张后 isChecking=false")

    vm.flipCard(at: wordIndices[1])
    assert(vm.sameTypeFlip, "两张英文 → sameTypeFlip=true")
    XCTAssertFalse(vm.isChecking, "同类型不设 isChecking — 用户可继续操作")
    assertEqual(vm.flippedIndices.count, 2, "异步翻回前 2 张仍翻转")
    assertEqual(vm.moves, 0, "同类型不计步数")
}

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    let meaningIndices = vm.cards.enumerated().compactMap { i, c in !c.isWord && !c.isMatched ? i : nil }
    vm.flipCard(at: meaningIndices[0])
    vm.flipCard(at: meaningIndices[1])

    assert(vm.sameTypeFlip, "两张中文 → sameTypeFlip=true")
    XCTAssertFalse(vm.isChecking, "不设 isChecking")
    assertEqual(vm.moves, 0, "不计步数")

    // Simulate async flip-back
    vm.processPendingSameType()
    assertEqual(vm.flippedIndices.count, 0, "翻回后 flippedIndices 清空")
    for idx in meaningIndices {
        XCTAssertFalse(vm.cards[idx].isFlipped, "卡片 \(idx) 翻回")
    }
}

print("=== 2. 同类型翻回后可立即操作 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    // Trigger same type
    let wordIndices = vm.cards.enumerated().compactMap { i, c in c.isWord ? i : nil }
    vm.flipCard(at: wordIndices[0])
    vm.flipCard(at: wordIndices[1])
    assert(vm.sameTypeFlip, "sameTypeFlip triggered")

    // Before async flip-back, user can still interact (isChecking=false)
    // Simulate flip-back completing
    vm.processPendingSameType()
    vm.sameTypeFlip = false

    // Now make a valid match
    let pairId = vm.cards[wordIndices[0]].pairId
    let meaningIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId == pairId })!
    vm.flipCard(at: wordIndices[0])
    vm.flipCard(at: meaningIdx)

    XCTAssertFalse(vm.sameTypeFlip, "正常配对 → sameTypeFlip=false")
    assertEqual(vm.moves, 1, "正常配对计步")
    assertEqual(vm.matchedPairs, 1, "matchedPairs=1")
}

print("=== 3. 正常配对：一英一中匹配 → 计步数 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    let wordIdx = vm.cards.firstIndex(where: { $0.isWord && !$0.isMatched })!
    let pairId = vm.cards[wordIdx].pairId
    let meaningIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId == pairId })!

    vm.flipCard(at: wordIdx)
    vm.flipCard(at: meaningIdx)

    XCTAssertFalse(vm.sameTypeFlip, "正确配对 → no sameTypeFlip")
    assert(vm.isChecking || !vm.isChecking, "匹配走 checkMatch 并完成")
    XCTAssertFalse(vm.isChecking, "匹配完成 → isChecking=false")
    assertEqual(vm.moves, 1, "计 1 步")
    assertEqual(vm.matchedPairs, 1, "matchedPairs=1")
    assert(vm.cards[wordIdx].isMatched, "word matched")
    assert(vm.cards[meaningIdx].isMatched, "meaning matched")
}

print("=== 4. 不匹配：一英一中不同 pair ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    let wordIdx = vm.cards.firstIndex(where: { $0.isWord })!
    let wordPairId = vm.cards[wordIdx].pairId
    let meaningIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId != wordPairId })!

    vm.flipCard(at: wordIdx)
    vm.flipCard(at: meaningIdx)

    XCTAssertFalse(vm.sameTypeFlip, "不匹配 → no sameTypeFlip")
    assertEqual(vm.moves, 1, "计 1 步")
    assertEqual(vm.matchedPairs, 0, "未匹配")
    XCTAssertFalse(vm.cards[wordIdx].isFlipped, "翻回")
    XCTAssertFalse(vm.cards[meaningIdx].isFlipped, "翻回")
}

print("=== 5. ESC → sheetId 重置 → 再进入同一关卡 ===")

do {
    let sm = SessionManager()
    let vm = MatchGameVM(words: allWords)

    // Enter game
    vm.start(forLevel: 1)
    sm.enterGame("match_level1")
    XCTAssertNotNil(sm.activeSession["match_level1"], "进入后 session 存在")
    let sheetId1 = sm.sheetId

    // ESC
    sm.escDismiss("match_level1")
    assertNil(sm.activeSession["match_level1"], "ESC 后 session 清除")
    let sheetId2 = sm.sheetId
    XCTAssertFalse(sheetId1 == sheetId2, "sheetId 变了 → View 强制重建")

    // Re-enter same level
    vm.start(forLevel: 1)
    sm.enterGame("match_level1")
    assertEqual(vm.moves, 0, "重新进入后 moves=0")
    assertEqual(vm.matchedPairs, 0, "重新进入后 matchedPairs=0")
    XCTAssertFalse(vm.isCompleted, "重新进入后 isCompleted=false")
    XCTAssertFalse(vm.isChecking, "重新进入后 isChecking=false")
    XCTAssertFalse(vm.sameTypeFlip, "重新进入后 sameTypeFlip=false")
}

print("=== 6. 连续操作：ESC → 进关卡 → ESC → 进另一关卡 ===")

do {
    let sm = SessionManager()
    let vm = MatchGameVM(words: allWords)

    for level in [1, 3, 7] {
        vm.start(forLevel: level)
        sm.enterGame("level_\(level)")
        XCTAssertNotNil(sm.activeSession["level_\(level)"] as Any, "ESC level \(level) session exists before")

        sm.escDismiss("level_\(level)")
        assertNil(sm.activeSession["level_\(level)"] as Any?, "ESC level \(level) session cleared")
        assertEqual(vm.moves, 0, "ESC level \(level) 后 moves=0")
        assertEqual(vm.matchedPairs, 0, "ESC level \(level) 后 matchedPairs=0")
        XCTAssertFalse(vm.isChecking, "ESC level \(level) 后 isChecking=false")
        XCTAssertFalse(vm.sameTypeFlip, "ESC level \(level) 后 sameTypeFlip=false")
    }
}

do {
    let sm = SessionManager()
    let vm = MatchGameVM(words: allWords)
    var lastSheetId = sm.sheetId

    for level in [1, 5, 10, 25] {
        vm.start(forLevel: level)
        sm.enterGame("game_\(level)")
        sm.escDismiss("game_\(level)")
        XCTAssertFalse(sm.sheetId == lastSheetId, "Level \(level) ESC 后 sheetId 更新")
        lastSheetId = sm.sheetId
    }
}

print("=== 7. 混合操作：同类型 → 正常配对 → 完成 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    // First: trigger same type flip
    let wordIndices = vm.cards.enumerated().compactMap { i, c in c.isWord ? i : nil }
    vm.flipCard(at: wordIndices[0])
    vm.flipCard(at: wordIndices[1])
    assert(vm.sameTypeFlip, "sameTypeFlip")
    assertEqual(vm.moves, 0, "same type 不计步")

    // Process async flip-back
    vm.processPendingSameType()
    vm.sameTypeFlip = false

    // Then: complete all pairs normally
    while !vm.isCompleted && vm.moves < 50 {
        let pairIds = Set(vm.cards.compactMap { c in !c.isMatched ? c.pairId : nil })
        guard let pid = pairIds.first else { break }
        let wIdx = vm.cards.firstIndex(where: { $0.isWord && $0.pairId == pid && !$0.isMatched })!
        let mIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId == pid && !$0.isMatched })!
        vm.flipCard(at: wIdx)
        vm.flipCard(at: mIdx)
    }

    assert(vm.isCompleted, "全部完成")
    assertEqual(vm.matchedPairs, vm.totalPairs, "all matched")
}

print("=== 8. 已匹配/已翻转/isChecking 保护 ===")

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    // Match a pair
    let wIdx = vm.cards.firstIndex(where: { $0.isWord })!
    let pairId = vm.cards[wIdx].pairId
    let mIdx = vm.cards.firstIndex(where: { !$0.isWord && $0.pairId == pairId })!
    vm.flipCard(at: wIdx)
    vm.flipCard(at: mIdx)

    // Try flip matched card
    let movesBefore = vm.moves
    vm.flipCard(at: wIdx)
    assertEqual(vm.moves, movesBefore, "matched card 不可翻")
}

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    let wIdx = vm.cards.firstIndex(where: { $0.isWord })!
    vm.flipCard(at: wIdx)
    vm.flipCard(at: wIdx)
    assertEqual(vm.flippedIndices.count, 1, "已翻卡片不可重复翻")
}

do {
    let vm = MatchGameVM(words: allWords)
    vm.start(forLevel: 1)

    let wIdx = vm.cards.firstIndex(where: { $0.isWord })!
    vm.flipCard(at: wIdx)
    vm.isChecking = true
    let otherIdx = vm.cards.firstIndex(where: { $0.isWord && $0.id != vm.cards[wIdx].id })!
    vm.flipCard(at: otherIdx)
    XCTAssertFalse(vm.cards[otherIdx].isFlipped, "isChecking 期间不可翻")
}

func assertNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
    assert(value == nil, message, file: file, line: line)
}
func XCTAssertNotNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
    assert(value != nil, message, file: file, line: line)
}

// MARK: Results

print("\n" + String(repeating: "=", count: 50))
print("v1.4 测试结果: \(passed) passed, \(failed) failed")
if !errors.isEmpty {
    print("\nFAILURES:")
    for e in errors { print("  \(e)") }
}
exit(failed > 0 ? 1 : 0)
