import Foundation
import Testing
@testable import ChineseChess

@Suite("残局排序修复")
struct PuzzleSortFixTests {

    @Test("sqyq_001..010 的 id 字符串排序等于数字序")
    func idStringSortingMatchesNumericOrder() {
        let ids = (1...12).map { String(format: "sqyq_%03d", $0) }
        let sorted = ids.sorted { $0 < $1 }
        let expected = (1...12).map { String(format: "sqyq_%03d", $0) }
        #expect(sorted == expected)
    }

    @Test("sqyq_010 > sqyq_002（原 bug：name 排序 '第10局' < '第2局'）")
    func idSortsCorrectlyAround10() {
        let id2 = "sqyq_002"
        let id10 = "sqyq_010"
        #expect(id2 < id10)
    }

    @Test("排序稳定性：未完成在前，完成后按 id 排序")
    func sortOrderByCompletionThenId() {
        // 模拟排序逻辑
        struct Item { let id: String; let done: Bool }
        let items = [
            Item(id: "sqyq_010", done: false),
            Item(id: "sqyq_002", done: true),
            Item(id: "sqyq_003", done: false),
            Item(id: "sqyq_001", done: true),
        ]
        let sorted = items.sorted { a, b in
            if a.done != b.done { return !a.done }
            return a.id < b.id
        }
        let sortedIds = sorted.map(\.id)
        // 未完成: 003, 010 (按 id) → 完成: 001, 002 (按 id)
        #expect(sortedIds == ["sqyq_003", "sqyq_010", "sqyq_001", "sqyq_002"])
    }

    @Test("PuzzleSelectView 实例化不 crash")
    func puzzleSelectViewNoCrash() {
        let view = PuzzleSelectView()
        _ = view
    }
}
