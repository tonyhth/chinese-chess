import XCTest
@testable import RemCore

final class MatchResultTests: XCTestCase {
    func testFound() {
        let item = RemItem(
            id: "abc", title: "Test", list: "List",
            completed: false, dueDate: nil, dueDateFull: nil,
            priority: 0, priorityName: "none", notes: nil, creationDate: nil
        )
        let result: MatchResult<RemItem> = .found(item)
        if case .found(let found) = result {
            XCTAssertEqual(found.id, "abc")
        } else {
            XCTFail("Expected .found")
        }
    }

    func testMultiple() {
        let items = [
            RemItem(id: "a", title: "A", list: "L", completed: false,
                    dueDate: nil, dueDateFull: nil, priority: 0,
                    priorityName: "none", notes: nil, creationDate: nil),
            RemItem(id: "b", title: "B", list: "L", completed: false,
                    dueDate: nil, dueDateFull: nil, priority: 0,
                    priorityName: "none", notes: nil, creationDate: nil),
        ]
        let result: MatchResult<RemItem> = .multiple(items)
        if case .multiple(let found) = result {
            XCTAssertEqual(found.count, 2)
        } else {
            XCTFail("Expected .multiple")
        }
    }

    func testNone() {
        let result: MatchResult<RemItem> = .none
        if case .none = result {
            // pass
        } else {
            XCTFail("Expected .none")
        }
    }
}
