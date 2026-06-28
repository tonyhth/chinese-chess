import Testing
import Foundation
@testable import ChineseChess

// MARK: - Phase 5.2: FEN 边界条件测试

@Suite("FEN 边界条件")
struct FENBoundaryTests {

    // MARK: - 空 / 非法 FEN

    @Test("空字符串返回 nil")
    func emptyFEN() {
        #expect(FENParser.parse(fen: "") == nil)
    }

    @Test("只有空格返回 nil")
    func whitespaceFEN() {
        #expect(FENParser.parse(fen: "   ") == nil)
    }

    @Test("缺少行走方返回 nil")
    func missingTurn() {
        #expect(FENParser.parse(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR") == nil)
    }

    @Test("非法行走方返回 nil")
    func invalidTurn() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR x - - 0 1"
        #expect(FENParser.parse(fen: fen) == nil)
    }

    @Test("行数不足返回 nil")
    func tooFewRows() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p w - - 0 1"
        #expect(FENParser.parse(fen: fen) == nil)
    }

    @Test("行数过多返回 nil")
    func tooManyRows() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR/9 w - - 0 1"
        #expect(FENParser.parse(fen: fen) == nil)
    }

    @Test("非法字符返回 nil")
    func invalidChar() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNXAKABNR w - - 0 1"
        #expect(FENParser.parse(fen: fen) == nil)
    }

    @Test("列数不足返回 nil")
    func tooFewCols() {
        // 某行只有 5 列（4 空格 + 1 棋子，应该是 9 列）
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBA w - - 0 1"
        #expect(FENParser.parse(fen: fen) == nil)
    }

    // MARK: - 边界位置

    @Test("角点棋子位置正确")
    func cornerPositions() {
        guard let board = FENParser.parse(fen: FENParser.standardInitial) else {
            #expect(false, "标准 FEN 应解析成功")
            return
        }
        // 左上角 (0,0) = 黑车
        let topLeft = board.piece(at: Position(row: 0, col: 0))
        #expect(topLeft?.kind == .chariot)
        #expect(topLeft?.side == .black)

        // 右下角 (9,8) = 红车
        let bottomRight = board.piece(at: Position(row: 9, col: 8))
        #expect(bottomRight?.kind == .chariot)
        #expect(bottomRight?.side == .red)
    }

    @Test("FEN 中数字 0 非法")
    func zeroInFEN() {
        // 数字 0 在 FEN 中不合法
        let fen = "0bakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        #expect(FENParser.parse(fen: fen) == nil)
    }

    @Test("列溢出返回 nil")
    func colOverflow() {
        // 第一行有 10 列的数据（多了一个数字）
        let fen = "rnbakabnr9/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        #expect(FENParser.parse(fen: fen) == nil)
    }

    // MARK: - 往返一致性

    @Test("parse → generate → parse 一致")
    func roundTrip() {
        let original = FENParser.standardInitial
        guard let board = FENParser.parse(fen: original) else {
            #expect(false, "标准 FEN 应解析成功")
            return
        }
        let regenerated = FENParser.generate(board: board)
        // 重新解析应该得到相同的棋盘
        guard let board2 = FENParser.parse(fen: regenerated) else {
            #expect(false, "regenerated FEN 应解析成功")
            return
        }
        let regenerated2 = FENParser.generate(board: board2)
        #expect(regenerated == regenerated2)
    }

    @Test("空棋盘 generate 不崩溃")
    func emptyBoardGenerate() {
        let board = Board(pieces: [])
        let fen = FENParser.generate(board: board)
        // 应该全是数字
        #expect(!fen.isEmpty)
    }
}
