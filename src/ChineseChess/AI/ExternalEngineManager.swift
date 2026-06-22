#if os(macOS)

import Foundation

// MARK: - 外部 UCI 引擎管理器

/// 外部 UCI 引擎管理器（actor，线程安全）
/// 负责：进程生命周期、UCI 协议通信、搜索控制
///
/// 通信流程：
/// 1. `start()` 启动引擎进程，绑定管道
/// 2. UCI 握手：发送 `uci` → 等待 `uciok` → 设置选项 → 发送 `isready` → 等待 `readyok`
/// 3. `bestMove()` 发送 `position` + `go`，等待 `bestmove` 返回
/// 4. `shutdown()` 发送 `quit`，终止进程
actor ExternalEngineManager: ChessEngine {

    // MARK: - ChessEngine 属性

    nonisolated var displayName: String { config.name }
    nonisolated var engineType: EngineType { .external }
    private(set) var isReady = false

    // MARK: - 进程管理

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?

    // MARK: - UCI 通信

    private let transceiver = UCITransceiver()

    // MARK: - 配置

    private let config: ExternalEngineConfig

    init(config: ExternalEngineConfig) {
        self.config = config
    }

    // MARK: - 生命周期

    /// 启动引擎进程并发送 UCI 握手
    /// - Throws: 进程启动失败、UCI 握手超时
    func start() async throws {
        guard process == nil else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.executablePath)
        if let args = config.arguments, !args.isEmpty {
            proc.arguments = args
        }

        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout

        // 设置进程终止回调
        let termRef = self
        proc.terminationHandler = { _ in
            Task { await termRef.handleTermination() }
        }

        try proc.run()

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout

        // 启动 transceiver 接管 stdout
        try await transceiver.attach(outputPipe: stdout)

        // UCI 握手
        try await uciHandshake()
    }

    /// UCI 握手：发送 uci → 等 uciok → 设置选项 → 发送 isready → 等 readyok
    private func uciHandshake() async throws {
        try sendCommand("uci")
        try await transceiver.waitForToken("uciok", timeoutMs: 10_000)

        // 设置引擎选项（P0 修复：过滤换行符，防止 UCI 命令注入）
        for option in config.options {
            let safeName = option.name.filter { $0 != "\n" && $0 != "\r" }
            let safeValue = option.value.filter { $0 != "\n" && $0 != "\r" }
            try sendCommand("setoption name \(safeName) value \(safeValue)")
        }

        try sendCommand("isready")
        try await transceiver.waitForToken("readyok", timeoutMs: 10_000)

        isReady = true
    }

    // MARK: - ChessEngine 接口

    func bestMove(
        fen: String,
        moveHistory: [String],
        difficulty: AIDifficulty,
        timeLimitMs: Int
    ) async -> String? {
        guard isReady else { return nil }

        // 构建 position 命令（P1 修复：写入失败直接返回，不等 30s 超时）
        let movesStr = moveHistory.isEmpty ? "" : " moves " + moveHistory.joined(separator: " ")
        do {
            try sendCommand("position fen \(fen)\(movesStr)")
        } catch {
            return nil  // 管道断裂——引擎已退出
        }

        // 构建 go 命令
        let goCmd = buildGoCommand(difficulty: difficulty, timeLimitMs: timeLimitMs)
        do {
            try sendCommand(goCmd)
        } catch {
            return nil  // 管道断裂——引擎已退出
        }

        // 等待 bestmove（超时至少 30s）
        let timeout = max(timeLimitMs + 5_000, 30_000)
        return await transceiver.waitForBestMove(timeoutMs: timeout)
    }

    func stopSearch() async {
        try? sendCommand("stop")
    }

    func newGame() async {
        try? sendCommand("ucinewgame")
    }

    func shutdown() async {
        try? sendCommand("quit")
        process?.terminate()
        process = nil
        isReady = false
        await transceiver.detach()
    }

    // MARK: - 引擎信息回调

    func setInfoCallback(_ callback: @escaping @Sendable (UCIInfo) -> Void) async {
        await transceiver.setInfoCallback(callback)
    }

    // MARK: - 私有方法

    /// 发送命令到引擎 stdin
    /// - Throws: 管道写入错误。写入失败时标记引擎不可用
    private func sendCommand(_ cmd: String) throws {
        guard let pipe = stdinPipe else { return }
        let data = (cmd + "\n").data(using: .utf8)!
        do {
            try pipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            // 管道断裂——引擎可能已退出
            isReady = false
            throw error
        }
    }

    /// 根据难度和时间限制构建 go 命令
    /// depth 映射参考设计文档 §6.3（Pikafish 等 NNUE 引擎即使 depth 2 也远超人类业余水平）
    private func buildGoCommand(difficulty: AIDifficulty, timeLimitMs: Int) -> String {
        if timeLimitMs > 0 {
            return "go movetime \(timeLimitMs)"
        }
        switch difficulty {
        case .beginner:  // depth 2：即使是 NNUE 引擎也明显降弱
            return "go depth 2"
        case .easy:      // depth 5：基础水平
            return "go depth 5"
        case .medium:    // depth 10：中等水平
            return "go depth 10"
        case .hard:      // depth 18：较高水平
            return "go depth 18"
        case .master:    // depth 24：接近引擎全力
            return "go depth 24"
        }
    }

    /// 进程意外终止处理（P2 修复：清理 pipe 引用）
    private func handleTermination() {
        isReady = false
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
    }
}

#endif
