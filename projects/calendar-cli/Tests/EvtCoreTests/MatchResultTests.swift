import XCTest
@testable import EvtCore

final class MatchResultTests: XCTestCase {
    func testFound() {
        let result: MatchResult<String> = .found("hello")
        if case .found(let v) = result {
            XCTAssertEqual(v, "hello")
        } else {
            XCTFail("Expected found")
        }
    }

    func testMultiple() {
        let result: MatchResult<String> = .multiple(["a", "b"])
        if case .multiple(let items) = result {
            XCTAssertEqual(items.count, 2)
        } else {
            XCTFail("Expected multiple")
        }
    }

    func testNone() {
        let result: MatchResult<String> = .none
        if case .none = result {
            // pass
        } else {
            XCTFail("Expected none")
        }
    }
}
