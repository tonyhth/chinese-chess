import XCTest
@testable import VocabGame

final class PlayerProfileTests: XCTestCase {

    // MARK: - 初始状态

    func testDefaultValues() {
        let profile = PlayerProfile()
        XCTAssertEqual(profile.totalStars, 0)
        XCTAssertEqual(profile.totalWordsLearned, 0)
        XCTAssertEqual(profile.currentStreak, 0)
        XCTAssertEqual(profile.bestStreak, 0)
        XCTAssertNil(profile.lastPlayDate)
        XCTAssertEqual(profile.totalPlayTime, 0)
        XCTAssertEqual(profile.coins, 0)
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        var profile = PlayerProfile()
        profile.totalStars = 15
        profile.totalWordsLearned = 50
        profile.currentStreak = 7
        profile.bestStreak = 14
        profile.coins = 350

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(PlayerProfile.self, from: data)

        XCTAssertEqual(decoded.totalStars, 15)
        XCTAssertEqual(decoded.totalWordsLearned, 50)
        XCTAssertEqual(decoded.currentStreak, 7)
        XCTAssertEqual(decoded.bestStreak, 14)
        XCTAssertEqual(decoded.coins, 350)
    }
}
