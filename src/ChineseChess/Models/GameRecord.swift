import Foundation

// MARK: - 来源枚举

enum RecordSource: String, Codable {
    case versusAI     // 人机对弈
    case puzzle       // 残局练习
    case imported     // 导入
    case freePlay     // 自由对弈
}

// MARK: - 玩家信息

struct PlayerInfo: Codable, Equatable {
    let name: String           // "玩家" / "AI-高级" / "红方" / "黑方"
    let isAI: Bool
    let difficulty: AIDifficulty?  // v3.7.0: PGN 导入时可能缺少，允许 nil
}

// MARK: - 棋谱记录

struct GameRecord: Identifiable, Codable {
    let id: UUID
    var title: String          // "第 3 局" 或自定义标题
    let date: Date
    let redPlayer: PlayerInfo
    let blackPlayer: PlayerInfo
    let difficulty: AIDifficulty?  // v3.7.1 C5: 导入记录无难度信息
    let result: GameState      // redWon / blackWon / draw
    let totalMoves: Int
    let moves: [GameMove]      // 完整走法列表
    let initialFEN: String?    // 非标准开局时记录

    // v3.7.0 新增
    var source: RecordSource   // 来源：对弈/残局/导入/自由对弈
    var tags: [String]         // 用户标签（如"精彩"、"复盘"）
    var puzzleId: String?      // 残局模式关联的 puzzle ID

    // MARK: - Codable 向后兼容

    enum CodingKeys: String, CodingKey {
        case id, title, date, redPlayer, blackPlayer, difficulty
        case result, totalMoves, moves, initialFEN
        case source, tags, puzzleId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        redPlayer = try c.decode(PlayerInfo.self, forKey: .redPlayer)
        blackPlayer = try c.decode(PlayerInfo.self, forKey: .blackPlayer)
        difficulty = try c.decodeIfPresent(AIDifficulty.self, forKey: .difficulty)
        result = try c.decode(GameState.self, forKey: .result)
        totalMoves = try c.decode(Int.self, forKey: .totalMoves)
        moves = try c.decode([GameMove].self, forKey: .moves)
        initialFEN = try c.decodeIfPresent(String.self, forKey: .initialFEN)
        // v3.7.0 新增字段：decodeIfPresent + 默认值
        source = try c.decodeIfPresent(RecordSource.self, forKey: .source) ?? .versusAI
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        puzzleId = try c.decodeIfPresent(String.self, forKey: .puzzleId)
    }

    // MARK: - 便捷初始化器

    init(
        id: UUID = UUID(),
        title: String,
        date: Date = Date(),
        redPlayer: PlayerInfo,
        blackPlayer: PlayerInfo,
        difficulty: AIDifficulty? = nil,
        result: GameState,
        totalMoves: Int,
        moves: [GameMove],
        initialFEN: String? = nil,
        source: RecordSource = .versusAI,
        tags: [String] = [],
        puzzleId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.redPlayer = redPlayer
        self.blackPlayer = blackPlayer
        self.difficulty = difficulty
        self.result = result
        self.totalMoves = totalMoves
        self.moves = moves
        self.initialFEN = initialFEN
        self.source = source
        self.tags = tags
        self.puzzleId = puzzleId
    }
}
