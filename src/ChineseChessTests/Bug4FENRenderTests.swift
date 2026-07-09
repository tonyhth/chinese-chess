import XCTest
@testable import ChineseChess

/// Bug 4: 验证第9局和第27局的 FEN 解析和棋盘渲染中是否丢失将帅
final class Bug4FENRenderTests: XCTestCase {

    /// 第9局 (sqyq_009 神龟出洛) FEN 包含将帅
    func testPuzzle9_KingPresent() throws {
        let fen = "3a1k3/1C7/c4a3/8N/3P5/9/8C/B8/r2pnpp2/4K1cRR w - - 0 1"
        let board = Board(fen: fen)

        // 验证红帅存在
        let redKing = board.generalPosition(of: .red)
        XCTAssertNotNil(redKing, "第9局应包含红帅")
        XCTAssertEqual(redKing, Position(row: 9, col: 4), "红帅应在 (9,4)")

        // 验证黑将/帅存在
        let blackKing = board.generalPosition(of: .black)
        XCTAssertNotNil(blackKing, "第9局应包含黑方将/帅")
        XCTAssertEqual(blackKing, Position(row: 0, col: 5), "黑方将/帅应在 (0,5)")
    }

    /// 第27局 (sqyq_027 藕断丝牵) FEN 包含将帅
    func testPuzzle27_KingPresent() throws {
        let fen = "2bP1k2r/1nn1P4/3cbc3/9/2p3P1p/7RC/9/4p4/3p1R3/2pCK4 w - - 0 1"
        let board = Board(fen: fen)

        let redKing = board.generalPosition(of: .red)
        XCTAssertNotNil(redKing, "第27局应包含红帅")
        XCTAssertEqual(redKing, Position(row: 9, col: 4), "红帅应在 (9,4)")

        let blackKing = board.generalPosition(of: .black)
        XCTAssertNotNil(blackKing, "第27局应包含黑方将/帅")
        XCTAssertEqual(blackKing, Position(row: 0, col: 5), "黑方将/帅应在 (0,5)")
    }

    /// 全部 551 局都有将帅
    func testAll551Puzzles_HaveKings() throws {
        let puzzles = PuzzleStore.shared.puzzles
        XCTAssertEqual(puzzles.count, 551, "应有 551 局")

        var missingRedKing: [String] = []
        var missingBlackKing: [String] = []

        for puzzle in puzzles {
            let board = Board(fen: puzzle.initialFEN)
            if board.generalPosition(of: .red) == nil {
                missingRedKing.append(puzzle.id)
            }
            if board.generalPosition(of: .black) == nil {
                missingBlackKing.append(puzzle.id)
            }
        }

        XCTAssertTrue(missingRedKing.isEmpty, "缺少红帅的残局: \(missingRedKing)")
        XCTAssertTrue(missingBlackKing.isEmpty, "缺少黑将的残局: \(missingBlackKing)")
    }

    /// 验证 PuzzleStore 中第9局和第27局的 id 匹配
    func testPuzzle9And27_IDMapping() {
        let puzzles = PuzzleStore.shared.puzzles

        // 第9局 id 应为 sqyq_009
        let p9 = puzzles.first { $0.id == "sqyq_009" }
        XCTAssertNotNil(p9, "sqyq_009 应存在")
        XCTAssertEqual(p9?.name, "第9局 神龟出洛")

        // 第27局 id 应为 sqyq_027
        let p27 = puzzles.first { $0.id == "sqyq_027" }
        XCTAssertNotNil(p27, "sqyq_027 应存在")
        XCTAssertEqual(p27?.name, "第27局 藕断丝牵")
    }
}
