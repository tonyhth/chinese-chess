import Foundation

// MARK: - Zobrist 哈希

/// 为棋盘位置生成确定性哈希值，用于置换表查找和开局库匹配。
/// 14 种棋子（7 PieceKind × 2 Side）× 90 个位置（10 行 × 9 列）的预计算随机数表。
struct ZobristHash {

    /// 14 × 90 随机数表：table[pieceIndex][positionIndex]
    /// pieceIndex: 0-6 红方(将仕象马车炮兵), 7-13 黑方
    /// positionIndex: row * 9 + col (0-89)
    static let table: [[UInt64]] = {
        // 使用固定种子的伪随机数，确保每次运行哈希一致
        var rng = SplitMix64(seed: 0x12345678_9ABCDEF0)
        var t: [[UInt64]] = []
        for _ in 0..<14 {
            var row: [UInt64] = []
            for _ in 0..<90 {
                row.append(rng.next())
            }
            t.append(row)
        }
        return t
    }()

    /// 行走方切换的异或值
    static let sideHash: UInt64 = {
        var rng = SplitMix64(seed: 0xFEDCBA98_76543210)
        return rng.next()
    }()

    // MARK: - 完整哈希计算

    /// 计算棋盘的完整 Zobrist 哈希
    static func hash(board: Board) -> UInt64 {
        var h: UInt64 = 0
        for piece in board.pieces {
            let pi = pieceIndex(piece)
            let posi = piece.position.row * 9 + piece.position.col
            h ^= table[pi][posi]
        }
        if board.currentTurn == .black {
            h ^= sideHash
        }
        return h
    }

    // MARK: - 增量更新

    /// 走棋后增量更新哈希（无需重算整个棋盘）
    ///
    /// 注意：当前接口不支持棋子升变（兵变车等）。如果未来加入升变机制，
    /// 需要改为用旧棋子类型 XOR 出 + 新棋子类型 XOR 入，而非直接移动。
    /// 象棋标准规则无升变，当前接口满足需求。
    static func update(hash: UInt64, piece: Piece, from: Position, to: Position, captured: Piece?) -> UInt64 {
        var h = hash
        let pi = pieceIndex(piece)

        // 移除旧位置
        h ^= table[pi][from.row * 9 + from.col]
        // 添加新位置
        h ^= table[pi][to.row * 9 + to.col]

        // 移除被吃棋子
        if let captured = captured {
            let ci = pieceIndex(captured)
            h ^= table[ci][to.row * 9 + to.col]
        }

        // 切换行走方
        h ^= sideHash
        return h
    }

    // MARK: - 棋子索引

    /// 将棋子映射到 0-13 的索引
    static func pieceIndex(_ piece: Piece) -> Int {
        let kindBase: [PieceKind: Int] = [
            .general: 0, .advisor: 1, .elephant: 2,
            .horse: 3, .chariot: 4, .cannon: 5, .soldier: 6
        ]
        let base = kindBase[piece.kind] ?? 0
        return piece.side == .red ? base : base + 7
    }
}

// MARK: - SplitMix64 伪随机数生成器

/// 固定种子的 PRNG，用于生成 Zobrist 表。保证跨平台、跨运行一致性。
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        var z = state &+ 0x9E3779B97F4A7C15
        state = z
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
