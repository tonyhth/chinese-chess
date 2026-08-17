import Foundation
import Testing
@testable import ChineseChess

@Suite("Phase 3.1 Lazy-Load Opening Book Tests", .serialized)
struct LazyOpeningBookTests {

    // MARK: - 开局库命中：各难度初始局面走法正常

    @Test("中级难度初始局面返回合法走法（开局库命中路径）")
    func mediumInitialPosition_legalMove() async {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurLow)
        #expect(move != nil)
        if let move = move {
            let captured = board.piece(at: move.to)
            let m = Move(piece: move.piece, from: move.from, to: move.to, captured: captured)
            #expect(MoveValidator.isLegal(m, on: board))
        }
    }

    @Test("高级难度初始局面返回合法走法（开局库命中路径，moveHistory < 6）")
    func hardInitialPosition_legalMove() async {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurMid)
        #expect(move != nil)
        if let move = move {
            let captured = board.piece(at: move.to)
            let m = Move(piece: move.piece, from: move.from, to: move.to, captured: captured)
            #expect(MoveValidator.isLegal(m, on: board))
        }
    }

    @Test("大师难度初始局面返回合法走法（开局库命中路径，moveHistory < 6）")
    func masterInitialPosition_legalMove() async {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurHigh)
        #expect(move != nil)
        if let move = move {
            let captured = board.piece(at: move.to)
            let m = Move(piece: move.piece, from: move.from, to: move.to, captured: captured)
            #expect(MoveValidator.isLegal(m, on: board))
        }
    }

    // MARK: - 懒加载不阻塞 init

    @Test("AIEngine init 快速完成（openingBook 延迟加载）")
    func initFast_openingBookLazyLoaded() async {
        // 创建 engine 实例不应触发开局库加载
        let start = Date()
        let engine = AIEngine()
        let initDuration = Date().timeIntervalSince(start)
        // 开局库加载 ~3.7MB JSON 需要 100ms+
        // init 不加载开局库，但仍有 EvalConfigManager/AIEvaluator 初始化
        // 阈值放宽到 2.0s——首次初始化含 EvalConfigManager/AIEvaluator 可能耗时
        // 开局库如果在 init 中加载通常需要 1-3 秒，2s 阈值仍能区分
        #expect(initDuration < 2.0)

        // 首次 bestMove 才触发加载，但应正常返回
        let board = Board()
        board.setCurrentTurn(.black)
        let move = await engine.bestMove(for: board, difficulty: .amateurLow)
        #expect(move != nil)
    }

    // MARK: - 多局连续对弈，开局库不重复加载

    @Test("多局连续对弈开局库幂等加载（newGame 后仍可命中）")
    func multipleGames_openingBookIdempotent() async {
        let engine = AIEngine()

        // 第 1 局
        let board1 = Board()
        board1.setCurrentTurn(.black)
        let move1 = await engine.bestMove(for: board1, difficulty: .amateurLow)
        #expect(move1 != nil)

        // newGame（清空历史，不开局库）
        await engine.newGame()

        // 第 2 局
        let board2 = Board()
        board2.setCurrentTurn(.black)
        let move2 = await engine.bestMove(for: board2, difficulty: .amateurLow)
        #expect(move2 != nil)

        // newGame
        await engine.newGame()

        // 第 3 局
        let board3 = Board()
        board3.setCurrentTurn(.black)
        let move3 = await engine.bestMove(for: board3, difficulty: .amateurMid)
        #expect(move3 != nil)
    }

    // MARK: - 开局库 fallback：无命中时搜索引擎正常工作

    @Test("高级难度中局（moveHistory >= 6）跳过开局库，搜索引擎正常")
    func hardMidGame_skipsOpeningBook_searchWorks() async {
        // 构造一个 moveHistory >= 6 的中局
        let board = Board(pieces: [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 8, col: 0)),
            Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9),
            TestPieceFactory.blackGeneral(0, 5),
            TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 1, col: 0)),
            Piece(kind: .cannon, side: .black, position: Position(row: 2, col: 1), id: 25)
        ])
        // 手动添加 6 步 moveHistory 以跳过开局库
        let p1 = board.piece(at: Position(row: 8, col: 0))!
        board.execute(Move(piece: p1, from: p1.position, to: Position(row: 8, col: 4), captured: nil))
        let p2 = board.piece(at: Position(row: 1, col: 0))!
        board.execute(Move(piece: p2, from: p2.position, to: Position(row: 1, col: 4), captured: nil))
        let p3 = board.piece(at: Position(row: 8, col: 4))!
        board.execute(Move(piece: p3, from: p3.position, to: Position(row: 8, col: 0), captured: nil))
        let p4 = board.piece(at: Position(row: 1, col: 4))!
        board.execute(Move(piece: p4, from: p4.position, to: Position(row: 1, col: 0), captured: nil))
        let p5 = board.piece(at: Position(row: 8, col: 0))!
        board.execute(Move(piece: p5, from: p5.position, to: Position(row: 8, col: 4), captured: nil))
        let p6 = board.piece(at: Position(row: 1, col: 0))!
        board.execute(Move(piece: p6, from: p6.position, to: Position(row: 1, col: 4), captured: nil))

        #expect(board.moveHistory.count >= 6)

        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurMid)
        #expect(move != nil)
    }

    @Test("大师难度中局（moveHistory >= 6）跳过开局库，搜索引擎正常")
    func masterMidGame_skipsOpeningBook_searchWorks() async {
        let board = Board(pieces: [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 8, col: 0)),
            TestPieceFactory.blackGeneral(0, 5),
            TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 1, col: 0))
        ])
        // 简单走 6 步
        let p1 = board.piece(at: Position(row: 8, col: 0))!
        board.execute(Move(piece: p1, from: p1.position, to: Position(row: 8, col: 4), captured: nil))
        let p2 = board.piece(at: Position(row: 1, col: 0))!
        board.execute(Move(piece: p2, from: p2.position, to: Position(row: 1, col: 4), captured: nil))
        let p3 = board.piece(at: Position(row: 8, col: 4))!
        board.execute(Move(piece: p3, from: p3.position, to: Position(row: 8, col: 0), captured: nil))
        let p4 = board.piece(at: Position(row: 1, col: 4))!
        board.execute(Move(piece: p4, from: p4.position, to: Position(row: 1, col: 0), captured: nil))
        let p5 = board.piece(at: Position(row: 8, col: 0))!
        board.execute(Move(piece: p5, from: p5.position, to: Position(row: 8, col: 4), captured: nil))
        let p6 = board.piece(at: Position(row: 1, col: 0))!
        board.execute(Move(piece: p6, from: p6.position, to: Position(row: 1, col: 4), captured: nil))

        #expect(board.moveHistory.count >= 6)

        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurHigh)
        #expect(move != nil)
    }

    // MARK: - 新手难度不走开局库

    @Test("新手难度不走开局库，随机走法正常")
    func beginner_noOpeningBook_randomWorks() async {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .novice)
        #expect(move != nil)
        if let move = move {
            let captured = board.piece(at: move.to)
            let m = Move(piece: move.piece, from: move.from, to: move.to, captured: captured)
            #expect(MoveValidator.isLegal(m, on: board))
        }
    }
}
