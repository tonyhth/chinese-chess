import Foundation

// MARK: - 走法记录（面向视图层的不可变记录）

/// 与 v1.0 Move 的关系：
/// - Move: AI 搜索内部使用的轻量走法，用于 Board.execute/undoLastMove 和 minimax
/// - GameMove: 面向视图层的不可变记录，含棋谱文本、时间戳、将军标记等展示信息
///
/// 创建方式：GameViewModel 走棋后一次性构建，isCheck/isCheckmate 在 execute 后判断。
/// NotationGenerator（Phase 3 实现）将在走棋前生成 notation。
/// 当前 notation 暂为空字符串占位，不影响数据结构完整性。
struct GameMove: Identifiable, Codable {
    let id: UUID
    let piece: Piece           // 移动的棋子
    let from: Position         // 起点
    let to: Position           // 终点
    let captured: Piece?       // 被吃棋子

    // v2.0 新增
    let turnNumber: Int        // 回合号（从 1 开始，红黑各走一次 = 1 回合）
    let notation: String       // 棋谱文本占位，Phase 3 NotationGenerator 实现后填充
    let timestamp: Date        // 走棋时间
    let isCheck: Bool          // 是否将军
    var isCheckmate: Bool     // 是否将死（走棋后延迟标记）
    let halfmoveClock: Int    // #3: 走棋后的 halfmoveClock 快照，悔棋时恢复

    // v4.0 Phase 6: 长捉检测（P0-1 修正：使用 Piece.id Int）
    var isChase: Bool = false           // 是否"捉"（攻击对方有价值棋子）
    var chaseAttackerId: Int? = nil     // 捉的攻击棋子 ID（Piece.id）
    var chaseTargetId: Int? = nil       // 捉的目标棋子 ID（Piece.id）

    // P1 fix: 自定义 CodingKeys + decodeIfPresent 保证旧数据兼容
    enum CodingKeys: String, CodingKey {
        case id, piece, from, to, captured
        case turnNumber, notation, timestamp
        case isCheck, isCheckmate, halfmoveClock
        case isChase, chaseAttackerId, chaseTargetId
    }

    // Memberwise initializer（自定义 init(from:) 后需显式提供）
    init(id: UUID, piece: Piece, from: Position, to: Position, captured: Piece?,
         turnNumber: Int, notation: String, timestamp: Date,
         isCheck: Bool, isCheckmate: Bool, halfmoveClock: Int,
         isChase: Bool = false, chaseAttackerId: Int? = nil, chaseTargetId: Int? = nil) {
        self.id = id
        self.piece = piece
        self.from = from
        self.to = to
        self.captured = captured
        self.turnNumber = turnNumber
        self.notation = notation
        self.timestamp = timestamp
        self.isCheck = isCheck
        self.isCheckmate = isCheckmate
        self.halfmoveClock = halfmoveClock
        self.isChase = isChase
        self.chaseAttackerId = chaseAttackerId
        self.chaseTargetId = chaseTargetId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        piece = try c.decode(Piece.self, forKey: .piece)
        from = try c.decode(Position.self, forKey: .from)
        to = try c.decode(Position.self, forKey: .to)
        captured = try c.decodeIfPresent(Piece.self, forKey: .captured)
        turnNumber = try c.decode(Int.self, forKey: .turnNumber)
        notation = try c.decode(String.self, forKey: .notation)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        isCheck = try c.decode(Bool.self, forKey: .isCheck)
        isCheckmate = try c.decode(Bool.self, forKey: .isCheckmate)
        halfmoveClock = try c.decodeIfPresent(Int.self, forKey: .halfmoveClock) ?? 0
        // v4.0 Phase 6: 长捉字段兼容旧存档（P0-1 修正：Int 类型）
        isChase = try c.decodeIfPresent(Bool.self, forKey: .isChase) ?? false
        chaseAttackerId = try c.decodeIfPresent(Int.self, forKey: .chaseAttackerId)
        chaseTargetId = try c.decodeIfPresent(Int.self, forKey: .chaseTargetId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(piece, forKey: .piece)
        try c.encode(from, forKey: .from)
        try c.encode(to, forKey: .to)
        try c.encodeIfPresent(captured, forKey: .captured)
        try c.encode(turnNumber, forKey: .turnNumber)
        try c.encode(notation, forKey: .notation)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(isCheck, forKey: .isCheck)
        try c.encode(isCheckmate, forKey: .isCheckmate)
        try c.encode(halfmoveClock, forKey: .halfmoveClock)
        // v4.0 Phase 6: 长捉字段编码
        try c.encode(isChase, forKey: .isChase)
        try c.encodeIfPresent(chaseAttackerId, forKey: .chaseAttackerId)
        try c.encodeIfPresent(chaseTargetId, forKey: .chaseTargetId)
    }
}

// MARK: - UCI 表示

extension GameMove {
    /// ICCS 坐标格式的 UCI 走法（如 "h2e2"）
    /// v3.7.2: 提取公共逻辑，消除 5 处重复代码
    var uciNotation: String {
        let fileChars = Array("abcdefghi")
        let fromFile = String(fileChars[from.col])
        let fromRank = String(9 - from.row)
        let toFile = String(fileChars[to.col])
        let toRank = String(9 - to.row)
        return fromFile + fromRank + toFile + toRank
    }
}

extension Array where Element == GameMove {
    /// 批量转换为 UCI 走法列表
    var uciMoves: [String] { map { $0.uciNotation } }
}
