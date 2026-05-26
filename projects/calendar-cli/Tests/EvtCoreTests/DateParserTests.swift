import XCTest
@testable import EvtCore

final class DateParserTests: XCTestCase {
    let cal = Calendar.current

    func testAbsoluteDateDash() {
        let d = DateParser.parse("2026-04-19")!
        let components = cal.dateComponents([.year, .month, .day], from: d)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 19)
    }

    func testAbsoluteDateTimeDash() {
        let d = DateParser.parse("2026-04-19 14:30")!
        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 19)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }

    func testAbsoluteDateSlash() {
        let d = DateParser.parse("2026/04/19")!
        let components = cal.dateComponents([.year, .month, .day], from: d)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 19)
    }

    func testAbsoluteDateTimeSlash() {
        let d = DateParser.parse("2026/04/19 09:00")!
        let components = cal.dateComponents([.hour, .minute], from: d)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
    }

    func testToday() {
        let d = DateParser.parse("today")!
        XCTAssertEqual(cal.startOfDay(for: Date()), cal.startOfDay(for: d))
    }

    func testTomorrow() {
        let d = DateParser.parse("tomorrow")!
        let expected = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        XCTAssertEqual(cal.startOfDay(for: d), expected)
    }

    func testNow() {
        let d = DateParser.parse("now")!
        // Should be within a few seconds of now
        let diff = abs(d.timeIntervalSinceNow)
        XCTAssertLessThan(diff, 2)
    }

    func testPlusDays() {
        let d = DateParser.parse("+3")!
        let expected = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: Date()))!
        XCTAssertEqual(cal.startOfDay(for: d), cal.startOfDay(for: expected))
    }

    func testPlusDaysSuffix() {
        let d = DateParser.parse("+3d")!
        let expected = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: Date()))!
        XCTAssertEqual(cal.startOfDay(for: d), cal.startOfDay(for: expected))
    }

    func testPlusWeeks() {
        let d = DateParser.parse("+1w")!
        let expected = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: Date()))!
        XCTAssertEqual(cal.startOfDay(for: d), cal.startOfDay(for: expected))
    }

    func testPlusZero() {
        let d = DateParser.parse("+0")!
        XCTAssertEqual(cal.startOfDay(for: d), cal.startOfDay(for: Date()))
    }

    func testInvalid() {
        XCTAssertNil(DateParser.parse("invalid"))
        XCTAssertNil(DateParser.parse("2026-13-01"))
        XCTAssertNil(DateParser.parse("+"))
        XCTAssertNil(DateParser.parse("-1"))
    }
}
