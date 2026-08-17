import Testing
@testable import ChineseChess

@Suite("走棋规则边界测试")
struct EdgeCaseTests {

    // 辅助：最小棋盘
    private func makeBoard(redGeneralCol: Int = 3, blackGeneralCol: Int = 5, extra: [Piece] = []) -> Board {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: redGeneralCol), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: blackGeneralCol), id: 24)
        return Board(pieces: [rg, bg] + extra)
    }

    // MARK: - 将帅对面

    @Test("将帅同列无阻隔 = 双方均被将军")
    func generalsFacingNoBlocker() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let board = Board(pieces: [rg, bg])
        #expect(MoveValidator.isInCheck(.red, on: board))
        #expect(MoveValidator.isInCheck(.black, on: board))
    }

    @Test("将帅同列中间有子 = 不算对面")
    func generalsBlockedByPiece() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let blocker = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 4, col: 4))
        let board = Board(pieces: [rg, bg, blocker])
        #expect(!MoveValidator.isInCheck(.red, on: board))
        #expect(!MoveValidator.isInCheck(.black, on: board))
    }

    @Test("将帅不同列 = 不算对面")
    func generalsDifferentColumns() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = TestPieceFactory.blackGeneral(0, 3)
        let board = Board(pieces: [rg, bg])
        #expect(!MoveValidator.isInCheck(.red, on: board))
        #expect(!MoveValidator.isInCheck(.black, on: board))
    }

    @Test("将帅面对面中间有多子但仍有一格空隙不算对面")
    func generalsPartiallyBlocked() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let p1 = Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4), id: 13)
        let p2 = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 7, col: 4))
        // row 5 和 row 8 为空，有阻隔
        let board = Board(pieces: [rg, bg, p1, p2])
        #expect(!MoveValidator.isInCheck(.red, on: board))
    }

    // MARK: - 蹩马腿

    @Test("马八方向蹩腿完整测试")
    func horseBlockedAllDirections() {
        // 马在 (4,4)，八个方向各测试蹩腿
        let horse = TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 4, col: 4))
        let blockers: [Position] = [
            Position(row: 3, col: 4),  // 蹩上
            Position(row: 5, col: 4),  // 蹩下
            Position(row: 4, col: 3),  // 蹩左
            Position(row: 4, col: 5),  // 蹩右
        ]
        let blockerPieces = blockers.map { Piece(kind: .soldier, side: .red, position: $0, id: 11) }
        let board = makeBoard(extra: [horse] + blockerPieces)
        let moves = MoveValidator.legalMoves(for: horse, on: board)
        let targets = Set(moves.map { $0.to })

        // 所有 8 个目标位置都被蹩腿
        #expect(!targets.contains(Position(row: 2, col: 3)))  // 左上蹩上
        #expect(!targets.contains(Position(row: 2, col: 5)))  // 右上蹩上
        #expect(!targets.contains(Position(row: 6, col: 3)))  // 左下蹩下
        #expect(!targets.contains(Position(row: 6, col: 5)))  // 右下蹩下
        #expect(!targets.contains(Position(row: 3, col: 2)))  // 上左蹩左
        #expect(!targets.contains(Position(row: 5, col: 2)))  // 下左蹩左
        #expect(!targets.contains(Position(row: 3, col: 6)))  // 上右蹩右
        #expect(!targets.contains(Position(row: 5, col: 6)))  // 下右蹩右

        // 蹩腿后马应该没有合法走法
        #expect(targets.isEmpty)
    }

    @Test("马无蹩腿可走全部方向")
    func horseNoBlocking() {
        let horse = TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 4, col: 4))
        let board = makeBoard(extra: [horse])
        let moves = MoveValidator.legalMoves(for: horse, on: board)
        let targets = Set(moves.map { $0.to })
        // 中心位置 8 个方向都可达
        #expect(targets.contains(Position(row: 2, col: 3)))
        #expect(targets.contains(Position(row: 2, col: 5)))
        #expect(targets.contains(Position(row: 6, col: 3)))
        #expect(targets.contains(Position(row: 6, col: 5)))
        #expect(targets.contains(Position(row: 3, col: 2)))
        #expect(targets.contains(Position(row: 3, col: 6)))
        #expect(targets.contains(Position(row: 5, col: 2)))
        #expect(targets.contains(Position(row: 5, col: 6)))
        #expect(targets.count == 8)
    }

    // MARK: - 塞象眼

    @Test("象四个方向塞眼完整测试")
    func elephantBlockedAllEyes() {
        let elephant = TestPieceFactory.makePiece(kind: .elephant, side: .red, position: Position(row: 7, col: 2))
        let blockers: [Piece] = [
            TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 6, col: 1)),  // 左上眼
            TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 6, col: 3)),  // 右上眼
            TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 8, col: 1)),  // 左下眼
            TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 8, col: 3)),  // 右下眼
        ]
        let board = makeBoard(extra: [elephant] + blockers)
        let moves = MoveValidator.legalMoves(for: elephant, on: board)
        #expect(moves.isEmpty)
    }

    @Test("象不能过河")
    func elephantCannotCrossRiver() {
        let elephant = TestPieceFactory.makePiece(kind: .elephant, side: .red, position: Position(row: 5, col: 2))
        // row 5 是红方领地最后一行，合法；但 (3,0) 等过河了
        let board = makeBoard(extra: [elephant])
        let moves = MoveValidator.legalMoves(for: elephant, on: board)
        let targets = Set(moves.map { $0.to })
        // (3,0), (3,4) 过了河（<=4），不允许
        #expect(!targets.contains(Position(row: 3, col: 0)))
        #expect(!targets.contains(Position(row: 3, col: 4)))
        // (7,0), (7,4) 在己方领地，允许
        #expect(targets.contains(Position(row: 7, col: 0)))
        #expect(targets.contains(Position(row: 7, col: 4)))
    }

    // MARK: - 炮翻架

    @Test("炮无架不能吃子")
    func cannonCannotCaptureWithoutMount() {
        let cannon = TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 7, col: 0))
        let target = TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 7, col: 3))
        let board = makeBoard(extra: [cannon, target])
        let moves = MoveValidator.legalMoves(for: cannon, on: board)
        let captureMoves = moves.filter { $0.captured != nil }
        #expect(captureMoves.isEmpty)
    }

    @Test("炮翻一个架可吃子")
    func cannonCaptureWithOneMount() {
        let cannon = TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 7, col: 0))
        let mount = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 7, col: 2))
        let target = TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 7, col: 4))
        let board = makeBoard(extra: [cannon, mount, target])
        let moves = MoveValidator.legalMoves(for: cannon, on: board)
        let captureTarget = moves.first { $0.captured != nil && $0.to == Position(row: 7, col: 4) }
        #expect(captureTarget != nil)
    }

    @Test("炮翻两个架不能吃子")
    func cannonCannotCaptureWithTwoMounts() {
        let cannon = TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 7, col: 0))
        let mount1 = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 7, col: 2))
        let mount2 = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 7, col: 3))
        let target = TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 7, col: 5))
        let board = makeBoard(extra: [cannon, mount1, mount2, target])
        let moves = MoveValidator.legalMoves(for: cannon, on: board)
        let captureTarget = moves.first { $0.to == Position(row: 7, col: 5) }
        #expect(captureTarget == nil)
    }

    @Test("炮纵向翻架吃子")
    func cannonVerticalCapture() {
        let cannon = TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 5, col: 4))
        let mount = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 4, col: 4))
        let target = Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 4), id: 29)
        let board = makeBoard(extra: [cannon, mount, target])
        let moves = MoveValidator.legalMoves(for: cannon, on: board)
        let captureTarget = moves.first { $0.to == Position(row: 3, col: 4) }
        #expect(captureTarget != nil)
        #expect(captureTarget?.captured?.kind == .soldier)
    }

    // MARK: - 过河兵

    @Test("兵过河后不能后退")
    func soldierCannotRetreatAfterCrossing() {
        let soldier = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 4, col: 4))
        let board = makeBoard(extra: [soldier])
        let moves = MoveValidator.legalMoves(for: soldier, on: board)
        let targets = Set(moves.map { $0.to })
        // 不能后退 (row 5)
        #expect(!targets.contains(Position(row: 5, col: 4)))
        #expect(!targets.contains(Position(row: 5, col: 3)))
        #expect(!targets.contains(Position(row: 5, col: 5)))
    }

    @Test("兵在边路过河后只有两个方向")
    func soldierAtEdgeAfterCrossing() {
        // 红兵在 (4,0) 过河后，只能前进和向右（左边界）
        let soldier = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 4, col: 0))
        let board = makeBoard(extra: [soldier])
        let moves = MoveValidator.legalMoves(for: soldier, on: board)
        let targets = Set(moves.map { $0.to })
        #expect(targets.count == 2)
        #expect(targets.contains(Position(row: 3, col: 0)))  // 前进
        #expect(targets.contains(Position(row: 4, col: 1)))  // 右
    }

    @Test("黑卒过河行为对称")
    func blackSoldierAfterCrossing() {
        let soldier = TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 5, col: 4))
        let board = makeBoard(extra: [soldier])
        let moves = MoveValidator.legalMoves(for: soldier, on: board)
        let targets = Set(moves.map { $0.to })
        // 黑卒前进方向是 +row
        #expect(targets.contains(Position(row: 6, col: 4)))  // 前进
        #expect(targets.contains(Position(row: 5, col: 3)))  // 左
        #expect(targets.contains(Position(row: 5, col: 5)))  // 右
        #expect(!targets.contains(Position(row: 4, col: 4)))  // 不能后退
    }

    // MARK: - 将/帅九宫限制

    @Test("将不能出九宫")
    func generalCannotLeavePalace() {
        let rg = TestPieceFactory.redGeneral(8, 3)
        let board = Board(pieces: [rg, TestPieceFactory.blackGeneral(0, 5)])
        let moves = MoveValidator.legalMoves(for: rg, on: board)
        let targets = Set(moves.map { $0.to })
        // (7,2) 和 (7,3) 在九宫内，(8,2) 在九宫外
        #expect(targets.contains(Position(row: 7, col: 3)))
        #expect(targets.contains(Position(row: 9, col: 3)))
        #expect(targets.contains(Position(row: 8, col: 4)))
        // 出九宫的位置不应出现
        for pos in targets {
            #expect(pos.isInRedPalace)
        }
    }

    @Test("士不能出九宫")
    func advisorCannotLeavePalace() {
        let advisor = TestPieceFactory.makePiece(kind: .advisor, side: .red, position: Position(row: 8, col: 4))
        let board = makeBoard(extra: [advisor])
        let moves = MoveValidator.legalMoves(for: advisor, on: board)
        for move in moves {
            #expect(move.to.isInRedPalace)
        }
    }

    // MARK: - 车边界

    @Test("车吃子不越过被吃子")
    func chariotCannotMoveBeyondCapture() {
        let chariot = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let target = Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0), id: 27)
        let behind = TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 2, col: 0))
        let board = makeBoard(extra: [chariot, target, behind])
        let moves = MoveValidator.legalMoves(for: chariot, on: board)
        let targets = Set(moves.map { $0.to })
        #expect(targets.contains(Position(row: 3, col: 0)))  // 吃 target
        #expect(!targets.contains(Position(row: 2, col: 0)))  // 不能越过
    }
}
