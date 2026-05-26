import XCTest
@testable import RemCore

final class DedupTests: XCTestCase {
    func testExactDuplicate() {
        let items = [
            RemItem(id: "a", title: "Buy milk", list: "Groceries",
                    completed: false, dueDate: nil, dueDateFull: nil,
                    priority: 0, priorityName: "none", notes: nil, creationDate: nil),
            RemItem(id: "b", title: "Buy milk", list: "Groceries",
                    completed: true, dueDate: nil, dueDateFull: nil,
                    priority: 0, priorityName: "none", notes: nil, creationDate: nil),
        ]
        // Only uncompleted exact matches
        let dups = items.filter { !$0.completed && $0.title == "Buy milk" }
        XCTAssertEqual(dups.count, 1)
        XCTAssertEqual(dups[0].id, "a")
    }

    func testNoDuplicate() {
        let items = [
            RemItem(id: "a", title: "Buy milk", list: "Groceries",
                    completed: false, dueDate: nil, dueDateFull: nil,
                    priority: 0, priorityName: "none", notes: nil, creationDate: nil),
        ]
        let dups = items.filter { !$0.completed && $0.title == "Buy bread" }
        XCTAssertTrue(dups.isEmpty)
    }

    func testCompletedNotCounted() {
        let items = [
            RemItem(id: "a", title: "Buy milk", list: "Groceries",
                    completed: true, dueDate: nil, dueDateFull: nil,
                    priority: 0, priorityName: "none", notes: nil, creationDate: nil),
        ]
        let dups = items.filter { !$0.completed && $0.title == "Buy milk" }
        XCTAssertTrue(dups.isEmpty)
    }

    func testNoSubstringMatch() {
        let items = [
            RemItem(id: "a", title: "Buy milk and bread", list: "Groceries",
                    completed: false, dueDate: nil, dueDateFull: nil,
                    priority: 0, priorityName: "none", notes: nil, creationDate: nil),
        ]
        let dups = items.filter { !$0.completed && $0.title == "Buy milk" }
        XCTAssertTrue(dups.isEmpty, "Exact match should not match substrings")
    }
}
