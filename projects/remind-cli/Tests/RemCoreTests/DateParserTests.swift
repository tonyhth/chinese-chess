import XCTest
@testable import RemCore

final class DateParserTests: XCTestCase {
    func testStandardDate() {
        let dc = DateParser.parse("2026-04-15")
        XCTAssertNotNil(dc)
        XCTAssertEqual(dc?.year, 2026)
        XCTAssertEqual(dc?.month, 4)
        XCTAssertEqual(dc?.day, 15)
    }

    func testSlashDate() {
        let dc = DateParser.parse("2026/04/15")
        XCTAssertNotNil(dc)
        XCTAssertEqual(dc?.year, 2026)
        XCTAssertEqual(dc?.month, 4)
        XCTAssertEqual(dc?.day, 15)
    }

    func testToday() {
        let dc = DateParser.parse("today")
        XCTAssertNotNil(dc)
        let cal = Calendar.current
        let now = cal.dateComponents([.year, .month, .day], from: Date())
        XCTAssertEqual(dc?.year, now.year)
        XCTAssertEqual(dc?.month, now.month)
        XCTAssertEqual(dc?.day, now.day)
    }

    func testTomorrow() {
        let dc = DateParser.parse("tomorrow")
        XCTAssertNotNil(dc)
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let expected = cal.dateComponents([.year, .month, .day], from: tomorrow)
        XCTAssertEqual(dc?.year, expected.year)
        XCTAssertEqual(dc?.month, expected.month)
        XCTAssertEqual(dc?.day, expected.day)
    }

    func testPlusDays() {
        let dc = DateParser.parse("+3")
        XCTAssertNotNil(dc)
        let cal = Calendar.current
        let target = cal.date(byAdding: .day, value: 3, to: Date())!
        let expected = cal.dateComponents([.year, .month, .day], from: target)
        XCTAssertEqual(dc?.year, expected.year)
        XCTAssertEqual(dc?.month, expected.month)
        XCTAssertEqual(dc?.day, expected.day)
    }

    func testPlusDaysWithD() {
        let dc = DateParser.parse("+3d")
        XCTAssertNotNil(dc)
        let cal = Calendar.current
        let target = cal.date(byAdding: .day, value: 3, to: Date())!
        let expected = cal.dateComponents([.year, .month, .day], from: target)
        XCTAssertEqual(dc?.year, expected.year)
        XCTAssertEqual(dc?.month, expected.month)
        XCTAssertEqual(dc?.day, expected.day)
    }

    func testPlusZeroEqualsToday() {
        let dc = DateParser.parse("+0")
        XCTAssertNotNil(dc)
        let cal = Calendar.current
        let now = cal.dateComponents([.year, .month, .day], from: Date())
        XCTAssertEqual(dc?.year, now.year)
        XCTAssertEqual(dc?.month, now.month)
        XCTAssertEqual(dc?.day, now.day)
    }

    func testInvalidInput() {
        XCTAssertNil(DateParser.parse("not-a-date"))
        XCTAssertNil(DateParser.parse(""))
        XCTAssertNil(DateParser.parse("2026-13-01"))
        XCTAssertNil(DateParser.parse("+abc"))
        XCTAssertNil(DateParser.parse("-1"))
    }

    func testCaseInsensitive() {
        XCTAssertNotNil(DateParser.parse("Today"))
        XCTAssertNotNil(DateParser.parse("TOMORROW"))
    }
}
