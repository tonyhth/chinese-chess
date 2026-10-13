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

extension PlayerInfo {
    /// T-1013-OC-03 P1-2：边界迁移重建实例（difficulty 过 S2 映射，nil 透传；成员逐一 init 同模块可达）
    var s2DifficultyMigrated: PlayerInfo {
        PlayerInfo(name: name, isAI: isAI, difficulty: AIDifficulty.s2Migrated(difficulty))
    }
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

    /// T-1013-OC-03 P1-2（Luke 裁定选项 a）：S2 迁移标记——false/缺席=difficulty 键为 S2 前旧语义
    /// （加载边界单次迁移）；true=S2 后新语义（零腐蚀直读）。便捷 init 缺省 true=新记录生于新体系
    var s2Migrated: Bool

    // MARK: - Codable 向后兼容

    enum CodingKeys: String, CodingKey {
        case id, title, date, redPlayer, blackPlayer, difficulty
        case result, totalMoves, moves, initialFEN
        case source, tags, puzzleId
        case s2Migrated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        var redPlayerDecoded = try c.decode(PlayerInfo.self, forKey: .redPlayer)
        var blackPlayerDecoded = try c.decode(PlayerInfo.self, forKey: .blackPlayer)
        result = try c.decode(GameState.self, forKey: .result)
        totalMoves = try c.decode(Int.self, forKey: .totalMoves)
        moves = try c.decode([GameMove].self, forKey: .moves)
        initialFEN = try c.decodeIfPresent(String.self, forKey: .initialFEN)
        // v3.7.0 新增字段：decodeIfPresent + 默认值
        source = try c.decodeIfPresent(RecordSource.self, forKey: .source) ?? .versusAI
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        puzzleId = try c.decodeIfPresent(String.self, forKey: .puzzleId)

        // T-1013-OC-03 P1-2（Luke 裁定选项 a）：S2 迁移在用户数据边界单次应用——
        // s2Migrated 标记缺席（S2 前旧档）→ difficulty/双 PlayerInfo 经映射迁移；
        // 标记在位（S2 后新档）零腐蚀直读。难度以原始键解码（AIDifficulty Codable 保持纯解码），
        // 未知键保留 .amateurMid fallback 语义；标记缺席缺省 false（全部存量档皆需迁移）
        s2Migrated = try c.decodeIfPresent(Bool.self, forKey: .s2Migrated) ?? false
        let difficultyRaw = try c.decodeIfPresent(String.self, forKey: .difficulty)
        if let raw = difficultyRaw {
            let migrated = s2Migrated ? raw : AIDifficulty.s2MigratedRaw(raw)
            difficulty = AIDifficulty(rawValue: migrated) ?? .amateurMid
        } else {
            difficulty = nil
        }
        if !s2Migrated {
            redPlayerDecoded = redPlayerDecoded.s2DifficultyMigrated
            blackPlayerDecoded = blackPlayerDecoded.s2DifficultyMigrated
        }
        redPlayer = redPlayerDecoded
        blackPlayer = blackPlayerDecoded
        // P1-2 应用后标记：迁移已应用 → 内存态置 true（再编码写回=单次应用持久化，
        // 杜绝无写回时 lvl8→lvl4→lvl3 型二次迁移漂移；新档本就 true 不受影响）
        s2Migrated = true
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
        puzzleId: String? = nil,
        s2Migrated: Bool = true
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
        self.s2Migrated = s2Migrated
    }
}
