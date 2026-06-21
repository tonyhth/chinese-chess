import Testing
import Foundation
@testable import ChineseChess

@Suite("Phase2a: UCIMoveConverter Tests")
struct UCIMoveConverterTests {

    // MARK: - uciString (Move → UCI)

    @Test("Move → UCI 字符串正确转换")
    func testMoveToUCI() {
        let board = Board(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1")
        let chariot = board.piece(at: Position(row: 9, col: 0))!
        let move = Move(piece: chariot, from: Position(row: 9, col: 0), to: Position(row: 5, col: 0), captured: nil)
        #expect(UCIMoveConverter.uciString(from: move) == "a9a5")
    }

    @Test("不同列位置正确映射")
    func testColMapping() {
        let board = Board(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1")
        let piece = board.piece(at: Position(row: 9, col: 4))!
        let move = Move(piece: piece, from: Position(row: 9, col: 4), to: Position(row: 8, col: 4), captured: nil)
        #expect(UCIMoveConverter.uciString(from: move) == "e9e8")
    }

    // MARK: - positions (UCI → Position pair)

    @Test("UCI → Position 往返转换")
    func testPositionsRoundTrip() {
        let testCases = ["a0a9", "h2e2", "b7d7", "e9e8", "d0d9"]
        for uci in testCases {
            guard let (from, to) = UCIMoveConverter.positions(from: uci) else {
                Issue.record("解析失败: \(uci)")
                continue
            }
            let dummyPiece = Piece(kind: .chariot, side: .red, position: from)
            let move = Move(piece: dummyPiece, from: from, to: to, captured: nil)
            let roundTrip = UCIMoveConverter.uciString(from: move)
            #expect(roundTrip == uci, "往返转换不匹配: \(uci) → \(roundTrip)")
        }
    }

    @Test("非法 UCI 字符串返回 nil")
    func testInvalidUCI() {
        #expect(UCIMoveConverter.positions(from: "") == nil)
        #expect(UCIMoveConverter.positions(from: "abc") == nil)
        #expect(UCIMoveConverter.positions(from: "a") == nil)
        #expect(UCIMoveConverter.positions(from: "j0j9") == nil)  // col > 8
    }

    // MARK: - move (UCI → Move on Board)

    @Test("初始局面 UCI → Move 包含 piece")
    func testMoveOnBoard() {
        let board = Board(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1")
        guard let move = UCIMoveConverter.move(from: "a9a5", on: board) else {
            Issue.record("move 返回 nil")
            return
        }
        #expect(move.piece.kind == .chariot)
        #expect(move.from == Position(row: 9, col: 0))
        #expect(move.to == Position(row: 5, col: 0))
    }

    // MARK: - board (FEN + UCI moves → Board)

    @Test("初始 FEN 无 moves 解析")
    func testFENParsing() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        guard let board = UCIMoveConverter.board(from: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        #expect(board.pieces.count == 32, "初始局面应有 32 个棋子")
    }

    @Test("FEN + moves 解析后棋子数量不变")
    func testFENWithMoves() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        // 黑炮从 b 列 row=2 到 row=6（即 UCI "b2b6"）
        let uciMoves = ["b2b6"]
        guard let board = UCIMoveConverter.board(from: fen, moves: uciMoves) else {
            Issue.record("FEN + moves 解析失败")
            return
        }
        #expect(board.pieces.count == 32, "走一步后棋子数不变")
    }

    // MARK: - ChessEngine 协议 — AIEngine 适配

    @Test("AIEngine 实现 ChessEngine 协议属性")
    func testAIEngineProperties() {
        let engine = AIEngine()
        #expect(engine.displayName == "内置引擎")
        #expect(engine.engineType == .native)
    }

    @Test("AIEngine 通过 ChessEngine 协议走棋")
    func testAIEngineViaProtocol() async {
        let engine: any ChessEngine = AIEngine()
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let uciMove = await engine.bestMove(
            fen: fen,
            moveHistory: [],
            difficulty: .easy,
            timeLimitMs: 5000
        )

        #expect(uciMove != nil, "应返回一个走法")
        #expect(uciMove!.count == 4, "UCI 走法应为 4 字符")
    }

    // MARK: - EngineRouter

    @Test("EngineRouter 默认返回 native 引擎")
    func testEngineRouterDefault() {
        let router = EngineRouter.shared
        let engine = router.activeEngine()
        #expect(engine.displayName == "内置引擎")
        #expect(engine.engineType == .native)
    }

    @Test("EngineRouter.native 返回 AIEngine 实例")
    func testEngineRouterNative() {
        let router = EngineRouter.shared
        let native = router.native
        let chessEngine: any ChessEngine = native
        #expect(chessEngine.engineType == .native)
    }
}
