import Foundation

// MARK: - 时间管理

/// 管理 AI 思考时间，在迭代加深的每一层开始前检查是否超时。
struct TimeManager {

    let timeLimitMs: Int     // 总时间限制（毫秒）
    let startTime: Date      // 搜索开始时间

    /// 上一层搜索的单层耗时（毫秒），用于迭代加深时间分配
    var lastIterationMs: Int = 0
    /// 上一层搜索结束时的累积时间（毫秒），用于计算 delta
    private var lastIterationEndMs: Int = 0

    /// 显式公开初始化器（避免 private 字段导致 memberwise init 不可访问）
    init(timeLimitMs: Int, startTime: Date) {
        self.timeLimitMs = timeLimitMs
        self.startTime = startTime
    }

    /// 已用时间（毫秒）
    var elapsedMs: Int {
        Int(Date().timeIntervalSince(startTime) * 1000)
    }

    /// 是否应该停止搜索
    var shouldStop: Bool {
        elapsedMs >= timeLimitMs
    }

    /// 剩余时间（毫秒）
    var remainingMs: Int {
        max(0, timeLimitMs - elapsedMs)
    }

    /// 是否应该开始下一层搜索
    /// 启发式：如果剩余时间 < 上一层单层耗时 * 2.5，则不再开始新层
    var shouldStartNextIteration: Bool {
        let remaining = remainingMs
        // 第一层（没有历史数据）总是执行
        if lastIterationMs == 0 { return true }
        // 估计下一层耗时 = 上一层单层耗时 * 2.5
        let estimatedNextMs = Int(Double(lastIterationMs) * 2.5)
        return remaining > estimatedNextMs
    }

    /// 记录一层搜索完成（记录单层 delta，非累积时间）
    mutating func recordIterationComplete() {
        let currentMs = elapsedMs
        lastIterationMs = currentMs - lastIterationEndMs  // 单层耗时 = 当前累积 - 上层累积
        lastIterationEndMs = currentMs
    }

    /// 局面复杂度评分（0-100）
    /// 评分规则：阶梯式加权（子力/吃子/将军/活跃子力），每项独立贡献
    /// 调用频率：每次 bestMove 调用一次，不在搜索内部调用
    static func positionComplexity<T: BoardReadable>(board: T) -> Int {
        var complexity = 0

        let totalPieces = board.pieces.count

        // 因子 1：子力数量（阶梯式，中局最复杂）
        if totalPieces > 16 {
            complexity += 30
        } else if totalPieces > 10 {
            complexity += 40  // 中局最复杂
        } else {
            complexity += 15  // 残局相对简单
        }

        // 因子 2：吃子走法数量（线性，上限 25）
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        let captureCount = moves.filter { $0.captured != nil }.count
        complexity += min(captureCount * 5, 25)

        // 因子 3：将军状态（被将时值得多想）
        if MoveValidator.isInCheck(side, on: board) {
            complexity += 20
        }

        // 因子 4：双方车/马/炮活跃度（线性，上限 15）
        let activePieces = board.pieces.filter {
            $0.kind == .chariot || $0.kind == .cannon || $0.kind == .horse
        }.count
        complexity += min(activePieces * 3, 15)

        return min(complexity, 100)
    }

    /// 根据难度创建 TimeManager
    /// 1-2 级无时间限制，返回 nil
    /// 3-5 级自研引擎时间分配
    /// 6-10 级专业级返回 nil（时间由 Pikafish 内部管理）
    /// isIOS: iOS 降时避免主线程阻塞被系统 kill
    /// board: 可选，传入时根据局面复杂度动态调整时间
    static func forDifficulty<T: BoardReadable>(_ difficulty: AIDifficulty, isIOS: Bool = false,
                              board: T? = nil) -> TimeManager? {
        let baseTimeMs: Int
        switch difficulty {
        case .novice, .beginner:
            return nil
        case .amateurLow:
            baseTimeMs = isIOS ? 2000 : 3000
        case .amateurMid:
            baseTimeMs = isIOS ? 3000 : 5000
        case .amateurHigh:
            baseTimeMs = isIOS ? 5000 : 10000
        case .amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster:
            // v6.0: 专业级时间由 Pikafish 内部管理
            return nil
        }

        // 根据局面复杂度调整时间（仅当传入 board 时）
        if let board = board {
            let complexity = positionComplexity(board: board)
            // 线性映射：复杂度 0 → factor 0.6，复杂度 100 → factor 1.4
            let factor = 0.6 + Double(complexity) / 100.0 * 0.8
            let adjustedTime = Int(Double(baseTimeMs) * factor)
            return TimeManager(timeLimitMs: adjustedTime, startTime: Date())
        }

        return TimeManager(timeLimitMs: baseTimeMs, startTime: Date())
    }
}
