import XCTest
@testable import RemCore

final class PriorityTests: XCTestCase {
    func testFromString() {
        XCTAssertEqual(Priority(stringValue: "high"), .some(.high))
        XCTAssertEqual(Priority(stringValue: "medium"), .some(.medium))
        XCTAssertEqual(Priority(stringValue: "low"), .some(.low))
        XCTAssertEqual(Priority(stringValue: "none"), .some(.none))
    }

    func testCaseInsensitive() {
        XCTAssertEqual(Priority(stringValue: "High"), .high)
        XCTAssertEqual(Priority(stringValue: "HIGH"), .high)
        XCTAssertEqual(Priority(stringValue: "Medium"), .medium)
    }

    func testInvalid() {
        XCTAssertNil(Priority(stringValue: "urgent"))
        XCTAssertNil(Priority(stringValue: ""))
        XCTAssertNil(Priority(stringValue: "1"))
    }

    func testRawValues() {
        XCTAssertEqual(Priority.high.rawValue, 1)
        XCTAssertEqual(Priority.medium.rawValue, 5)
        XCTAssertEqual(Priority.low.rawValue, 9)
        XCTAssertEqual(Priority.none.rawValue, 0)
    }

    func testDisplayNames() {
        XCTAssertEqual(Priority.high.displayName, "high")
        XCTAssertEqual(Priority.medium.displayName, "medium")
        XCTAssertEqual(Priority.low.displayName, "low")
        XCTAssertEqual(Priority.none.displayName, "none")
    }
}
