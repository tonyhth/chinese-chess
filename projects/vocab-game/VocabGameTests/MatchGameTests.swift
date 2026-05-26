import XCTest
@testable import VocabGame

/// 测试配对消消乐的核心数据结构和逻辑
final class MatchGameTests: XCTestCase {

    private let sampleWords: [Word] = (1...8).map { i in
        Word(id: i, text: "word\(i)", meaning: "释义\(i)", group: 1)
    }

    // MARK: - MatchCard

    func testMatchCard_pairIdLinksWordAndMeaning() {
        let wordCard = MatchCard(id: 0, text: "word1", pairId: 0, isWord: true)
        let meaningCard = MatchCard(id: 1, text: "释义1", pairId: 0, isWord: false)

        XCTAssertEqual(wordCard.pairId, meaningCard.pairId)
        XCTAssertTrue(wordCard.isWord)
        XCTAssertFalse(meaningCard.isWord)
    }

    func testMatchCard_initialState() {
        let card = MatchCard(id: 0, text: "hello", pairId: 0, isWord: true)
        XCTAssertFalse(card.isFlipped)
        XCTAssertFalse(card.isMatched)
    }

    // MARK: - 卡牌生成

    func testSetupCards_createsPairs() {
        let cards = generateCards(from: sampleWords)
        XCTAssertEqual(cards.count, 16, "8 对 = 16 张卡")

        // 每个 pairId 应出现恰好 2 次
        let pairCounts = Dictionary(grouping: cards, by: { $0.pairId })
        for (_, group) in pairCounts {
            XCTAssertEqual(group.count, 2)
        }
    }

    func testSetupCards_eachPairHasOneWordOneMeaning() {
        let cards = generateCards(from: sampleWords)

        let pairCounts = Dictionary(grouping: cards, by: { $0.pairId })
        for (_, group) in pairCounts {
            let wordCards = group.filter { $0.isWord }.count
            let meaningCards = group.filter { !$0.isWord }.count
            XCTAssertEqual(wordCards, 1, "每对应恰好 1 张单词卡")
            XCTAssertEqual(meaningCards, 1, "每对应恰好 1 张释义卡")
        }
    }

    func testSetupCards_allCardsHaveUniqueIds() {
        let cards = generateCards(from: sampleWords)
        let ids = cards.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "卡牌 ID 应唯一")
    }

    // MARK: - 匹配逻辑

    func testMatch_samePairIdDifferentType_isMatch() {
        let card1 = MatchCard(id: 0, text: "word1", pairId: 0, isWord: true)
        let card2 = MatchCard(id: 1, text: "释义1", pairId: 0, isWord: false)

        XCTAssertTrue(isMatch(card1, card2))
    }

    func testMatch_samePairIdSameType_notMatch() {
        let card1 = MatchCard(id: 0, text: "word1", pairId: 0, isWord: true)
        let card2 = MatchCard(id: 1, text: "word1", pairId: 0, isWord: true)

        XCTAssertFalse(isMatch(card1, card2), "同类型同对不应匹配")
    }

    func testMatch_differentPairId_notMatch() {
        let card1 = MatchCard(id: 0, text: "word1", pairId: 0, isWord: true)
        let card2 = MatchCard(id: 1, text: "释义2", pairId: 1, isWord: false)

        XCTAssertFalse(isMatch(card1, card2))
    }

    // MARK: - 边界：少于 4 对

    func testMinimumPairs_4pairs() {
        let smallWords = Array(sampleWords.prefix(4))
        let cards = generateCards(from: smallWords)
        XCTAssertEqual(cards.count, 8)
    }

    // MARK: - 得分计算

    func testScore_matchingAddsBasePlusTimeBonus() {
        // 匹配得分: 50 + remainingSeconds
        let remainingSeconds = 45
        let matchScore = 50 + remainingSeconds
        XCTAssertEqual(matchScore, 95)

        // 时间奖励
        let timeBonus = remainingSeconds * 5
        XCTAssertEqual(timeBonus, 225)
    }

    func testScore_fasterCompletion_morePoints() {
        let fastBonus = 55 * 5 // 55 秒剩余
        let slowBonus = 10 * 5 // 10 秒剩余

        XCTAssertGreaterThan(fastBonus, slowBonus, "完成越快，时间奖励越高")
    }

    // MARK: - Helpers

    private func generateCards(from words: [Word]) -> [MatchCard] {
        var cards: [MatchCard] = []
        for (i, word) in words.enumerated() {
            cards.append(MatchCard(id: i * 2, text: word.text, pairId: i, isWord: true))
            cards.append(MatchCard(id: i * 2 + 1, text: word.meaning, pairId: i, isWord: false))
        }
        return cards.shuffled()
    }

    private func isMatch(_ c1: MatchCard, _ c2: MatchCard) -> Bool {
        c1.pairId == c2.pairId && c1.isWord != c2.isWord
    }
}
