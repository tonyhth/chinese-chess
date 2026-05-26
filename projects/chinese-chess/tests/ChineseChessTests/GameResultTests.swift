import Testing
@testable import ChineseChess

@Suite("胜负判定测试")
struct GameResultTests {

    // MARK: - 将死测试

    @Test("双车将死")
    func doubleChariotCheckmate() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let bc1 = Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 3))
        let bc2 = Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 5))
        let board = Board(pieces: [rg, bg, bc1, bc2])
        #expect(MoveValidator.isCheckmate(.red, on: board))
        #expect(MoveValidator.isInCheck(.red, on: board))
    }

    @Test("将帅对面+车将死")
    func generalFacingWithChariotCheckmate() {
        // 红帅 (9,4)，黑将 (0,4)，黑车 (8,4) 将军
        // 红帅可走 (8,4) 吃车，但吃车后将帅仍对面 → 送将
        // (9,3) (9,5) 不在车攻击范围内但需要验证
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let bc = Piece(kind: .chariot, side: .black, position: Position(row: 8, col: 4))
        // 需要额外黑子防止红帅走到 (9,3) (9,5)
        let bc2 = Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 3))
        let bc3 = Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 5))
        let board = Board(pieces: [rg, bg, bc, bc2, bc3])
        #expect(MoveValidator.isCheckmate(.red, on: board))
    }

    @Test("单车不能将死有路可走的情况")
    func singleChariotNotCheckmate() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let bc = Piece(kind: .chariot, side: .black, position: Position(row: 8, col: 0))
        let board = Board(pieces: [rg, bg, bc])
        #expect(!MoveValidator.isCheckmate(.red, on: board))
    }

    // MARK: - 困毙测试

    @Test("isStalemate 在将军场景返回 false")
    func checkmateIsNotStalemate() {
        // 使用双车将死（已验证为将死）
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let bc1 = Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 3))
        let bc2 = Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 5))
        let board = Board(pieces: [rg, bg, bc1, bc2])
        #expect(MoveValidator.isCheckmate(.red, on: board))
        #expect(!MoveValidator.isStalemate(.red, on: board))
    }

    @Test("困毙：红方所有棋子无合法走法且未被将军")
    func stalemateScenario() {
        // 构造困毙：红帅 (9,4) 周围被己方棋子完全封锁
        // 红帅可走：(8,4) (9,3) (9,5)
        // 用红方棋子堵住这三个位置
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let ra1 = Piece(kind: .advisor, side: .red, position: Position(row: 9, col: 3))
        let ra2 = Piece(kind: .advisor, side: .red, position: Position(row: 9, col: 5))
        let ra3 = Piece(kind: .advisor, side: .red, position: Position(row: 8, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        // 黑方需要棋子让红仕无法移动
        // ra1 (9,3) 可走 (8,2) (8,4) — (8,2) 不在九宫，(8,4) 有 ra3
        // ra2 (9,5) 可走 (8,4) 有 ra3, (8,6) 不在九宫
        // ra3 (8,4) 可走 (7,3) (7,5) (9,3) 有 ra1 (9,5) 有 ra2
        // (7,3) 和 (7,5) 在九宫内且无阻挡 → ra3 有合法走法
        // 所以这不是困毙... 需要进一步限制
        // 加黑炮控制 ra3 的走位
        let bh1 = Piece(kind: .horse, side: .black, position: Position(row: 5, col: 2))  // 控制 (7,3)
        let bh2 = Piece(kind: .horse, side: .black, position: Position(row: 5, col: 6))  // 控制 (7,5)
        // bh1 (5,2) 攻击 (7,3): dr=2, dc=1, legRow=6, legCol=2, (6,2) 无子 → 可以
        // ra3 走 (7,3) 后被 bh1 攻击 → 送将 → 不合法 ✓
        // bh2 (5,6) 攻击 (7,5): dr=2, dc=-1, legRow=6, legCol=6, (6,6) 无子 → 可以
        // ra3 走 (7,5) 后被 bh2 攻击 → 送将 → 不合法 ✓
        // 红帅不被将军？
        // bh1 (5,2) 不攻击 (9,4)
        // bh2 (5,6) 不攻击 (9,4)
        // bg (0,4) 将帅对面？同列，中间有 ra3(8,4) → 被阻隔 → 不对面 ✓
        let board = Board(pieces: [rg, ra1, ra2, ra3, bg, bh1, bh2])
        #expect(!MoveValidator.isInCheck(.red, on: board))
        #expect(MoveValidator.isStalemate(.red, on: board))
    }

    @Test("正常局面不是将死也不是困毙")
    func normalPositionNoTermination() {
        let board = Board()
        #expect(!MoveValidator.isCheckmate(.red, on: board))
        #expect(!MoveValidator.isCheckmate(.black, on: board))
        #expect(!MoveValidator.isStalemate(.red, on: board))
        #expect(!MoveValidator.isStalemate(.black, on: board))
    }

    @Test("非将死场景返回 false")
    func notCheckmateWhenHasMoves() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let board = Board(pieces: [rg, bg])
        // 将帅对面，但红帅可走 (9,3) 避开对面
        #expect(!MoveValidator.isCheckmate(.red, on: board))
    }
}
