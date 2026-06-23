#if os(macOS)

import Foundation

// MARK: - In-Process Mock UCI 引擎

/// 方案 E：纯 Swift actor，内存模拟 UCI 引擎行为
/// 用于测试，消除外部进程依赖，根治进程残留问题
///
/// 固定返回 bestmove h2e2（炮二平五，开局第一步）
actor MockUCIEngine: ChessEngine {

    // MARK: - ChessEngine 属性

    nonisolated let displayName: String = "MockUCIEngine"
    nonisolated let engineType: EngineType = .external
    private(set) var isReady = false

    // MARK: - 生命周期

    /// 模拟启动（短暂延迟后标记 ready）
    func start() async throws {
        // 模拟 UCI 握手延迟
        try await Task.sleep(for: .milliseconds(10))
        isReady = true
    }

    // MARK: - ChessEngine 接口

    /// 固定返回 h2e2（炮二平五）
    func bestMove(
        fen: String,
        moveHistory: [String],
        difficulty: AIDifficulty,
        timeLimitMs: Int
    ) async -> String? {
        guard isReady else { return nil }
        // 模拟思考延迟（可选）
        if timeLimitMs > 0 {
            try? await Task.sleep(for: .milliseconds(min(timeLimitMs, 100)))
        }
        return "h2e2"
    }

    func stopSearch() async {
        // Mock 不需要实现
    }

    func newGame() async {
        // Mock 不需要实现
    }

    func shutdown() async {
        isReady = false
    }
}

#endif