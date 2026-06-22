import Foundation

// MARK: - 统一引擎协议

/// 统一引擎接口——自研引擎和外部引擎都实现此协议
/// v3.1 Phase 2a: 双引擎适配层核心
protocol ChessEngine: AnyObject {
    /// 引擎显示名称
    var displayName: String { get }

    /// 引擎类型
    var engineType: EngineType { get }

    /// 引擎是否就绪（外部引擎需完成 UCI 握手）
    /// async 因为 actor-isolated 属性需要 await
    var isReady: Bool { get async }

    /// 计算最佳走法
    /// - Parameters:
    ///   - fen: 当前局面的 FEN 字符串
    ///   - moveHistory: UCI 格式的走法历史（如 ["e6e5", "h2e2"]）
    ///   - difficulty: 难度（用于自研引擎路由和外部引擎参数映射）
    ///   - timeLimitMs: 时间限制（毫秒），0 表示不限
    /// - Returns: UCI 格式的最佳走法（如 "h2e2"），nil 表示无合法走法
    func bestMove(
        fen: String,
        moveHistory: [String],
        difficulty: AIDifficulty,
        timeLimitMs: Int
    ) async -> String?

    /// 中止当前搜索（外部引擎发 `stop` 命令）
    func stopSearch() async

    /// 通知引擎开始新对局（外部引擎发 `ucinewgame`，自研引擎清空 TT）
    func newGame() async

    /// 释放资源（外部引擎发 `quit` 命令并终止进程）
    func shutdown() async
}

/// 引擎类型
enum EngineType: String, Codable {
    case native   // 自研引擎
    case external // 外部 UCI 引擎
}
