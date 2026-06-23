import Foundation

#if os(macOS)

/// 纯 Swift Mock UCI 引擎（替代 mock-uci-engine.sh 外部进程）
/// 用于 Phase2bUCITests 集成测试，避免进程残留问题
final class MockUCIEngine: Sendable {
    // 固定走法（炮二平五）
    static let bestMove = "h2e2"
    
    // 引擎信息
    let name = "MockUCIEngine 1.0"
    let author = "TestSuite"
    
    /// 处理单个 UCI 命令，返回响应
    func handleCommand(_ line: String) -> [String] {
        let cmd = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch cmd {
        case "uci":
            return [
                "id name \(name)",
                "id author \(author)",
                "option name Hash type spin default 128 min 1 max 1024",
                "option name Threads type spin default 1 min 1 max 64",
                "uciok"
            ]
        case "isready":
            return ["readyok"]
        case "ucinewgame":
            return [] // 静默确认
        case let pos where pos.hasPrefix("position"):
            return [] // 接受 position 命令
        case let go where go.hasPrefix("go"):
            // 模拟搜索输出 + bestmove
            return [
                "info depth 1 nodes 20 score cp 50 time 1 pv \(Self.bestMove)",
                "info depth 2 nodes 45 score cp 60 time 2 pv \(Self.bestMove)",
                "info depth 3 nodes 120 score cp 70 time 3 pv \(Self.bestMove)",
                "bestmove \(Self.bestMove)"
            ]
        case "stop":
            return [] // 已在 go 中立即返回
        case "quit":
            return [] // 退出信号
        default:
            return [] // 忽略未知命令
        }
    }
}

/// Process-based Mock UCI Engine for ExternalEngineManager testing
/// 内嵌 Swift 逻辑，不依赖外部 bash 脚本
actor ProcessMockEngine {
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private let mockLogic = MockUCIEngine()
    
    /// 启动 mock 引擎（内嵌 Swift 逻辑）
    func start() async throws {
        // 不启动外部进程，直接用 actor 内的状态机
        // ExternalEngineManager 期望的是 Process 模式，
        // 但这里我们用 actor 模式模拟相同行为
    }
    
    /// 发送命令并获取响应
    func sendCommand(_ cmd: String) async -> [String] {
        return mockLogic.handleCommand(cmd)
    }
}

#endif