import XCTest
@testable import EvtCore

final class AlertParserTests: XCTestCase {
    func testRelativeMinutes() {
        if case .relative(let offset) = AlertParser.parse("15m") {
            XCTAssertEqual(offset, -900)
        } else {
            XCTFail("Expected relative")
        }
    }

    func testRelativeHours() {
        if case .relative(let offset) = AlertParser.parse("1h") {
            XCTAssertEqual(offset, -3600)
        } else {
            XCTFail("Expected relative")
        }
    }

    func testRelativeDays() {
        if case .relative(let offset) = AlertParser.parse("1d") {
            XCTAssertEqual(offset, -86400)
        } else {
            XCTFail("Expected relative")
        }
    }

    func testRelativeComposite() {
        if case .relative(let offset) = AlertParser.parse("2h30m") {
            XCTAssertEqual(offset, -9000)
        } else {
            XCTFail("Expected relative")
        }
    }

    func testAbsoluteAlert() {
        if case .absolute(let date) = AlertParser.parse("@2026-04-19 08:30") {
            let cal = Calendar.current
            let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            XCTAssertEqual(components.year, 2026)
            XCTAssertEqual(components.month, 4)
            XCTAssertEqual(components.day, 19)
            XCTAssertEqual(components.hour, 8)
            XCTAssertEqual(components.minute, 30)
        } else {
            XCTFail("Expected absolute")
        }
    }

    func testFormatOffset() {
        XCTAssertEqual(AlertParser.formatOffset(-900), "15m")
        XCTAssertEqual(AlertParser.formatOffset(-3600), "1h")
        XCTAssertEqual(AlertParser.formatOffset(-86400), "1d")
        XCTAssertEqual(AlertParser.formatOffset(-9000), "2h30m")
    }

    func testInvalid() {
        XCTAssertNil(AlertParser.parse("abc"))
        XCTAssertNil(AlertParser.parse("@invalid"))
    }
}
