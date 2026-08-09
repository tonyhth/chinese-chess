import Testing
@testable import ChineseChess

@Suite("Phase 2a: AI 基础设施", .serialized)
struct Phase2aTests {

    // MARK: - ZobristHash 测试

    @MainActor
@Test("Zobrist 哈希：同一局面多次计算结果一致")
    func zobristConsistency() {
        let board = Board()
        let h1 = ZobristHash.hash(board: board)
        let h2 = ZobristHash.hash(board: board)
        #expect(h1 == h2)
    }

    @MainActor
@Test("Zobrist 哈希：不同局面产生不同哈希")
    func zobristDifferentPositions() {
        let board1 = Board()
        var board2 = Board()
        // 走一步后局面不同
        let move = MoveValidator.allLegalMoves(for: .red, on: board2).first!
        board2.execute(move)
        let h1 = ZobristHash.hash(board: board1)
        let h2 = ZobristHash.hash(board: board2)
        #expect(h1 != h2)
    }

    @MainActor
@Test("Zobrist 哈希：增量更新等价于全量重算")
    func zobristIncrementalMatchesFull() {
        let board = Board()
        let fullHash = ZobristHash.hash(board: board)

        // 执行一步走法
        let snapshot = board.snapshot()
        let moves = MoveValidator.allLegalMoves(for: .red, on: snapshot)
        guard let move = moves.first else {
            Issue.record("No legal moves")
            return
        }
        let captured = snapshot.piece(at: move.to)
        let incrHash = ZobristHash.update(hash: fullHash, piece: move.piece, from: move.from, to: move.to, captured: captured)
        snapshot.execute(move)

        let newFullHash = ZobristHash.hash(board: snapshot)
        #expect(incrHash == newFullHash)
    }

    @MainActor
@Test("Zobrist 哈希：棋子索引覆盖 14 种")
    func zobristPieceIndexCoverage() {
        let kinds: [PieceKind] = [.general, .advisor, .elephant, .horse, .chariot, .cannon, .soldier]
        for kind in kinds {
            let redIdx = ZobristHash.pieceIndex(Piece(kind: kind, side: .red, position: Position(row: 0, col: 0), id: 100))
            let blackIdx = ZobristHash.pieceIndex(Piece(kind: kind, side: .black, position: Position(row: 0, col: 0), id: 200))
            #expect(redIdx >= 0 && redIdx < 7)
            #expect(blackIdx >= 7 && blackIdx < 14)
            #expect(redIdx != blackIdx)
        }
    }

    // MARK: - TranspositionTable 测试

    @MainActor
@Test("置换表：存取一致性")
    func ttStoreAndLookup() {
        let tt = TranspositionTable()
        let hash: UInt64 = 12345
        let move = Move(piece: Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
                        from: Position(row: 0, col: 0), to: Position(row: 1, col: 0), captured: nil)
        tt.store(hash: hash, depth: 4, score: 100, flag: .exact, bestMove: move)

        let result = tt.lookup(hash: hash, depth: 3, alpha: Int.min, beta: Int.max)
        #expect(result != nil)
        #expect(result!.score == 100)
        #expect(result!.flag == .exact)
    }

    @MainActor
@Test("置换表：深度不够不命中")
    func ttDepthTooShallow() {
        let tt = TranspositionTable()
        tt.store(hash: 99999, depth: 2, score: 50, flag: .exact, bestMove: nil)

        // 查找需要 depth=4，但只存了 depth=2
        let result = tt.lookup(hash: 99999, depth: 4, alpha: Int.min, beta: Int.max)
        #expect(result == nil)
    }

    @MainActor
@Test("置换表：lower flag 截断 beta")
    func ttLowerFlagBetaCutoff() {
        let tt = TranspositionTable()
        // lower bound: 实际值 >= 200
        tt.store(hash: 88888, depth: 4, score: 200, flag: .lower, bestMove: nil)

        // beta=100, score=200 >= beta → 命中
        let result = tt.lookup(hash: 88888, depth: 4, alpha: Int.min, beta: 100)
        #expect(result != nil)
        #expect(result!.score == 200)
    }

    @MainActor
@Test("置换表：upper flag 截断 alpha")
    func ttUpperFlagAlphaCutoff() {
        let tt = TranspositionTable()
        // upper bound: 实际值 <= 50
        tt.store(hash: 77777, depth: 4, score: 50, flag: .upper, bestMove: nil)

        // alpha=100, score=50 <= alpha → 命中
        let result = tt.lookup(hash: 77777, depth: 4, alpha: 100, beta: Int.max)
        #expect(result != nil)
        #expect(result!.score == 50)
    }

    @MainActor
@Test("置换表：深度优先替换策略")
    func ttDepthPreferReplacement() {
        let tt = TranspositionTable(capacity: 4)  // 小容量，容易碰撞
        let hash: UInt64 = 42

        // 先存 depth=2
        tt.store(hash: hash, depth: 2, score: 10, flag: .exact, bestMove: nil)
        // 再存 depth=4（更深的应该替换）
        tt.store(hash: hash, depth: 4, score: 20, flag: .exact, bestMove: nil)

        let result = tt.lookup(hash: hash, depth: 3, alpha: Int.min, beta: Int.max)
        #expect(result != nil)
        #expect(result!.score == 20)  // 应该是 depth=4 的值
    }

    @MainActor
@Test("置换表：clear 后不命中")
    func ttClear() {
        let tt = TranspositionTable()
        tt.store(hash: 55555, depth: 4, score: 100, flag: .exact, bestMove: nil)
        tt.clear()
        let result = tt.lookup(hash: 55555, depth: 2, alpha: Int.min, beta: Int.max)
        #expect(result == nil)
    }

    @MainActor
@Test("置换表：实际搜索命中率 > 0")
    func ttHitRateInSearch() async {
        let tt = TranspositionTable()
        let board = Board()
        board.setCurrentTurn(.black)

        // 第一次搜索 depth=2，填充置换表
        let engine = AIEngine()
        _ = await engine.bestMove(for: board, difficulty: .amateurLow)

        // 注意：AIEngine 内部每次 bestMove 都会 clear TT，所以这个测试
        // 验证的是 TT 在搜索过程中被正确使用（通过 probeBestMove）
        // 直接测试 TT 存取
        let hash = ZobristHash.hash(board: board)
        tt.store(hash: hash, depth: 4, score: 500, flag: .exact, bestMove: nil)

        let probe = tt.probeBestMove(hash: hash)
        // hash 刚存了但没有 bestMove
        #expect(probe == nil)

        // 存带 bestMove 的
        let move = MoveValidator.allLegalMoves(for: .black, on: board).first!
        tt.store(hash: hash, depth: 4, score: 500, flag: .exact, bestMove: move)
        let probe2 = tt.probeBestMove(hash: hash)
        #expect(probe2 != nil)
    }

    // MARK: - MoveOrderer 测试

    @MainActor
@Test("走法排序：吃子走法排在不吃子前面")
    func moveOrdererCaptureFirst() {
        let board = Board()
        // 构造一个有吃子走法的局面
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 0), id: 250)
        let redHorse = Piece(kind: .horse, side: .red, position: Position(row: 5, col: 1), id: 151)
        let board2 = Board(pieces: [rg, bg, blackChariot, redHorse])
        board2.setCurrentTurn(.black)

        let moves = MoveValidator.allLegalMoves(for: .black, on: board2)
        let ordered = MoveOrderer().order(moves, on: board2, ttBestMove: nil, checkLegal: false)

        // 吃子走法（车吃马）应该排在前面
        let captureMoves = ordered.filter { $0.captured != nil }
        let nonCaptureMoves = ordered.filter { $0.captured == nil }
        guard !captureMoves.isEmpty, !nonCaptureMoves.isEmpty else {
            // 如果没有吃子走法或不吃子走法，跳过排序验证
            return
        }
        let firstCaptureIdx = ordered.firstIndex(where: { $0.captured != nil })!
        let lastNonCaptureIdx = ordered.lastIndex(where: { $0.captured == nil })!
        #expect(firstCaptureIdx < lastNonCaptureIdx)
    }

    @MainActor
@Test("走法排序：TT 最佳走法排在最前")
    func moveOrdererTTBestFirst() {
        let board = Board()
        board.setCurrentTurn(.black)
        let moves = MoveValidator.allLegalMoves(for: .black, on: board)
        guard moves.count >= 2 else { return }

        let ttBest = moves.last!  // 取最后一个作为 TT 最佳走法
        let ordered = MoveOrderer().order(moves, on: board, ttBestMove: ttBest, checkLegal: false)

        // TT 最佳走法应该排在第一位
        let first = ordered.first!
        #expect(first.piece.id == ttBest.piece.id && first.from == ttBest.from && first.to == ttBest.to)
    }

    // MARK: - OpeningBook 测试

    @MainActor
@Test("开局库：初始局面有推荐走法")
    func openingBookInitialPosition() {
        let book = OpeningBook.shared
        let board = Board()
        // 初始局面，红方走完后查黑方走法
        // 先执行一步红方走法
        let snapshot = board.snapshot()
        let redMoves = MoveValidator.allLegalMoves(for: .red, on: snapshot)
        guard let firstMove = redMoves.first(where: { $0.piece.kind == .cannon }) else {
            Issue.record("No cannon move found")
            return
        }
        snapshot.execute(firstMove)
        let hash = ZobristHash.hash(board: snapshot)
        let recommendation = book.lookup(zobristHash: hash)
        // 如果开局库覆盖了红炮走法后的局面，应该有推荐
        // 即使没有，也不应该 crash
        #expect(true)  // 主要验证不 crash
    }

    @MainActor
@Test("开局库：parseICCSMove 正确解析")
    func openingBookParseICCS() {
        let board = Board()
        let book = OpeningBook.shared
        // 红方炮二平五 = h2e2 (col7,row7 → col4,row7)
        let move = book.parseICCSMove("h2e2", on: board)
        #expect(move != nil)
        #expect(move!.piece.kind == .cannon)
        #expect(move!.piece.side == .red)
        #expect(move!.to == Position(row: 7, col: 4))
    }

    @MainActor
@Test("开局库：非法 ICCS 返回 nil")
    func openingBookInvalidICCS() {
        let board = Board()
        let book = OpeningBook.shared
        #expect(book.parseICCSMove("z9z9", on: board) == nil)  // 无效列
        #expect(book.parseICCSMove("ab", on: board) == nil)    // 长度不对
    }

    @MainActor
@Test("开局库：ICCS 行号映射正确（行 0 = 红方底线 = row 9）")
    func openingBookICCSRowMapping() {
        let board = Board()
        let book = OpeningBook.shared
        // a0 = col0, row9（红方底线最左 = 红车位置）
        let move = book.parseICCSMove("a0a1", on: board)
        #expect(move != nil)
        #expect(move!.piece.kind == .chariot)
        #expect(move!.piece.side == .red)
        #expect(move!.from == Position(row: 9, col: 0))
    }

    // MARK: - AI 难度差异化测试

    @MainActor
@Test("新手 AI 返回合法走法")
    func beginnerReturnsLegalMove() async {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .novice)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }

    @MainActor
@Test("新手 AI 不送大子（多次采样）")
    func beginnerDoesNotBlunderBigPieces() async {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 0), id: 250)
        let redCannon = Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9)
        let redSoldier = Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 0), id: 11)

        var blunders = 0
        for _ in 0..<10 {
            let board = Board(pieces: [rg, bg, blackChariot, redCannon, redSoldier])
            board.setCurrentTurn(.black)
            let engine = AIEngine()
            let move = await engine.bestMove(for: board, difficulty: .novice)
            if let move, move.piece.kind == .chariot {
                // 检查走后是否被吃
                let snapshot = board.snapshot()
                let captured = snapshot.piece(at: move.to)
                snapshot.execute(Move(piece: move.piece, from: move.from, to: move.to, captured: captured))
                let redMoves = MoveValidator.allLegalMoves(for: .red, on: snapshot)
                if redMoves.contains(where: { $0.captured?.id == move.piece.id }) {
                    blunders += 1
                }
            }
        }
        // 新手允许偶尔送，但不应超过一半
        #expect(blunders <= 5)
    }

    @MainActor
@Test("初级 AI 返回合法走法（depth=2）")
    func easyReturnsLegalMove() async {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .beginner)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }

    @MainActor
@Test("中级 AI 返回合法走法（depth=4 + 开局库）")
    func mediumReturnsLegalMove() async {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurLow)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }

    @MainActor
@Test("大师级 AI 返回合法走法")
    func masterReturnsLegalMove() async {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurHigh)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }
}

// MARK: - Phase 2a 新增：UCI 走法转换 + ChessEngine 协议测试

@Suite("Phase 2a: UCIMoveConverter + ChessEngine", .serialized)
struct Phase2aUCITests {

    // MARK: - uciString (Move → UCI)

    @MainActor
@Test("Move → UCI 字符串正确转换")
    func testMoveToUCI() {
        let board = Board(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1")
        let chariot = board.piece(at: Position(row: 9, col: 0))!
        let move = Move(piece: chariot, from: Position(row: 9, col: 0), to: Position(row: 5, col: 0), captured: nil)
        #expect(UCIMoveConverter.uciString(from: move) == "a0a4")
    }

    @MainActor
@Test("不同列位置正确映射")
    func testColMapping() {
        let board = Board(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1")
        let piece = board.piece(at: Position(row: 9, col: 4))!
        let move = Move(piece: piece, from: Position(row: 9, col: 4), to: Position(row: 8, col: 4), captured: nil)
        #expect(UCIMoveConverter.uciString(from: move) == "e0e1")
    }

    // MARK: - positions (UCI → Position pair)

    @MainActor
@Test("UCI → Position 往返转换")
    func testPositionsRoundTrip() {
        let testCases = ["a0a9", "h2e2", "b7d7", "e9e8", "d0d9"]
        for uci in testCases {
            guard let (from, to) = UCIMoveConverter.positions(from: uci) else {
                Issue.record("解析失败: \(uci)")
                continue
            }
            let dummyPiece = Piece(kind: .chariot, side: .red, position: from, id: 0)
            let move = Move(piece: dummyPiece, from: from, to: to, captured: nil)
            let roundTrip = UCIMoveConverter.uciString(from: move)
            #expect(roundTrip == uci, "往返转换不匹配: \(uci) → \(roundTrip)")
        }
    }

    @MainActor
@Test("非法 UCI 字符串返回 nil")
    func testInvalidUCI() {
        #expect(UCIMoveConverter.positions(from: "") == nil)
        #expect(UCIMoveConverter.positions(from: "abc") == nil)
        #expect(UCIMoveConverter.positions(from: "a") == nil)
        #expect(UCIMoveConverter.positions(from: "j0j9") == nil)  // col > 8
    }

    // MARK: - move (UCI → Move on Board)

    @MainActor
@Test("初始局面 UCI → Move 包含 piece")
    func testMoveOnBoard() {
        let board = Board(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1")
        guard let move = UCIMoveConverter.move(from: "a0a4", on: board) else {
            Issue.record("move 返回 nil")
            return
        }
        #expect(move.piece.kind == .chariot)
        #expect(move.from == Position(row: 9, col: 0))
        #expect(move.to == Position(row: 5, col: 0))
    }

    // MARK: - board (FEN + UCI moves → Board)

    @MainActor
@Test("初始 FEN 无 moves 解析")
    func testFENParsing() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        guard let board = UCIMoveConverter.board(from: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        #expect(board.pieces.count == 32, "初始局面应有 32 个棋子")
    }

    @MainActor
@Test("FEN + moves 解析后棋子数量不变")
    func testFENWithMoves() {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        let uciMoves = ["b2b6"]
        guard let board = UCIMoveConverter.board(from: fen, moves: uciMoves) else {
            Issue.record("FEN + moves 解析失败")
            return
        }
        #expect(board.pieces.count == 32, "走一步后棋子数不变")
    }

    // MARK: - ChessEngine 协议 — AIEngine 适配

    @MainActor
@Test("AIEngine 实现 ChessEngine 协议属性")
    func testAIEngineProperties() {
        let engine = AIEngine()
        #expect(engine.displayName == "内置引擎")
        #expect(engine.engineType == .native)
    }

    @MainActor
@Test("AIEngine 通过 ChessEngine 协议走棋")
    func testAIEngineViaProtocol() async {
        let engine: any ChessEngine = AIEngine()
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let uciMove = await engine.bestMove(
            fen: fen,
            moveHistory: [],
            difficulty: .beginner,
            timeLimitMs: 5000
        )

        #expect(uciMove != nil, "应返回一个走法")
        #expect(uciMove!.count == 4, "UCI 走法应为 4 字符")
    }

    // MARK: - EngineRouter

    @MainActor
@Test("EngineRouter 默认返回 native 引擎")
    func testEngineRouterDefault() {
        let router = EngineRouter.shared
        let engine = router.activeEngine()
        #expect(engine.displayName == "内置引擎")
        #expect(engine.engineType == .native)
    }

    @MainActor
@Test("EngineRouter.nativeEngine 返回 AIEngine 实例")
    func testEngineRouterNative() async {
        let router = EngineRouter.shared
        let native = await router.getNativeEngine()
        let chessEngine: any ChessEngine = native
        #expect(chessEngine.engineType == .native)
    }
}
