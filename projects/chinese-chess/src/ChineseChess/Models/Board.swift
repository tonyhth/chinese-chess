import Foundation

@Observable
class Board {
    private(set) var pieces: [Piece]
    private(set) var moveHistory: [Move] = []
    private(set) var currentTurn: Side = .red   // 红先手

    // MARK: - 初始化

    init() {
        self.pieces = Self.initialPieces()
    }

    init(pieces: [Piece]) {
        self.pieces = pieces
    }

    static func initialPieces() -> [Piece] {
        var p: [Piece] = []

        // 黑方
        p.append(Piece(kind: .chariot,  side: .black, position: Position(row: 0, col: 0)))
        p.append(Piece(kind: .horse,    side: .black, position: Position(row: 0, col: 1)))
        p.append(Piece(kind: .elephant, side: .black, position: Position(row: 0, col: 2)))
        p.append(Piece(kind: .advisor,  side: .black, position: Position(row: 0, col: 3)))
        p.append(Piece(kind: .general,  side: .black, position: Position(row: 0, col: 4)))
        p.append(Piece(kind: .advisor,  side: .black, position: Position(row: 0, col: 5)))
        p.append(Piece(kind: .elephant, side: .black, position: Position(row: 0, col: 6)))
        p.append(Piece(kind: .horse,    side: .black, position: Position(row: 0, col: 7)))
        p.append(Piece(kind: .chariot,  side: .black, position: Position(row: 0, col: 8)))
        p.append(Piece(kind: .cannon,   side: .black, position: Position(row: 2, col: 1)))
        p.append(Piece(kind: .cannon,   side: .black, position: Position(row: 2, col: 7)))
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 0)))
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 2)))
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 4)))
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 6)))
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 8)))

        // 红方
        p.append(Piece(kind: .chariot,  side: .red, position: Position(row: 9, col: 0)))
        p.append(Piece(kind: .horse,    side: .red, position: Position(row: 9, col: 1)))
        p.append(Piece(kind: .elephant, side: .red, position: Position(row: 9, col: 2)))
        p.append(Piece(kind: .advisor,  side: .red, position: Position(row: 9, col: 3)))
        p.append(Piece(kind: .general,  side: .red, position: Position(row: 9, col: 4)))
        p.append(Piece(kind: .advisor,  side: .red, position: Position(row: 9, col: 5)))
        p.append(Piece(kind: .elephant, side: .red, position: Position(row: 9, col: 6)))
        p.append(Piece(kind: .horse,    side: .red, position: Position(row: 9, col: 7)))
        p.append(Piece(kind: .chariot,  side: .red, position: Position(row: 9, col: 8)))
        p.append(Piece(kind: .cannon,   side: .red, position: Position(row: 7, col: 1)))
        p.append(Piece(kind: .cannon,   side: .red, position: Position(row: 7, col: 7)))
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 0)))
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 2)))
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 4)))
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 6)))
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 8)))

        return p
    }

    // MARK: - 查询

    func piece(at pos: Position) -> Piece? {
        pieces.first { $0.position == pos }
    }

    func pieces(for side: Side) -> [Piece] {
        pieces.filter { $0.side == side }
    }

    func generalPosition(of side: Side) -> Position? {
        pieces.first { $0.kind == .general && $0.side == side }?.position
    }

    func hasPiece(at pos: Position) -> Bool {
        pieces.contains { $0.position == pos }
    }

    // MARK: - 走法执行

    func execute(_ move: Move) {
        // 移除被吃棋子
        if let captured = move.captured {
            pieces.removeAll { $0.id == captured.id }
        }
        // 移动棋子到新位置
        if let idx = pieces.firstIndex(where: { $0.id == move.piece.id }) {
            pieces[idx].position = move.to
        }
        moveHistory.append(move)
        currentTurn = (currentTurn == .red) ? .black : .red
    }

    func undoLastMove() -> Move? {
        guard let move = moveHistory.popLast() else { return nil }

        // 将棋子移回原位
        if let idx = pieces.firstIndex(where: { $0.id == move.piece.id }) {
            pieces[idx].position = move.from
        }
        // 恢复被吃棋子
        if let captured = move.captured {
            pieces.append(captured)
        }

        currentTurn = (currentTurn == .red) ? .black : .red
        return move
    }

    // MARK: - 深拷贝（AI 搜索用）

    func snapshot() -> Board {
        let copy = Board(pieces: pieces.map { Piece(kind: $0.kind, side: $0.side, position: $0.position, id: $0.id) })
        copy.moveHistory = moveHistory
        copy.currentTurn = currentTurn
        return copy
    }
}
