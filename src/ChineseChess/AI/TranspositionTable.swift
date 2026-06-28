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

    // v3.0 Phase 2b: 双桶策略（2 slots per index）
    // 桶 0: depth-prefer（优先保留高深度条目）
    // 桶 1: always-replace（总是替换，保持新鲜度）
    private var table: [TTEntry?]  // 双桶：index * 2 = slot 0, index * 2 + 1 = slot 1
    private let capacity: Int      // 桶数（每桶 2 slot）
    private let mask: UInt64

    // MARK: - 初始化

    #if os(iOS)
    init(capacity: Int = 1 << 18) {
        precondition(capacity > 0 && (capacity & (capacity - 1)) == 0, "capacity must be power of 2")
        self.capacity = capacity
        self.mask = UInt64(capacity - 1)
        self.table = Array(repeating: nil, count: capacity * 2)  // 双桶
    }
    #else
    init(capacity: Int = 1 << 20) {
        precondition(capacity > 0 && (capacity & (capacity - 1)) == 0, "capacity must be power of 2")
        self.capacity = capacity
        self.mask = UInt64(capacity - 1)
        self.table = Array(repeating: nil, count: capacity * 2)  // 双桶
    }
    #endif

    // MARK: - 查找

    /// 查找置换表。如果找到有效条目且深度足够，返回查找结果。
    /// 调用方根据 flag 和 alpha/beta 判断是否可直接使用。
    func lookup(hash: UInt64, depth: Int, alpha: Int, beta: Int) -> TTLookupResult? {
        let baseIdx = Int(hash & mask) * 2
        // 检查两个桶
        for slot in 0..<2 {
            let idx = baseIdx + slot
            guard let entry = table[idx], entry.isValid, entry.hash == hash else { continue }
            guard entry.depth >= depth else { continue }
            switch entry.flag {
            case .exact:
                return TTLookupResult(score: entry.score, flag: .exact, bestMove: entry.bestMove)
            case .lower:
                if entry.score >= beta {
                    return TTLookupResult(score: entry.score, flag: .lower, bestMove: entry.bestMove)
                }
            case .upper:
                if entry.score <= alpha {
                    return TTLookupResult(score: entry.score, flag: .upper, bestMove: entry.bestMove)
                }
            }
        }
        return nil
    }

    /// 获取条目的最佳走法（即使深度不够或 flag 不匹配），用于走法排序
    func probeBestMove(hash: UInt64) -> Move? {
        let baseIdx = Int(hash & mask) * 2
        for slot in 0..<2 {
            let idx = baseIdx + slot
            if let entry = table[idx], entry.isValid, entry.hash == hash {
                return entry.bestMove
            }
        }
        return nil
    }

    // MARK: - 存储

    /// v3.0 Phase 2b: 双桶存储策略
    /// slot 0 (depth-prefer): 新条目深度 >= 旧条目深度时替换
    /// slot 1 (always-replace): 总是替换
    func store(hash: UInt64, depth: Int, score: Int, flag: TTFlag, bestMove: Move?) {
        let baseIdx = Int(hash & mask) * 2

        // slot 0: depth-prefer
        if let existing = table[baseIdx] {
            if !existing.isValid || depth >= existing.depth {
                table[baseIdx] = TTEntry(hash: hash, depth: depth, score: score,
                                          flag: flag, bestMove: bestMove, isValid: true)
                return
            }
        } else {
            table[baseIdx] = TTEntry(hash: hash, depth: depth, score: score,
                                      flag: flag, bestMove: bestMove, isValid: true)
            return
        }

        // slot 1: always-replace
        table[baseIdx + 1] = TTEntry(hash: hash, depth: depth, score: score,
                                      flag: flag, bestMove: bestMove, isValid: true)
    }

    // MARK: - 清理

    func clear() {
        table = Array(repeating: nil, count: capacity * 2)
    }
}
