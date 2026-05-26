import XCTest
@testable import VocabGame

final class StarRatingTests: XCTestCase {

    // MARK: - 基本评级

    func testStars_0Score() {
        XCTAssertEqual(StarRating.stars(forScore: 0), 0)
    }

    func testStars_below600() {
        XCTAssertEqual(StarRating.stars(forScore: 599), 0)
    }

    func testStars_exact600() {
        XCTAssertEqual(StarRating.stars(forScore: 600), 1)
    }

    func testStars_exact800() {
        XCTAssertEqual(StarRating.stars(forScore: 800), 2)
    }

    func testStars_exact900() {
        XCTAssertEqual(StarRating.stars(forScore: 900), 3)
    }

    func testStars_above900() {
        XCTAssertEqual(StarRating.stars(forScore: 1500), 3)
    }

    // MARK: - 边界值

    func testStars_boundaryCases() {
        XCTAssertEqual(StarRating.stars(forScore: 1), 0)
        XCTAssertEqual(StarRating.stars(forScore: 799), 1)
        XCTAssertEqual(StarRating.stars(forScore: 899), 2)
        XCTAssertEqual(StarRating.stars(forScore: 1000), 3)
    }

    // MARK: - 阈值常量

    func testThresholds() {
        XCTAssertEqual(StarRating.thresholds.star1, 600)
        XCTAssertEqual(StarRating.thresholds.star2, 800)
        XCTAssertEqual(StarRating.thresholds.star3, 900)
    }

    // MARK: - 负分

    func testStars_negativeScore() {
        XCTAssertEqual(StarRating.stars(forScore: -100), 0)
    }
}
