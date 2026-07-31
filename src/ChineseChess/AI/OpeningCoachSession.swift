import Foundation

// MARK: - Phase B3 Step 1: 开局教练会话

/// 开局教练会话状态
enum CoachSessionStatus: String, Codable {
    case inProgress
    case completed    // 走出开局区域
    case abandoned
}

/// 开局教练会话
struct OpeningCoachSession: Codable {
    let id: UUID
    /// 目标开局子分类 ID
    let openingId: String
    /// 用户执哪方（默认红）
    let playerSide: Side
    let startedAt: Date
    /// 用户已走的每步 + 评估
    var moves: [CoachedMove]
    /// 会话状态
    var status: CoachSessionStatus

    init(
        id: UUID = UUID(),
        openingId: String,
        playerSide: Side = .red,
        startedAt: Date = Date(),
        moves: [CoachedMove] = [],
        status: CoachSessionStatus = .inProgress
    ) {
        self.id = id
        self.openingId = openingId
        self.playerSide = playerSide
        self.startedAt = startedAt
        self.moves = moves
        self.status = status
    }

    /// 当前局面 FEN
    ///
    /// 从标准开局开始，依次执行每步走法推算。
    /// 推算失败时返回已执行的最后一个合法局面的 FEN。
    var currentFEN: String {
        let board = Board(fen: FENParser.standardInitial)
        for coachedMove in moves {
            guard let move = ICCSParser.parse(coachedMove.move, on: board) else {
                return FENParser.generate(board: board)
            }
            board.execute(move)
        }
        return FENParser.generate(board: board)
    }

    /// 添加走法（自动追加，无需手动填 moveIndex）
    mutating func appendMove(_ coachedMove: CoachedMove) {
        moves.append(coachedMove)
    }

    /// 整体准确率（书谱 + 精妙 + 好棋 / 总步数）
    var accuracy: Double {
        guard !moves.isEmpty else { return 0 }
        let good = moves.filter { $0.quality == .book || $0.quality == .brilliant || $0.quality == .good }.count
        return Double(good) / Double(moves.count)
    }
}
