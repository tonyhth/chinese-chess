import XCTest
@testable import VocabGame

final class WordProgressTests: XCTestCase {

    // MARK: - 初始状态

    func testInitial() {
        let wp = WordProgress.initial(wordId: 42)
        XCTAssertEqual(wp.wordId, 42)
        XCTAssertEqual(wp.mastery, .new)
        XCTAssertEqual(wp.correctCount, 0)
        XCTAssertEqual(wp.consecutiveCorrect, 0)
        XCTAssertEqual(wp.wrongCount, 0)
        XCTAssertEqual(wp.lastReviewed, Date.distantPast)
        XCTAssertEqual(wp.nextReviewDate, Date.distantPast)
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        var wp = WordProgress.initial(wordId: 1)
        wp.mastery = .familiar
        wp.correctCount = 8
        wp.consecutiveCorrect = 3
        wp.wrongCount = 2

        let data = try JSONEncoder().encode(wp)
        let decoded = try JSONDecoder().decode(WordProgress.self, from: data)

        XCTAssertEqual(decoded.wordId, 1)
        XCTAssertEqual(decoded.mastery, .familiar)
        XCTAssertEqual(decoded.correctCount, 8)
        XCTAssertEqual(decoded.consecutiveCorrect, 3)
        XCTAssertEqual(decoded.wrongCount, 2)
    }

    // MARK: - MasteryLevel

    func testMasteryLevel_rawValues() {
        XCTAssertEqual(MasteryLevel.new.rawValue, 0)
        XCTAssertEqual(MasteryLevel.learning.rawValue, 1)
        XCTAssertEqual(MasteryLevel.familiar.rawValue, 2)
        XCTAssertEqual(MasteryLevel.mastered.rawValue, 3)
    }

    func testMasteryLevel_codable() throws {
        let levels: [MasteryLevel] = [.new, .learning, .familiar, .mastered]
        for level in levels {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(MasteryLevel.self, from: data)
            XCTAssertEqual(decoded, level)
        }
    }
}
