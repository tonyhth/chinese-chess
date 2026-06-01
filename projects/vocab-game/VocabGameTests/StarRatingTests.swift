import XCTest
@testable import VocabGame

final class StarRatingTests: XCTestCase {

    // MARK: - 基本评级（正确率）

    func testStars_0Correct() {
        XCTAssertEqual(StarRating.stars(correctCount: 0, totalCount: 10), 0)
    }

    func testStars_below40() {
        XCTAssertEqual(StarRating.stars(correctCount: 3, totalCount: 10), 0)
    }

    func testStars_exact40() {
        XCTAssertEqual(StarRating.stars(correctCount: 4, totalCount: 10), 1)
    }

    func testStars_exact60() {
        XCTAssertEqual(StarRating.stars(correctCount: 6, totalCount: 10), 2)
    }

    func testStars_exact80() {
        XCTAssertEqual(StarRating.stars(correctCount: 8, totalCount: 10), 3)
    }

    func testStars_perfect() {
        XCTAssertEqual(StarRating.stars(correctCount: 10, totalCount: 10), 3)
    }

    // MARK: - 边界值

    func testStars_boundaryCases() {
        XCTAssertEqual(StarRating.stars(correctCount: 1, totalCount: 10), 0)
        XCTAssertEqual(StarRating.stars(correctCount: 5, totalCount: 10), 1)
        XCTAssertEqual(StarRating.stars(correctCount: 7, totalCount: 10), 2)
        XCTAssertEqual(StarRating.stars(correctCount: 9, totalCount: 10), 3)
    }

    // MARK: - 阈值常量（正确率）

    func testThresholds() {
        XCTAssertEqual(StarRating.thresholds.star1, 0.4)
        XCTAssertEqual(StarRating.thresholds.star2, 0.6)
        XCTAssertEqual(StarRating.thresholds.star3, 0.8)
    }

    // MARK: - 空总数

    func testStars_zeroTotal() {
        XCTAssertEqual(StarRating.stars(correctCount: 0, totalCount: 0), 0)
    }

    // MARK: - 向后兼容 forScore

    func testStars_forScore_backwardCompat() {
        // forScore delegates to stars(correctCount:estimatedCorrect, totalCount: questionCount)
        // score 1000 / 10 → estimatedCorrect = 10 → rate 1.0 → 3 stars
        XCTAssertEqual(StarRating.stars(forScore: 1000, questionCount: 10), 3)
        // score 800 / 10 → estimatedCorrect = 8 → rate 0.8 → 3 stars
        XCTAssertEqual(StarRating.stars(forScore: 800, questionCount: 10), 3)
        // score 600 / 10 → estimatedCorrect = 6 → rate 0.6 → 2 stars
        XCTAssertEqual(StarRating.stars(forScore: 600, questionCount: 10), 2)
        // score 300 / 10 → estimatedCorrect = 3 → rate 0.3 → 0 stars
        XCTAssertEqual(StarRating.stars(forScore: 300, questionCount: 10), 0)
    }

    func testStars_negativeScore() {
        // Negative score → estimatedCorrect = negative → clamped by guard
        XCTAssertEqual(StarRating.stars(forScore: -100), 0)
    }
}
