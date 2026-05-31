import Foundation

// MARK: - 时间管理

/// 管理 AI 思考时间，在迭代加深的每一层开始前检查是否超时。
struct TimeManager {

    let timeLimitMs: Int     // 总时间限制（毫秒）
    let startTime: Date      // 搜索开始时间

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

    /// 根据难度创建 TimeManager
    /// beginner/easy/medium 无时间限制，返回 nil
    static func forDifficulty(_ difficulty: AIDifficulty) -> TimeManager? {
        switch difficulty {
        case .beginner, .easy, .medium:
            return nil
        case .hard:
            return TimeManager(timeLimitMs: 3000, startTime: Date())
        case .master:
            return TimeManager(timeLimitMs: 5000, startTime: Date())
        }
    }
}
