import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 2b: AI 高级算法测试

@Suite("Phase 2b: 杀法搜索", .serialized)
struct CheckmateSearchTests {

    @Test("单车将杀：车 vs 空防线")
    func singleChariotCheckmate() {
        // 红车在 (5,0)，黑将在 (0,3)，红帅在 (9,4)
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = TestPieceFactory.blackGeneral(0, 3)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 3))
        let board = Board(pieces: [rg, bg, rc])
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 8)
        #expect(result != nil)
        if let moves = result {
            #expect(!moves.isEmpty)
        }
    }

    @Test("双车将杀")
    func doubleChariotCheckmate() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc1 = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 4))
        let rc2 = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 4, col: 0))
        let board = Board(pieces: [rg, bg, rc1, rc2])
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 8)
        #expect(result != nil)
    }

    @Test("无杀法时返回 nil")
    func noCheckmate() {
        // 初始局面，没有连将杀（P2-1 勘误 2026-10-28：占位断言转真实断言——初始局面 depth=4 内不存在强制连将杀，恒 nil）
        let board = Board()
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 4)
        #expect(result == nil, "初始局面 depth=4 内不得报强制将杀")
    }

    @Test("极短超时安全退出：初始局面恒无杀返回 nil")
    func checkmateSearchTimeout() {
        let board = Board()
        board.setCurrentTurn(.red)
        // 极短超时（P2-1 勘误 2026-10-28：占位断言转真实断言——初始局面不存在强制连将杀，超时/搜完两态均应 nil）
        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 12, timeLimitMs: 1)
        #expect(result == nil, "初始局面无论超时与否都不得报强制将杀")
    }
}
