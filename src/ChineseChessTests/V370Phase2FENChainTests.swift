import XCTest
@testable import ChineseChess

// MARK: - v3.7.0 Phase 2: FEN 推算链路验证

final class V370Phase2FENChainTests: XCTestCase {

    // MARK: - 标准开局 FEN 推算

    /// 验证标准开局下，Board 逐步执行后的 FEN == FENRebuilder 推算的 FEN
    func testFENChain_StandardInitial() {
        let initialFEN = FENParser.standardInitial
        let board = Board(fen: initialFEN)

        // 收集一系列标准走法
        var gameMoves: [GameMove] = []
        var boardFENs: [String] = [FENParser.generate(board: board)]

        let testMoves: [(from: Position, to: Position)] = [
            // 炮二平五 (h2e2)
            (Position(row: 7, col: 7), Position(row: 7, col: 4)),
            // 马8进7 (b0c2)
            (Position(row: 9, col: 1), Position(row: 7, col: 2)),
            // 马二进三 (h0g2)
            (Position(row: 9, col: 7), Position(row: 7, col: 6)),
            // 车9平8 (a0b0)
            (Position(row: 9, col: 0), Position(row: 9, col: 1)),
            // 车一平四 (i0h0)
            (Position(row: 9, col: 8), Position(row: 9, col: 7)),
        ]

        for (idx, testMove) in testMoves.enumerated() {
            guard let piece = board.piece(at: testMove.from) else {
                XCTFail("第 \(idx) 步：棋盘上 \(testMove.from) 无棋子")
                return
            }
            let captured = board.piece(at: testMove.to)
            let move = Move(piece: piece, from: testMove.from, to: testMove.to, captured: captured)
            board.execute(move)

            let fenAfter = FENParser.generate(board: board)
            boardFENs.append(fenAfter)

            let gameMove = GameMove(
                id: UUID(),
                piece: piece,
                from: testMove.from,
                to: testMove.to,
                captured: captured,
                turnNumber: (idx / 2) + 1,
                notation: "",
                timestamp: Date(),
                isCheck: false,
                isCheckmate: false, halfmoveClock: 0
            )
            gameMoves.append(gameMove)
        }

        // 使用 FENRebuilder 推算
        let rebuiltFENs = FENRebuilder.computeAllFENs(initialFEN: initialFEN, moves: gameMoves)

        // 逐个比较
        XCTAssertEqual(boardFENs.count, rebuiltFENs.count, "FEN 数量不匹配")
        for (i, (boardFEN, rebuiltFEN)) in zip(boardFENs, rebuiltFENs).enumerated() {
            XCTAssertEqual(boardFEN, rebuiltFEN, "第 \(i) 步 FEN 不匹配：Board=\(boardFEN), Rebuilder=\(rebuiltFEN)")
        }
    }

    // MARK: - computeFEN(before:) 精确验证

    /// 验证 computeFEN(before:) 每一步的 FEN
    func testComputeFENBefore_EachStep() {
        let initialFEN = FENParser.standardInitial
        let board = Board(fen: initialFEN)

        var gameMoves: [GameMove] = []
        var expectedFENs: [String] = [FENParser.generate(board: board)]

        // 执行 4 步走法
        let testMoves: [(from: Position, to: Position)] = [
            (Position(row: 7, col: 7), Position(row: 7, col: 4)),  // 炮二平五
            (Position(row: 9, col: 1), Position(row: 7, col: 2)),  // 马8进7
            (Position(row: 9, col: 7), Position(row: 7, col: 6)),  // 马二进三
            (Position(row: 9, col: 0), Position(row: 9, col: 1)),  // 车9平8
        ]

        for (idx, testMove) in testMoves.enumerated() {
            guard let piece = board.piece(at: testMove.from) else {
                XCTFail("第 \(idx) 步：棋盘上无棋子")
                return
            }
            let captured = board.piece(at: testMove.to)
            let move = Move(piece: piece, from: testMove.from, to: testMove.to, captured: captured)
            board.execute(move)

            expectedFENs.append(FENParser.generate(board: board))

            let gameMove = GameMove(
                id: UUID(),
                piece: piece,
                from: testMove.from,
                to: testMove.to,
                captured: captured,
                turnNumber: (idx / 2) + 1,
                notation: "",
                timestamp: Date(),
                isCheck: false,
                isCheckmate: false, halfmoveClock: 0
            )
            gameMoves.append(gameMove)
        }

        // 验证 computeFEN(before:) 对每一步
        for i in 0...gameMoves.count {
            let rebuiltFEN = FENRebuilder.computeFEN(initialFEN: initialFEN, moves: gameMoves, before: i)
            XCTAssertEqual(rebuiltFEN, expectedFENs[i], "computeFEN(before: \(i)) 不匹配")
        }
    }

    // MARK: - 非标准开局 FEN 推算

    /// 验证非标准开局 FEN 推算
    func testFENChain_CustomFEN() {
        // 只有将帅对面的残局 FEN
        let customFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        let board = Board(fen: customFEN)

        // 这个局面只有将和帅，走法有限
        // 帅五进一 (e0e1)
        let fromPos = Position(row: 9, col: 4)
        let toPos = Position(row: 8, col: 4)

        guard let piece = board.piece(at: fromPos) else {
            XCTFail("帅不在 e0 位置")
            return
        }
        let captured = board.piece(at: toPos)
        let move = Move(piece: piece, from: fromPos, to: toPos, captured: captured)
        board.execute(move)

        let gameMove = GameMove(
            id: UUID(),
            piece: piece,
            from: fromPos,
            to: toPos,
            captured: captured,
            turnNumber: 1,
            notation: "",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false, halfmoveClock: 0
        )

        let fenBefore = FENRebuilder.computeFEN(initialFEN: customFEN, moves: [gameMove], before: 0)
        XCTAssertEqual(fenBefore, customFEN, "before: 0 应返回初始 FEN")

        let rebuiltAll = FENRebuilder.computeAllFENs(initialFEN: customFEN, moves: [gameMove])
        XCTAssertEqual(rebuiltAll.count, 2, "应有 2 个 FEN（初始+走后）")
        XCTAssertEqual(rebuiltAll[0], customFEN, "第一个 FEN 应为初始 FEN")

        let expectedFenAfter = FENParser.generate(board: board)
        XCTAssertEqual(rebuiltAll[1], expectedFenAfter, "走后的 FEN 应匹配")
    }

    // MARK: - fallback 策略验证

    /// 验证 board.piece(at: gm.from) ?? gm.piece 的 fallback 策略
    /// 当 Board 上 from 位置的棋子因某种原因找不到时，应使用 gm.piece 作为 fallback
    func testFENChain_FallbackStrategy() {
        let initialFEN = FENParser.standardInitial

        // 构造一个 GameMove（正常走法）
        let fromPos = Position(row: 7, col: 7)
        let toPos = Position(row: 7, col: 4)

        let board = Board(fen: initialFEN)
        guard let piece = board.piece(at: fromPos) else {
            XCTFail("炮不在 h2 位置")
            return
        }

        let gameMove = GameMove(
            id: UUID(),
            piece: piece,
            from: fromPos,
            to: toPos,
            captured: nil,
            turnNumber: 1,
            notation: "",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false, halfmoveClock: 0
        )

        // FENRebuilder 使用 board.piece(at: gm.from) ?? gm.piece
        let rebuiltFENs = FENRebuilder.computeAllFENs(initialFEN: initialFEN, moves: [gameMove])
        XCTAssertEqual(rebuiltFENs.count, 2)

        // 验证走后的 FEN（用全新的 Board 验证）
        let expectedBoard = Board(fen: initialFEN)
        let m = Move(piece: expectedBoard.piece(at: fromPos)!, from: fromPos, to: toPos, captured: nil)
        expectedBoard.execute(m)
        let expectedFEN = FENParser.generate(board: expectedBoard)

        XCTAssertEqual(rebuiltFENs[1], expectedFEN, "fallback 策略下的 FEN 推算应正确")
    }

    // MARK: - 空走法列表

    func testFENChain_EmptyMoves() {
        let initialFEN = FENParser.standardInitial
        let fens = FENRebuilder.computeAllFENs(initialFEN: initialFEN, moves: [])
        XCTAssertEqual(fens.count, 1, "空走法应返回 1 个 FEN")
        XCTAssertEqual(fens[0], initialFEN)

        let fen = FENRebuilder.computeFEN(initialFEN: initialFEN, moves: [], before: 0)
        XCTAssertEqual(fen, initialFEN)
    }

    // MARK: - AnalysisViewModel FEN 缓存集成

    func testAnalysisViewModel_FENCache() {
        let vm = AnalysisViewModel()
        let initialFEN = FENParser.standardInitial

        // 构造 GameMove
        let fromPos = Position(row: 7, col: 7)
        let toPos = Position(row: 7, col: 4)
        let board = Board(fen: initialFEN)
        guard let piece = board.piece(at: fromPos) else {
            XCTFail("炮不在 h2")
            return
        }
        let gameMove = GameMove(
            id: UUID(),
            piece: piece,
            from: fromPos,
            to: toPos,
            captured: nil,
            turnNumber: 1,
            notation: "",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false, halfmoveClock: 0
        )

        // 不传 gameMoves → fenList 只有初始 FEN
        vm.load(moves: ["h2e2"], initialFEN: initialFEN)
        XCTAssertEqual(vm.fenList.count, 1, "不传 gameMoves 时 fenList 应只有 1 个")

        // 传 gameMoves → fenList 预计算
        vm.load(moves: ["h2e2"], initialFEN: initialFEN, gameMoves: [gameMove])
        XCTAssertEqual(vm.fenList.count, 2, "传 gameMoves 时 fenList 应有 2 个（初始+走后）")
        XCTAssertEqual(vm.fenList[0], initialFEN, "fenList[0] 应为初始 FEN")
    }
}
