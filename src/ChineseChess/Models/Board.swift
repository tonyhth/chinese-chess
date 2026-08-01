import Foundation

@Observable
class Board {
    private(set) var pieces: [Piece]
    private(set) var moveHistory: [Move] = []
    private(set) var currentTurn: Side = .red   // 红先手

    /// 切换走棋方（仅供 AI 空着裁剪内部使用，不维护 moveHistory 等状态）
    func toggleTurn() {
        currentTurn = (currentTurn == .red) ? .black : .red
    }

    // MARK: - 初始化

    init() {
        self.pieces = Self.initialPieces()
    }

    init(pieces: [Piece]) {
        self.pieces = pieces
    }

    /// 从 PositionSnapshot 重建 Board（v5.0 开局探索用）
    convenience init(snapshot: PositionSnapshot) {
        self.init(pieces: snapshot.pieces)
        self.currentTurn = snapshot.currentTurn
    }

    static func initialPieces() -> [Piece] {
        var p: [Piece] = []

        // 黑方（ID 16-31）
        p.append(Piece(kind: .chariot,  side: .black, position: Position(row: 0, col: 0), id: 16))  // 左车
        p.append(Piece(kind: .horse,    side: .black, position: Position(row: 0, col: 1), id: 18))  // 左马
        p.append(Piece(kind: .elephant, side: .black, position: Position(row: 0, col: 2), id: 20))  // 左象
        p.append(Piece(kind: .advisor,  side: .black, position: Position(row: 0, col: 3), id: 22))  // 左士
        p.append(Piece(kind: .general,  side: .black, position: Position(row: 0, col: 4), id: 24))  // 将
        p.append(Piece(kind: .advisor,  side: .black, position: Position(row: 0, col: 5), id: 23))  // 右士
        p.append(Piece(kind: .elephant, side: .black, position: Position(row: 0, col: 6), id: 21))  // 右象
        p.append(Piece(kind: .horse,    side: .black, position: Position(row: 0, col: 7), id: 19))  // 右马
        p.append(Piece(kind: .chariot,  side: .black, position: Position(row: 0, col: 8), id: 17))  // 右车
        p.append(Piece(kind: .cannon,   side: .black, position: Position(row: 2, col: 1), id: 25))  // 左炮
        p.append(Piece(kind: .cannon,   side: .black, position: Position(row: 2, col: 7), id: 26))  // 右炮
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 0), id: 27))  // 卒
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 2), id: 28))  // 卒
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 4), id: 29))  // 卒
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 6), id: 30))  // 卒
        p.append(Piece(kind: .soldier,  side: .black, position: Position(row: 3, col: 8), id: 31))  // 卒

        // 红方（ID 0-15）
        p.append(Piece(kind: .chariot,  side: .red, position: Position(row: 9, col: 0), id: 0))   // 左车
        p.append(Piece(kind: .horse,    side: .red, position: Position(row: 9, col: 1), id: 2))   // 左马
        p.append(Piece(kind: .elephant, side: .red, position: Position(row: 9, col: 2), id: 4))   // 左相
        p.append(Piece(kind: .advisor,  side: .red, position: Position(row: 9, col: 3), id: 6))   // 左仕
        p.append(Piece(kind: .general,  side: .red, position: Position(row: 9, col: 4), id: 8))   // 帅
        p.append(Piece(kind: .advisor,  side: .red, position: Position(row: 9, col: 5), id: 7))   // 右仕
        p.append(Piece(kind: .elephant, side: .red, position: Position(row: 9, col: 6), id: 5))   // 右相
        p.append(Piece(kind: .horse,    side: .red, position: Position(row: 9, col: 7), id: 3))   // 右马
        p.append(Piece(kind: .chariot,  side: .red, position: Position(row: 9, col: 8), id: 1))   // 右车
        p.append(Piece(kind: .cannon,   side: .red, position: Position(row: 7, col: 1), id: 9))   // 左炮
        p.append(Piece(kind: .cannon,   side: .red, position: Position(row: 7, col: 7), id: 10))  // 右炮
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 0), id: 11))  // 兵
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 2), id: 12))  // 兵
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 4), id: 13))  // 兵
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 6), id: 14))  // 兵
        p.append(Piece(kind: .soldier,  side: .red, position: Position(row: 6, col: 8), id: 15))  // 兵

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

    // MARK: - FEN 支持

    /// 从 FEN 初始化。解析失败时 fallback 到标准开局。
    convenience init(fen: String) {
        if let parsed = FENDecoder.parse(fen: fen) {
            self.init(pieces: parsed.pieces)
            self.currentTurn = parsed.currentTurn
        } else {
            self.init()
        }
    }

    /// 设置当前行走方（FEN 解析内部使用，不应外部调用）
    func setCurrentTurn(_ side: Side) {
        currentTurn = side
    }

    // MARK: - 深拷贝（AI 搜索用）

    /// ⚠️ 已废弃：返回 @Observable 副本，AI 引擎不应使用。
    /// AI 引擎请使用 SearchBoard(from: board)。
    /// UI 层仍可使用（主线程安全），但建议迁移到值类型方案。
    @available(*, deprecated, message: "AI 引擎请使用 SearchBoard(from: board)")
    func snapshot() -> Board {
        let copy = Board(pieces: pieces.map { Piece(kind: $0.kind, side: $0.side, position: $0.position, id: $0.id) })
        copy.moveHistory = moveHistory
        copy.currentTurn = currentTurn
        return copy
    }
}
