// LegacySearchBoard.swift — AI 引擎专用棋盘（纯值类型，脱离 @Observable）

/// AI 搜索专用棋盘。纯值类型，无线程安全风险。
///
/// **M1 Phase 2a（m1-hotpath-redesign v1.2 §7.1）**：原 SearchBoard.swift 更名
/// LegacySearchBoard——与 SearchBoardV2（90 格信箱）双实现并存至 P2d 收敛，
/// 交叉对比期间作为运行时参照（§8.2）。除名字外零行为改动。
///
/// 设计要点：
/// - 不继承 @Observable，不注册到 Observation 全局表
/// - 实现 BoardReadable 协议，可传入 MoveValidator 等泛型方法
/// - execute/undo 是 mutating，配合 inout 避免不必要拷贝
/// - moveHistory 使用 [Move]（与 Board 一致，降低初期改动复杂度）
struct LegacySearchBoard: BoardReadable {
    private(set) var pieces: [Piece]
    private(set) var currentTurn: Side = .red
    private(set) var moveHistory: [Move] = []

    // MARK: - BoardReadable

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

    func makeSearchBoard() -> LegacySearchBoard {
        self  // 值类型赋值即深拷贝，COW 可优化
    }

    // MARK: - 初始化

    /// 从 Board 创建（AI 入口唯一转换点）
    /// ⚠️ 依赖 board.pieces 返回 [Piece] 数组。如果 Board 将来改 pieces 存储结构（如字典），
    /// 需同步更新此处映射逻辑。
    init(from board: Board) {
        self.pieces = board.pieces.map {
            Piece(kind: $0.kind, side: $0.side, position: $0.position, id: $0.id)
        }
        self.currentTurn = board.currentTurn
        self.moveHistory = board.moveHistory
    }

    /// 标准开局
    init() {
        self.pieces = Board.initialPieces()
    }

    /// 直接构造
    init(pieces: [Piece], currentTurn: Side = .red, moveHistory: [Move] = []) {
        self.pieces = pieces
        self.currentTurn = currentTurn
        self.moveHistory = moveHistory
    }

    // MARK: - 走法执行（mutating，配合 inout 使用避免 COW）

    mutating func execute(_ move: Move) {
        if let captured = move.captured {
            pieces.removeAll { $0.id == captured.id }
        }
        if let idx = pieces.firstIndex(where: { $0.id == move.piece.id }) {
            pieces[idx].position = move.to
        }
        moveHistory.append(move)
        currentTurn = (currentTurn == .red) ? .black : .red
        // P0 遥测：Debug 下检出腐败 dump-继续（与 Board 同语义，详见 Board.swift 注释）
        #if DEBUG
        let problems = Board.integrityProblems(in: pieces)
        if !problems.isEmpty {
            BoardIntegrityLogger.dumpOverlap(reason: "LegacySearchBoard.execute",
                                             pieces: pieces,
                                             recentMoves: Array(moveHistory.suffix(10)),
                                             detail: problems.joined(separator: " | "))
        }
        #endif
    }

    @discardableResult
    mutating func undoLastMove() -> Move? {
        guard let move = moveHistory.popLast() else { return nil }

        if let idx = pieces.firstIndex(where: { $0.id == move.piece.id }) {
            pieces[idx].position = move.from
        }
        if let captured = move.captured {
            pieces.append(captured)
        }

        currentTurn = (currentTurn == .red) ? .black : .red
        // P0 遥测：Debug 下检出腐败 dump-继续
        #if DEBUG
        let problems = Board.integrityProblems(in: pieces)
        if !problems.isEmpty {
            BoardIntegrityLogger.dumpOverlap(reason: "LegacySearchBoard.undoLastMove",
                                             pieces: pieces,
                                             recentMoves: Array(moveHistory.suffix(10)),
                                             detail: problems.joined(separator: " | "))
        }
        #endif
        return move
    }

    mutating func toggleTurn() {
        currentTurn = (currentTurn == .red) ? .black : .red
    }
}
