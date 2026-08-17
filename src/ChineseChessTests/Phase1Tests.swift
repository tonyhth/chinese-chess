import Testing
import Foundation
@testable import ChineseChess

// MARK: - FEN 解析/序列化测试

@Suite("FEN Parser Tests")
struct FENParserTests {

    @Test("标准开局 FEN 解析")
    func testStandardInitialFEN() {
        let board = FENParser.parse(fen: FENParser.standardInitial)
        #expect(board != nil)

        let b = board!
        // 红方 16 子 + 黑方 16 子
        #expect(b.pieces.count == 32)
        #expect(b.currentTurn == .red)

        // 验证几个关键棋子位置
        let blackGeneral = b.piece(at: Position(row: 0, col: 4))
        #expect(blackGeneral != nil)
        #expect(blackGeneral?.kind == .general)
        #expect(blackGeneral?.side == .black)

        let redGeneral = b.piece(at: Position(row: 9, col: 4))
        #expect(redGeneral != nil)
        #expect(redGeneral?.kind == .general)
        #expect(redGeneral?.side == .red)

        // 红炮
        let redCannon = b.piece(at: Position(row: 7, col: 1))
        #expect(redCannon != nil)
        #expect(redCannon?.kind == .cannon)
        #expect(redCannon?.side == .red)

        // 黑马
        let blackHorse = b.piece(at: Position(row: 0, col: 1))
        #expect(blackHorse != nil)
        #expect(blackHorse?.kind == .horse)
        #expect(blackHorse?.side == .black)
    }

    @Test("FEN roundtrip：解析 → 序列化 → 再解析")
    func testFENRoundtrip() {
        let original = FENParser.standardInitial
        let board = FENParser.parse(fen: original)!
        let generated = FENParser.generate(board: board)
        let board2 = FENParser.parse(fen: generated)!

        // 两轮解析后棋子数和位置应一致
        #expect(board2.pieces.count == board.pieces.count)
        #expect(board2.currentTurn == board.currentTurn)

        for piece in board.pieces {
            let match = board2.piece(at: piece.position)
            #expect(match != nil)
            #expect(match?.kind == piece.kind)
            #expect(match?.side == piece.side)
        }
    }

    @Test("黑方先行 FEN")
    func testBlackTurnFEN() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1"
        let board = FENParser.parse(fen: fen)
        #expect(board != nil)
        #expect(board?.currentTurn == .black)
    }

    @Test("残局 FEN：单车胜双士")
    func testEndgameFEN() {
        let fen = "4k4/4a4/9/9/9/9/9/4R4/9/4K4 w - - 0 1"
        let board = FENParser.parse(fen: fen)
        #expect(board != nil)

        let b = board!
        #expect(b.pieces.count == 4)  // 黑将 + 黑士 + 红车 + 红帅 = 4 子
        #expect(b.currentTurn == .red)
    }

    @Test("非法 FEN 处理")
    func testInvalidFEN() {
        // 空字符串
        #expect(FENParser.parse(fen: "") == nil)

        // 只有行走方
        #expect(FENParser.parse(fen: "w") == nil)

        // 行数不对
        #expect(FENParser.parse(fen: "rnbakabnr/9 w - - 0 1") == nil)

        // 非法字符
        #expect(FENParser.parse(fen: "xyz/9/9/9/9/9/9/9/9/9 w - - 0 1") == nil)
    }

    @Test("空棋盘 FEN")
    func testEmptyBoard() {
        let fen = "9/9/9/9/9/9/9/9/9/9 w - - 0 1"
        let board = FENParser.parse(fen: fen)
        #expect(board != nil)
        #expect(board?.pieces.count == 0)

        // roundtrip
        let generated = FENParser.generate(board: board!)
        let board2 = FENParser.parse(fen: generated)
        #expect(board2?.pieces.count == 0)
    }

    @Test("Board FEN 初始化 convenience init")
    func testBoardFENInit() {
        let board = Board(fen: FENParser.standardInitial)
        #expect(board.pieces.count == 32)
        #expect(board.currentTurn == .red)
    }

    @Test("Board FEN 初始化 fallback")
    func testBoardFENInitFallback() {
        let board = Board(fen: "invalid fen string")
        // fallback 到标准开局
        #expect(board.pieces.count == 32)
    }

    @Test("FEN 序列化验证：标准开局生成正确")
    func testFENGeneration() {
        let board = Board()
        let generated = FENParser.generate(board: board)
        #expect(generated.hasPrefix("rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR"))
        #expect(generated.contains(" w "))
    }
}

// MARK: - GameMove 创建测试

@Suite("GameMove Tests")
struct GameMoveTests {

    @Test("GameMove 基本创建")
    func testGameMoveCreation() {
        let piece = Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9)
        let move = GameMove(
            id: UUID(),
            piece: piece,
            from: Position(row: 7, col: 1),
            to: Position(row: 7, col: 4),
            captured: nil,
            turnNumber: 1,
            notation: "炮二平五",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false,
            halfmoveClock: 0
        )

        #expect(move.piece.kind == .cannon)
        #expect(move.piece.side == .red)
        #expect(move.from == Position(row: 7, col: 1))
        #expect(move.to == Position(row: 7, col: 4))
        #expect(move.captured == nil)
        #expect(move.turnNumber == 1)
        #expect(move.notation == "炮二平五")
        #expect(move.isCheck == false)
        #expect(move.isCheckmate == false)
    }

    @Test("GameMove 吃子记录")
    func testGameMoveWithCapture() {
        let piece = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let captured = Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0), id: 27)
        let move = GameMove(
            id: UUID(),
            piece: piece,
            from: Position(row: 5, col: 0),
            to: Position(row: 3, col: 0),
            captured: captured,
            turnNumber: 3,
            notation: "車九进二",
            timestamp: Date(),
            isCheck: true,
            isCheckmate: false,
            halfmoveClock: 0
        )

        #expect(move.captured != nil)
        #expect(move.captured?.kind == .soldier)
        #expect(move.isCheck == true)
        #expect(move.isCheckmate == false)
    }

    @Test("GameMove 将死标记")
    func testGameMoveCheckmate() {
        let piece = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 1, col: 4))
        let move = GameMove(
            id: UUID(),
            piece: piece,
            from: Position(row: 1, col: 4),
            to: Position(row: 0, col: 4),
            captured: nil,
            turnNumber: 20,
            notation: "車五进一",
            timestamp: Date(),
            isCheck: true,
            isCheckmate: true,
            halfmoveClock: 0
        )

        #expect(move.isCheckmate == true)
        #expect(move.isCheck == true)
    }
}

// MARK: - AIDifficulty 测试

@Suite("AIDifficulty Tests")
struct AIDifficultyTests {

    @Test("AIDifficulty 5 级完整性")
    func testAIDifficultyFiveLevels() {
        let levels = AIDifficulty.allCases
        #expect(levels.count == 5)
        #expect(levels[0] == .novice)
        #expect(levels[1] == .beginner)
        #expect(levels[2] == .amateurLow)
        #expect(levels[3] == .amateurMid)
        #expect(levels[4] == .amateurHigh)
    }

    @Test("AIDifficulty Codable roundtrip")
    func testAIDifficultyCodable() {
        for difficulty in AIDifficulty.allCases {
            let data = try! JSONEncoder().encode(difficulty)
            let decoded = try! JSONDecoder().decode(AIDifficulty.self, from: data)
            #expect(decoded == difficulty)
        }
    }
}
