import Foundation

// MARK: - 置换表

/// 固定大小数组的置换表，用于 Alpha-Beta 搜索中避免重复计算。
/// 容量必须是 2 的幂，通过位运算实现 O(1) 查找。
final class TranspositionTable {

    // MARK: - 条目类型

    enum TTFlag: UInt8 {
        case exact = 0   // 精确值
        case lower = 1   // beta cutoff（下界）
        case upper = 2   // 上界
    }

    struct TTEntry {
        let hash: UInt64       // 完整哈希，校验碰撞
        let depth: Int
        let score: Int
        let flag: TTFlag
        let bestMove: Move?
        let isValid: Bool      // false = 空槽位
    }

    struct TTLookupResult {
        let score: Int
        let flag: TTFlag
        let bestMove: Move?
    }

    // MARK: - 属性

    private var table: [TTEntry?]
    private let capacity: Int
    private let mask: UInt64

    // MARK: - 初始化

    init(capacity: Int = 1 << 20) {
        precondition(capacity > 0 && (capacity & (capacity - 1)) == 0, "capacity must be power of 2")
        self.capacity = capacity
        self.mask = UInt64(capacity - 1)
        self.table = Array(repeating: nil, count: capacity)
    }

    // MARK: - 查找

    private func index(for hash: UInt64) -> Int {
        return Int(hash & mask)
    }

    /// 查找置换表。如果找到有效条目且深度足够，返回查找结果。
    /// 调用方根据 flag 和 alpha/beta 判断是否可直接使用。
    func lookup(hash: UInt64, depth: Int, alpha: Int, beta: Int) -> TTLookupResult? {
        let idx = index(for: hash)
        guard let entry = table[idx], entry.isValid, entry.hash == hash else { return nil }
        guard entry.depth >= depth else { return nil }

        switch entry.flag {
        case .exact:
            return TTLookupResult(score: entry.score, flag: .exact, bestMove: entry.bestMove)
        case .lower:
            // 下界：实际值 >= entry.score
            if entry.score >= beta {
                return TTLookupResult(score: entry.score, flag: .lower, bestMove: entry.bestMove)
            }
        case .upper:
            // 上界：实际值 <= entry.score
            if entry.score <= alpha {
                return TTLookupResult(score: entry.score, flag: .upper, bestMove: entry.bestMove)
            }
        }
        return nil  // 深度够但 flag 不满足截断条件，只可用于走法排序提示
    }

    /// 获取条目的最佳走法（即使深度不够或 flag 不匹配），用于走法排序
    func probeBestMove(hash: UInt64) -> Move? {
        let idx = index(for: hash)
        guard let entry = table[idx], entry.isValid, entry.hash == hash else { return nil }
        return entry.bestMove
    }

    // MARK: - 存储

    /// 存储条目。替换策略：深度优先（新条目深度 >= 旧条目深度时替换，或旧槽位为空）
    func store(hash: UInt64, depth: Int, score: Int, flag: TTFlag, bestMove: Move?) {
        let idx = index(for: hash)
        let existing = table[idx]

        if existing == nil || !existing!.isValid || depth >= existing!.depth {
            table[idx] = TTEntry(
                hash: hash, depth: depth, score: score,
                flag: flag, bestMove: bestMove, isValid: true
            )
        }
    }

    // MARK: - 清理

    func clear() {
        table = Array(repeating: nil, count: capacity)
    }
}
