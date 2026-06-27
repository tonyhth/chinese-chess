# v3.1 Phase 2 设计：macOS UCI 外部引擎支持

> 版本：v1.2（Vera 复审 P1-A/B/C 修复）
> 日期：2026-07-10
> 作者：Alex（架构师）
> 状态：v1.2（P1-A/B/C 修复完成，待 Luke 定稿）

---

## 一、背景与目标

### 1.1 现状

v3.0 Phase 10 设计了 Pikafish 集成方案（C 静态库直接桥接），但该方案存在约束：

- **iOS 不支持 `Process` API**，只能走 C 库编译路线
- **GPLv3 合规性**尚未完全解决
- **App 体积增量**（~50MB）需评估

### 1.2 Phase 2 的定位

Phase 2 是 **macOS 专属**的外部 UCI 引擎支持。它走的是完全不同的技术路线：

| 维度 | Phase 10（Pikafish C 库） | Phase 2（UCI 外部进程） |
|------|--------------------------|------------------------|
| 平台 | iOS + macOS | **仅 macOS** |
| 引擎分发 | 打包进 App Bundle | **不内置**，用户自行下载 |
| 通信方式 | C 函数直接调用 | Process + 管道（stdin/stdout） |
| 协议 | 自定义 C API | **UCI/UCCI 标准协议** |
| 引擎锁定 | 锁定 Pikafish | **任意 UCI 引擎**（Pikafish、Fairy-Stockfish 等） |
| 合规风险 | GPLv3 静态链接 | 无（独立进程，协议通信） |

### 1.3 设计目标

1. **用户可自行配置外部 UCI 引擎**（如 Pikafish、Fairy-Stockfish-MultiVariant）
2. **自研引擎与外部引擎共存**，通过统一接口切换
3. **设置界面允许选择引擎**，配置可执行文件路径
4. **零合规风险**：不内置、不链接，纯协议通信

### 1.4 非目标（Out of Scope）

- ❌ iOS 外部引擎支持（iOS 沙箱不允许 `Process`）
- ❌ 内置/打包任何外部引擎可执行文件
- ❌ 在线引擎对战（未来功能）
- ❌ 引擎分析/复盘功能（Phase 9 范畴）

---

## 二、技术选型

### 2.1 UCI/UCCI 协议

**选型：UCI（Universal Chess Interface）**

理由：
- 中国象棋引擎事实标准（Pikafish、Fairy-Stockfish 等均支持 UCI）
- UCCI 是 UCI 的中国象棋扩展，大多数引擎兼容 UCI 指令子集
- 协议简单、文本行、易解析
- 与 xiangqi.com、象棋巫师等平台一致

### 2.2 通信机制

**选型：`Foundation.Process` + 管道（stdin/stdout）**

理由：
- macOS 原生支持，无需第三方依赖
- UCI 协议基于文本行，天然适合管道通信
- 进程隔离——引擎崩溃不影响主程序
- 零合规风险——不链接引擎代码

### 2.3 异步模型

**选型：Actor + 行缓冲队列**

> **v1.1 修订（P0-3）**：原方案用 `AsyncStream` 单消费者模型，多次 `waitForToken` 调用间会丢数据。改为 actor 持续消费 + 队列分发模型。

理由：
- `Actor` 保证对引擎进程的线程安全访问
- 行缓冲队列确保多次等待调用间不丢数据
- `async/await` 与现有代码风格一致

---

## 三、架构设计

### 3.1 整体架构

```
┌──────────────────────────────────────────────────────────┐
│                      GameViewModel                        │
│                                                          │
│                    engine: ChessEngine                   │
│                        ↓                                 │
│              ┌─────────────────────┐                     │
│              │   ChessEngine       │                     │
│              │   (统一协议)         │                     │
│              └──────┬──────┬───────┘                     │
│                     │      │                             │
│          ┌──────────┘      └───────────┐                 │
│          ↓                            ↓                  │
│  ┌───────────────┐          ┌──────────────────────┐    │
│  │  AIEngine     │          │ ExternalEngineManager │    │
│  │  (自研引擎)    │          │  (macOS only, actor)  │    │
│  │               │          │                       │    │
│  │ depth 1-10    │          │ Process + 管道         │    │
│  │ 手写评估       │          │ UCI 协议               │    │
│  └───────────────┘          └──────────────────────┘    │
│                                     │                    │
│                           ┌─────────┴──────────┐        │
│                           │   pikafish (用户)   │        │
│                           │   fairy-stockfish  │        │
│                           │   其他 UCI 引擎     │        │
│                           └────────────────────┘        │
└──────────────────────────────────────────────────────────┘
```

### 3.2 分层职责

| 层级 | 组件 | 职责 |
|------|------|------|
| **路由层** | `EngineRouter` | 根据用户设置选择引擎，转发请求 |
| **协议层** | `ChessEngine` | 统一接口定义 |
| **适配层** | `AIEngine`（已有） | 自研引擎，实现 `ChessEngine` |
| **适配层** | `ExternalEngineManager` | 外部引擎管理，实现 `ChessEngine` |
| **通信层** | `UCITransceiver` | UCI 协议封装、命令收发、输出解析 |
| **基础设施** | `Process` + 管道 | 进程管理 |

---

## 四、模块详细设计

### 4.1 ChessEngine — 统一引擎协议

**文件**：`ChineseChess/AI/EngineProtocol.swift`（新增）

这是双引擎适配层的核心。现有的 `AIEngineProtocol` 方法签名绑定了 `Board` 类型，外部引擎不认识 `Board`，需要一个更高层的抽象。

```swift
/// 统一引擎接口——自研引擎和外部引擎都实现此协议
protocol ChessEngine: AnyObject {
    /// 引擎显示名称
    var displayName: String { get }

    /// 引擎类型
    var engineType: EngineType { get }

    /// 引擎是否就绪（外部引擎需完成加载和 isready 握手）
    /// - Note: async 因为 actor-isolated 属性需要 await（v1.2 P1-C 修复）
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
    func stopSearch()

    /// 通知引擎开始新对局（外部引擎发 `ucinewgame`，自研引擎清空 TT）
    func newGame()

    /// 释放资源（外部引擎发 `quit` 命令并终止进程）
    func shutdown()
}

/// 引擎类型
enum EngineType: String, Codable {
    case native   // 自研引擎
    case external // 外部 UCI 引擎
}
```

**设计要点**：

1. **输入用 FEN + UCI moves**，而非 `Board` 对象——FEN 是通用语言
2. **输出用 UCI move string**——调用方负责转换回 `Move`
3. `ChessEngine` 与现有 `AIEngineProtocol` 并存，`AIEngine` 实现两个协议
4. `difficulty` 参数保留——自研引擎路由搜索深度，外部引擎映射 UCI 参数
5. **v1.1 新增 `newGame()`**：对应 UCI `ucinewgame`，清空引擎置换表

### 4.2 AIEngine 适配 — 让自研引擎实现 ChessEngine

**文件**：`ChineseChess/AI/AIEngine.swift`（修改）

```swift
extension AIEngine: ChessEngine {
    var displayName: String { "内置引擎" }
    var engineType: EngineType { .native }
    var isReady: Bool { true }  // 同步返回，满足 async get（编译器自动包装）

    func bestMove(
        fen: String,
        moveHistory: [String],
        difficulty: AIDifficulty,
        timeLimitMs: Int
    ) async -> String? {
        // 1. FEN + moves → Board（复用现有 FENParser）
        guard let board = UCIMoveConverter.board(from: fen, moves: moveHistory) else {
            return nil
        }
        // 2. 调用现有 bestMove（零改动）
        let move = self.bestMove(for: board, difficulty: difficulty, isIOS: Self._isIOS)
        // 3. Move → UCI string
        return move.map { UCIMoveConverter.uciString(from: $0) }
    }

    func stopSearch() {
        // 自研引擎不支持中止，时间管理由 TimeManager 内部处理
    }

    func newGame() {
        // 自研引擎：清空历史启发表
        clearHistory()
    }

    func shutdown() {
        // 自研引擎无需 shutdown
    }
}
```

**影响**：`AIEngine` 原有 `AIEngineProtocol` 和 `bestMove(for:difficulty:isIOS:)` 完全不动，适配逻辑全在 extension。零侵入。

### 4.3 UCIMoveConverter — UCI 走法转换工具

**文件**：`ChineseChess/AI/UCIMoveConverter.swift`（新增）

> **v1.1 修订（P0-1）**：Board ↔ FEN 转换已由现有 `ChineseChess/Services/FENParser.swift` 实现（`parse(fen:)` + `generate(board:)`）。本模块**不重复 FEN 转换**，只负责 UCI 走法字符串与内部类型的互转。

```swift
/// UCI 走法转换工具
///
/// UCI 走法格式：4 字符，如 "h2e2" = 从 col=7,row=2 到 col=4,row=2
///
/// 列映射：a-i → col 0-8
/// 行映射：'0'-'9' → row 0-9（0 = 黑方底线，9 = 红方底线）
///
/// FEN 生成/解析请使用现有 `FENParser.generate(board:)` / `FENParser.parse(fen:)`。
enum UCIMoveConverter {
    /// Move → UCI 走法字符串（如 "h2e2"）
    static func uciString(from move: Move) -> String {
        return "\(colToChar(move.from.col))\(move.from.row)\(colToChar(move.to.col))\(move.to.row)"
    }

    /// UCI 走法字符串 → (from, to) 坐标对
    static func positions(from uci: String) -> (Position, Position)? {
        guard uci.count == 4 else { return nil }
        let chars = Array(uci)
        guard let fromCol = charToCol(chars[0]),
              let toCol = charToCol(chars[2]),
              let fromRow = chars[1].wholeNumberValue,
              let toRow = chars[3].wholeNumberValue,
              fromRow >= 0, fromRow <= 9,
              toRow >= 0, toRow <= 9 else { return nil }
        return (Position(row: fromRow, col: fromCol), Position(row: toRow, col: toCol))
    }

    /// UCI 走法字符串 → 完整 Move 对象（在 board 上查找棋子和被吃棋子）
    /// - v1.1 新增（P1-9）：解决 bestMove 返回后需要完整 Move 的问题
    static func move(from uci: String, on board: Board) -> Move? {
        guard let (from, to) = positions(from: uci) else { return nil }
        guard let piece = board.piece(at: from) else { return nil }
        let captured = board.piece(at: to)
        return Move(piece: piece, from: from, to: to, captured: captured)
    }

    /// FEN + UCI moves → Board（解析 FEN 后依次执行走法）
    static func board(from fen: String, moves: [String] = []) -> Board? {
        guard let board = FENParser.parse(fen: fen) else { return nil }
        for uci in moves {
            guard let move = self.move(from: uci, on: board) else { return nil }
            board.execute(move)
        }
        return board
    }

    // MARK: - 私有

    private static func colToChar(_ col: Int) -> Character {
        let a = Int(("a" as Character).asciiValue!)
        return Character(UnicodeScalar(a + col)!)
    }

    private static func charToCol(_ char: Character) -> Int? {
        guard let ascii = char.asciiValue, ascii >= 0x61, ascii <= 0x69 else { return nil }
        return Int(ascii) - 0x61
    }
}
```

**UCI 坐标映射规则**：

| 内部坐标 | UCI 字符 |
|---------|---------|
| col 0 | 'a' |
| col 8 | 'i' |
| row 0 | '0'（黑方底线） |
| row 9 | '9'（红方底线） |

例如：`Position(row: 0, col: 7)` → `"h0"`，`Position(row: 9, col: 0)` → `"a9"`

> **FEN 棋子字符映射**已由 `FENParser` 实现（`fenCharToPiece` / `pieceToFENChar`），参考 `FENParser.swift`。

### 4.4 ExternalEngineManager — 外部引擎管理器

**文件**：`ChineseChess/AI/ExternalEngineManager.swift`（新增）

> **v1.1 修订（P1-6）**：改为 `actor`，保证 `isReady`、`process` 等可变状态的线程安全。
> **v1.1 修订（P1-8）**：新增 `newGame()` 方法发送 `ucinewgame`。
> **v1.1 修订（P1-10）**：`sendCommand` 不再静默吞错，写入失败时设 `isReady = false`。

```swift
#if os(macOS)

import Foundation

/// 外部 UCI 引擎管理器（actor，线程安全）
/// 负责：进程生命周期、UCI 协议通信、搜索控制
actor ExternalEngineManager: ChessEngine {
    // MARK: - ChessEngine 属性

    nonisolated var displayName: String { config.name }
    nonisolated var engineType: EngineType { .external }
    private(set) var isReady = false  // actor-isolated，通过 async get 访问

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

    /// 启动引擎进程并发送 `uci` 握手
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

        // 启动 transceiver 接管 stdout（内部持续消费管道输出到行缓冲队列）
        try await transceiver.attach(outputPipe: stdout)

        // UCI 握手
        try await uciHandshake()
    }

    /// UCI 握手：发送 `uci`，等待 `uciok`，设置选项，发送 `isready`，等待 `readyok`
    private func uciHandshake() async throws {
        try sendCommand("uci")
        try await transceiver.waitForToken("uciok", timeoutMs: 10_000)

        // 设置引擎选项
        for option in config.options {
            try sendCommand("setoption name \(option.name) value \(option.value)")
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

        // 构建 position 命令
        let movesStr = moveHistory.isEmpty ? "" : " moves " + moveHistory.joined(separator: " ")
        try? sendCommand("position fen \(fen)\(movesStr)")

        // 构建 go 命令
        let goCmd = buildGoCommand(difficulty: difficulty, timeLimitMs: timeLimitMs)
        try? sendCommand(goCmd)

        // 等待 bestmove
        return await transceiver.waitForBestMove(timeoutMs: max(timeLimitMs + 5_000, 30_000))
    }

    func stopSearch() {
        try? sendCommand("stop")
    }

    func newGame() {
        try? sendCommand("ucinewgame")
    }

    func shutdown() {
        try? sendCommand("quit")
        process?.terminate()
        process = nil
        isReady = false
        transceiver.detach()
    }

    // MARK: - 私有方法

    /// 发送命令到引擎 stdin。
    /// - Throws: 管道写入错误。写入失败时标记引擎不可用（P1-10 修复）。
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

    private func buildGoCommand(difficulty: AIDifficulty, timeLimitMs: Int) -> String {
        if timeLimitMs > 0 {
            return "go movetime \(timeLimitMs)"
        }
        switch difficulty {
        case .beginner, .easy:
            return "go depth 3"
        case .medium:
            return "go depth 8"
        case .hard:
            return "go depth 15"
        case .master:
            return "go depth 22"
        }
    }

    private func handleTermination() {
        isReady = false
        process = nil
    }

    // MARK: - 引擎信息回调

    func setInfoCallback(_ callback: @escaping @Sendable (UCIInfo) -> Void) {
        await transceiver.setInfoCallback(callback)
    }
}

#endif
```

### 4.5 UCITransceiver — UCI 协议收发器

**文件**：`ChineseChess/AI/UCITransceiver.swift`（新增）

> **v1.1 重大修订（P0-2 + P0-3）**：
> - 旧方案 `readToEnd()` 会阻塞到管道关闭，对长运行引擎不可用 → 改用 `availableData` 增量读取
> - 旧方案 `AsyncStream` 单消费者模型，多次 `waitForToken` 间丢数据 → 改为 **actor + 行缓冲队列 + 等待者列表**

```swift
#if os(macOS)

import Foundation

/// UCI 协议收发器（actor，线程安全）
///
/// 通信模型：
/// 1. `attach()` 启动后台 Task，用 `readabilityHandler` + `availableData` 增量读取管道数据
/// 2. 按行分割后入 `lineQueue`（info 行直接回调，不入队）
/// 3. `waitForToken()` / `waitForBestMove()` 先检查队列已有行，不匹配则挂起为 `LineWaiter`
/// 4. 每次新行入队后调用 `checkWaiters()`，匹配则唤醒对应等待者
actor UCITransceiver {
    /// info 回调
    private var _onInfo: (@Sendable (UCIInfo) -> Void)?

    /// 行缓冲队列——后台 Task 持续入队
    private var lineQueue: [String] = []
    /// 等待者列表——每个等待者带 token 条件和续体
    private var waiters: [LineWaiter] = []
    /// 后台读取 Task
    private var readerTask: Task<Void, Never>?
    /// 输出管道引用
    private var outputPipe: Pipe?

    // MARK: - 连接管道

    func attach(outputPipe: Pipe) async throws {
        self.outputPipe = outputPipe
        readerTask = Task {
            await self.continuousRead(outputPipe: outputPipe)
        }
    }

    /// 断开管道连接
    func detach() {
        readerTask?.cancel()
        readerTask = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
    }

    // MARK: - 持续读取（P0-2 修复：用 availableData 而非 readToEnd）

    private func continuousRead(outputPipe: Pipe) async {
        var buffer = ""

        // 用 AsyncStream 包装 readabilityHandler 回调
        let dataStream = AsyncStream<Data> { continuation in
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    // EOF — 管道关闭
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
        }

        for await data in dataStream {
            guard let text = String(data: data, encoding: .utf8) else { continue }
            buffer += text

            // 按行分割（保留不完整行在 buffer 中）
            while let newlineIdx = buffer.firstIndex(of: "\n") {
                let line = String(buffer[buffer.startIndex..<newlineIdx])
                    .trimmingCharacters(in: .whitespaces)
                buffer.removeSubrange(buffer.startIndex...newlineIdx)

                if line.isEmpty { continue }

                // info 行：直接回调，不入等待队列
                if line.hasPrefix("info") {
                    let info = UCIInfo.parse(line: line)
                    _onInfo?(info)
                    continue
                }

                // 入队 + 检查是否有等待者匹配
                lineQueue.append(line)
                checkWaiters()
            }
        }

        // 管道关闭：清理 readabilityHandler（P1-A 修复）
        outputPipe.fileHandleForReading.readabilityHandler = nil

        // 唤醒所有等待者（它们会得到 nil）
        for waiter in waiters {
            waiter.continuation.resume(returning: nil)
        }
        waiters.removeAll()
    }

    // MARK: - 等待接口（P0-3 修复：队列模型；P1-B 修复：超时安全移除）

    /// 等待包含指定 token 的行
    ///
    /// 超时后自动从 waiters 移除，避免 resume 已取消的 continuation（P1-B）
    func waitForToken(_ token: String, timeoutMs: Int) async throws {
        // 先检查队列
        if let matchIdx = lineQueue.firstIndex(where: { matches($0, token: token) }) {
            lineQueue.remove(at: matchIdx)
            return
        }

        // 创建等待者并入队（continuation 在竞速 block 内创建）
        let waiterID = UUID()
        let wToken = token

        // 竞速：等待匹配 vs 超时
        let result: String? = await withTaskGroup(of: String?.self) { [self] group in
            group.addTask {
                return await withCheckedContinuation { continuation in
                    let waiter = LineWaiter(id: waiterID, token: wToken, continuation: continuation)
                    self.waiters.append(waiter)
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first ?? nil
        }

        // 无论成功还是超时，都从 waiters 移除（P1-B 关键修复）
        waiters.removeAll { $0.id == waiterID }

        guard result != nil else {
            throw UCIError.engineTimeout
        }
    }

    /// 等待 bestmove 行，返回 UCI 走法字符串
    ///
    /// 超时后自动从 waiters 移除（P1-B）
    func waitForBestMove(timeoutMs: Int) async -> String? {
        // 先检查队列
        if let matchIdx = lineQueue.firstIndex(where: { $0.hasPrefix("bestmove") }) {
            let line = lineQueue.remove(at: matchIdx)
            return parseBestMove(line: line)
        }

        let waiterID = UUID()

        let result = await withTaskGroup(of: String?.self) { [self] group in
            group.addTask {
                return await withCheckedContinuation { continuation in
                    let waiter = LineWaiter(id: waiterID, token: "bestmove", continuation: continuation)
                    self.waiters.append(waiter)
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first ?? nil
        }

        // 无论成功还是超时，都从 waiters 移除（P1-B 关键修复）
        waiters.removeAll { $0.id == waiterID }

        return result
    }

    // MARK: - 回调设置

    func setInfoCallback(_ callback: @escaping @Sendable (UCIInfo) -> Void) {
        _onInfo = callback
    }

    // MARK: - 私有

    private func checkWaiters() {
        var matched: [(waiterIdx: Int, lineIdx: Int)] = []
        for (wi, waiter) in waiters.enumerated() {
            if let li = lineQueue.firstIndex(where: { matches($0, token: waiter.token) }) {
                matched.append((wi, li))
            }
        }
        // 从后往前移除（避免索引偏移）
        for (wi, li) in matched.sorted(by: { $0.waiterIdx > $1.waiterIdx }) {
            let waiter = waiters.remove(at: wi)
            let line = lineQueue.remove(at: li)
            if waiter.token == "bestmove" {
                let move = parseBestMove(line: line)
                waiter.continuation.resume(returning: move)
            } else {
                waiter.continuation.resume(returning: "")
            }
        }
    }

    // MARK: - 注入 continuation（actor 内部使用）
    //
    // LineWaiter 的 continuation 由 waitForToken/BestMove 通过
    // withCheckedContinuation 创建后注入。这个设计使得：
    // 1. 等待者创建和入队是原子操作（在 actor 上下文中）
    // 2. 超时时可以通过 ID 安全移除，不会 resume 已取消的 continuation
    // 3. checkWaiters 匹配后直接 resume + remove

    private func matches(_ line: String, token: String) -> Bool {
        line == token || line.hasPrefix(token + " ") || line.contains(" \(token) ")
    }

    private func parseBestMove(line: String) -> String? {
        let parts = line.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        return String(parts[1])
    }
}

/// 等待者——使用 class 获得 ID 匹配能力（P1-B）
private final class LineWaiter {
    let id: UUID
    let token: String
    let continuation: CheckedContinuation<String?, Never>
    init(id: UUID, token: String, continuation: CheckedContinuation<String?, Never>) {
        self.id = id
        self.token = token
        self.continuation = continuation
    }
}

/// UCI info 行解析结果
struct UCIInfo {
    let depth: Int?
    let nodes: Int?
    let score: Int?       // 厘兵（centipawn）；mate 转为 ±100000+
    let nps: Int?
    let pv: String?
    let timeMs: Int?

    static func parse(line: String) -> UCIInfo {
        let tokens = line.split(separator: " ").map(String.init)
        var depth: Int?, nodes: Int?, score: Int?, nps: Int?, pv: String?, timeMs: Int?

        var i = 1  // 跳过 "info"
        while i < tokens.count {
            switch tokens[i] {
            case "depth":  if i + 1 < tokens.count { depth = Int(tokens[i + 1]); i += 2 }
            case "nodes":  if i + 1 < tokens.count { nodes = Int(tokens[i + 1]); i += 2 }
            case "time":   if i + 1 < tokens.count { timeMs = Int(tokens[i + 1]); i += 2 }
            case "nps":    if i + 1 < tokens.count { nps = Int(tokens[i + 1]); i += 2 }
            case "score":
                if i + 2 < tokens.count {
                    let value = Int(tokens[i + 2]) ?? 0
                    score = tokens[i + 1] == "mate" ? (value > 0 ? 100000 + value : -100000 - value) : value
                    i += 3
                } else { i += 1 }
            case "pv":
                pv = tokens[(i + 1)...].joined(separator: " ")
                i = tokens.count
            default: i += 1
            }
        }
        return UCIInfo(depth: depth, nodes: nodes, score: score, nps: nps, pv: pv, timeMs: timeMs)
    }
}

enum UCIError: Error {
    case notAttached
    case engineTimeout
    case engineCrashed
    case invalidResponse(String)
}

#endif
```

> **通信模型说明（P0-2 + P0-3 修复原理）**：
>
> **旧 Bug 1**：`readToEnd()` 阻塞到管道关闭（引擎退出才返回），长运行引擎完全不可用。
>
> **旧 Bug 2**：`AsyncStream` 是单消费者序列。`waitForResponse` return 后，到下一次调用之间引擎输出的行无人消费，直接丢失。
>
> **新方案**：持续读取 + 队列分发模型：
> 1. 后台 Task 用 `readabilityHandler` + `availableData` 增量读取（不阻塞）
> 2. 按行分割后入 `lineQueue`（info 行直接回调，不入队）
> 3. 等待方先检查队列已有行，不匹配则挂起为 `LineWaiter`
> 4. 每次新行入队后 `checkWaiters()`，匹配则唤醒对应等待者
> 5. 队列持续保留未消费的行，多次 `waitForToken` 调用间不会丢数据

### 4.6 引擎配置模型

**文件**：`ChineseChess/Models/ExternalEngineConfig.swift`（新增）

> **v1.1 修订（P0-4）**：`options` 从 `[(String, String)]` 改为 `[UCIOption]`（Codable struct）。
> **v1.1 修订（P0-5）**：新增 `id: UUID` + `Identifiable`。

```swift
import Foundation

/// UCI 选项键值对（Codable 安全）
struct UCIOption: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String   // 如 "Hash"
    var value: String  // 如 "128"
}

/// 外部引擎配置（持久化到 UserDefaults）
struct ExternalEngineConfig: Codable, Equatable, Identifiable {
    var id: UUID = UUID()

    /// 引擎显示名称（用户自定义，如 "Pikafish 4.0"）
    var name: String

    /// 可执行文件路径（如 /usr/local/bin/pikafish）
    var executablePath: String

    /// 启动参数（可选，如 ["--threads=2"]）
    var arguments: [String]?

    /// UCI 选项列表（如 Hash=128, Threads=2）
    var options: [UCIOption]

    /// 是否启用
    var isEnabled: Bool

    /// 默认配置
    static let defaultConfig = ExternalEngineConfig(
        name: "",
        executablePath: "",
        arguments: nil,
        options: [],
        isEnabled: false
    )
}

/// 引擎配置管理器（单例）
@Observable
final class EngineConfigStore {
    static let shared = EngineConfigStore()

    private let key = "chinesechess.externalEngines"

    /// 所有已配置的外部引擎列表
    var engines: [ExternalEngineConfig] {
        didSet { save() }
    }

    /// 当前选中的外部引擎 ID（nil 表示使用自研引擎）
    var selectedEngineId: UUID? {
        didSet {
            UserDefaults.standard.set(selectedEngineId?.uuidString, forKey: "chinesechess.selectedEngine")
        }
    }

    /// 当前是否使用外部引擎
    var useExternalEngine: Bool {
        selectedEngineId != nil
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ExternalEngineConfig].self, from: data) {
            engines = decoded
        } else {
            engines = []
        }
        if let idStr = UserDefaults.standard.string(forKey: "chinesechess.selectedEngine"),
           let uuid = UUID(uuidString: idStr) {
            selectedEngineId = uuid
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(engines) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func addEngine(_ config: ExternalEngineConfig) {
        engines.append(config)
    }

    func removeEngine(at index: Int) {
        let removed = engines[index]
        engines.remove(at: index)
        if selectedEngineId == removed.id {
            selectedEngineId = nil
        }
    }
}
```

### 4.7 EngineRouter — 引擎路由器

**文件**：`ChineseChess/AI/EngineRouter.swift`（新增）

> **v1.1 修订（P1-7）**：`activeEngine()` 不再有隐含副作用。新增显式 `switchEngineIfNeeded()` async 方法负责创建+启动新引擎。getter 只返回已有实例。

```swift
/// 引擎路由器——根据用户设置返回合适的引擎实例
final class EngineRouter {
    static let shared = EngineRouter()

    private let nativeEngine = AIEngine()
    #if os(macOS)
    private var externalEngine: ExternalEngineManager?
    private var currentConfigId: UUID?
    #endif

    private init() {}

    /// 获取当前活跃引擎（无副作用，只返回已有实例）
    func activeEngine() -> ChessEngine {
        #if os(macOS)
        if let ext = externalEngine {
            return ext
        }
        #endif
        return nativeEngine
    }

    #if os(macOS)
    /// 检查并执行引擎切换（如有必要）——在对局开始前调用
    /// - Returns: 切换后的活跃引擎。启动失败时 fallback 到自研引擎。
    func switchEngineIfNeeded() async -> ChessEngine {
        let store = EngineConfigStore.shared

        if let selectedId = store.selectedEngineId,
           let config = store.engines.first(where: { $0.id == selectedId }),
           config.isEnabled {
            // 配置没变，引擎已存在——无需切换
            if currentConfigId == config.id {
                return externalEngine ?? nativeEngine
            }
            // 配置变更——重新创建并启动
            if let ext = externalEngine {
                await ext.shutdown()
            }
            let newEngine = ExternalEngineManager(config: config)
            do {
                try await newEngine.start()
                externalEngine = newEngine
                currentConfigId = config.id
                return newEngine
            } catch {
                // 启动失败——fallback
                externalEngine = nil
                currentConfigId = nil
                return nativeEngine
            }
        } else {
            // 使用自研引擎——清理外部引擎
            if let ext = externalEngine {
                await ext.shutdown()
                externalEngine = nil
                currentConfigId = nil
            }
            return nativeEngine
        }
    }
    #endif

    /// 获取自研引擎（直接访问）
    var native: AIEngine { nativeEngine }

    /// 通知引擎开始新对局
    func newGame() {
        nativeEngine.newGame()
        #if os(macOS)
        if externalEngine != nil {
            Task { await externalEngine?.newGame() }
        }
        #endif
    }

    /// 关闭所有引擎（App 退出时调用）
    func shutdown() {
        #if os(macOS)
        if let ext = externalEngine {
            Task { await ext.shutdown() }
            externalEngine = nil
            currentConfigId = nil
        }
        #endif
    }
}
```

> **生命周期约定（P2-12 修复）**：
> - `switchEngineIfNeeded()` 在**对局开始前**调用（`GameViewModel.newGame()` 中），不在对局中途切换
> - `activeEngine()` 在**对局中**调用（`triggerAIMove()` 中），纯 getter 无副作用
> - `newGame()` 在每局开始时调用，转发到当前引擎
> - `shutdown()` 在 **App 退出时**调用（`.scenePhase == .background` 或 `NSApplicationDelegate.terminate`）

### 4.8 GameViewModel 适配

**文件**：`ChineseChess/ViewModels/GameViewModel.swift`（修改）

改动范围最小化——只改 `triggerAIMove()` 和 `requestHint()`：

```swift
// 修改前：
private let aiEngine = AIEngine()
// ...
let move = engine.bestMove(for: snapshot, difficulty: currentDifficulty, isIOS: Self._isIOS)

// 修改后：
private var currentEngine: ChessEngine {
    EngineRouter.shared.activeEngine()
}
// ...
// 走 ChessEngine 协议
let fen = FENParser.generate(board: snapshot)                    // P0-1: 复用 FENParser
let uciMoves = snapshot.moveHistory.map { UCIMoveConverter.uciString(from: $0) }
let uciMove = await currentEngine.bestMove(
    fen: fen,
    moveHistory: uciMoves,
    difficulty: currentDifficulty,
    timeLimitMs: 0
)
// UCI move → 完整 Move（P1-9: piece + captured 都在转换中构造）
guard let uciMove = uciMove,
      let move = UCIMoveConverter.move(from: uciMove, on: self.board) else { return }
// move 已包含 piece（from 位置的棋子）和 captured（to 位置的被吃棋子）
// 后续逻辑直接使用 move，与原 triggerAIMMove 完全一致
```

**关键约束**：
- `triggerAIMove()` 需从 `Task.detached` + 回调改为 `Task { await }` 模式（因为 `ChessEngine.bestMove` 是 async）
- 改动控制在 `triggerAIMove()` 和 `requestHint()` 两个方法内
- 棋谱生成、棋子动画、音效播放等逻辑完全不动

> **v1.1 修订（P1-9）**：`UCIMoveConverter.move(from:on:)` 在 board 上查找 from 位置棋子和 to 位置被吃棋子，构造完整的 `Move(piece:from:to:captured:)`。调用方无需额外处理。

---

## 五、设置界面设计

### 5.1 macOS 引擎设置面板

**文件**：`ChineseChess/Views/EngineSettingsView.swift`（新增）

```swift
import SwiftUI

struct EngineSettingsView: View {
    @State private var store = EngineConfigStore.shared
    @State private var showingFilePicker = false
    @State private var showingAddSheet = false
    @State private var testingStatus: TestStatus = .idle

    var body: some View {
        #if os(macOS)
        Section("引擎设置") {
            // 引擎来源选择（P2-13: 修正绑定逻辑）
            Picker("AI 引擎", selection: Binding(
                get: { store.useExternalEngine ? "external" : "native" },
                set: { newValue in
                    if newValue == "native" {
                        store.selectedEngineId = nil
                    }
                    // "external" 时不自动选具体引擎，用户从列表选
                }
            )) {
                Text("内置引擎").tag("native")
                Text("外部引擎").tag("external")
            }
            .pickerStyle(.radioGroup)

            if store.useExternalEngine {
                // 外部引擎列表
                ForEach(store.engines) { engine in
                    EngineRowView(
                        engine: engine,
                        isSelected: store.selectedEngineId == engine.id,
                        onSelect: { store.selectedEngineId = engine.id }
                    )
                }

                Button("添加引擎…") {
                    showingAddSheet = true
                }

                // 引擎测试
                if let selected = store.engines.first(where: { $0.id == store.selectedEngineId }) {
                    Divider()
                    EngineTestView(config: selected, status: $testingStatus)
                }
            }
        }
        #endif
    }
}
```

### 5.2 设置嵌入位置

在 `SettingsView.swift` 中，`#if os(macOS)` 条件下嵌入：

```swift
#if os(macOS)
Section("引擎") {
    NavigationLink {
        EngineSettingsView()
    } label: {
        HStack {
            Image(systemName: "cpu")
                .foregroundColor(.brown)
            Text("外部引擎")
        }
    }
}
#endif
```

### 5.3 引擎测试功能

设置界面提供"测试连接"按钮，验证：
1. 可执行文件路径有效
2. 进程可启动
3. UCI 握手成功（收到 `uciok` + `readyok`）
4. 可执行 `position startpos` + `go depth 5` 并收到 `bestmove`

测试结果显示在 UI 上（✅ 成功 / ❌ 失败原因）。

---

## 六、UCI 协议通信详解

### 6.1 完整通信流程

```
App                           Engine Process
 │                                  │
 │  ─── "uci\n" ─────────────────→  │
 │  ←── "id name Pikafish 4.0\n" ── │
 │  ←── "id author ...\n" ───────── │
 │  ←── "option name Hash ...\n" ── │
 │  ←── "uciok\n" ───────────────── │
 │                                  │
 │  ─── "setoption name Hash value 256\n" ─→ │
 │  ─── "isready\n" ──────────────→ │
 │  ←── "readyok\n" ─────────────── │
 │                                  │
 │  ─── "ucinewgame\n" ───────────→ │
 │  ─── "position startpos\n" ────→ │
 │  ─── "go movetime 3000\n" ─────→ │
 │  ←── "info depth 1 ...\n" ────── │
 │  ←── "info depth 2 ...\n" ────── │
 │  ←── "info depth 15 ...\n" ───── │
 │  ←── "bestmove h2e2 ponder ...\n"│
 │                                  │
 │  ─── "quit\n" ─────────────────→ │
 │                                  X (进程退出)
```

### 6.2 错误处理策略

| 场景 | 处理策略 |
|------|---------|
| 可执行文件不存在 | `start()` 抛错，UI 提示路径无效 |
| 进程启动失败 | `start()` 抛错，UI 提示检查权限 |
| UCI 握手超时（10s 无 `uciok`） | 终止进程，提示"不是有效的 UCI 引擎" |
| 搜索超时（30s 无 `bestmove`） | 发送 `stop`，如 5s 内仍无响应则 `terminate` |
| 进程意外终止 | `terminationHandler` 回调，fallback 到自研引擎，UI 提示 |
| 管道读取出错 | 关闭连接，清理资源，fallback 到自研引擎 |
| stdin 写入失败（P1-10） | 设 `isReady = false`，上层 fallback 到自研引擎 |
### 6.3 难度→参数映射

外部引擎不接受"难度"概念，需要转换为 UCI `go` 命令参数：

| 难度 | go 命令策略 | 理由 |
|------|-----------|------|
| 新手 | `go depth 2` + Multi-PV 随机选次优（详见§9.5） | 外部引擎即使 depth 2 也很强，需主动降弱 |
| 初级 | `go depth 5` | 基础水平 |
| 中级 | `go depth 10` | 中等水平 |
| 高级 | `go depth 18` | 较高水平 |
| 大师 | `go depth 24` 或 `go movetime 3000` | 全力 |

> ⚠️ **新手/初级映射需调优**：Pikafish 在 depth 2 时已经很强，可能需要 Multi-PV 随机选择次优走法来实现"新手"效果。这是调优项，非架构问题。

---

## 七、文件清单

| 文件 | 操作 | 平台 | 说明 |
|------|------|------|------|
| `AI/EngineProtocol.swift` | **新增** | 全平台 | `ChessEngine` 协议、`EngineType` 枚举 |
| `AI/UCIMoveConverter.swift` | **新增** | 全平台 | UCI move ↔ Position/Move 转换 + FEN+moves → Board（复用 `FENParser`） |
| `AI/EngineRouter.swift` | **新增** | 全平台 | 引擎路由器，根据设置返回引擎实例 |
| `AI/ExternalEngineManager.swift` | **新增** | macOS only | 外部引擎进程管理（`#if os(macOS)`） |
| `AI/UCITransceiver.swift` | **新增** | macOS only | UCI 协议收发器（`#if os(macOS)`） |
| `AI/AIEngine.swift` | **修改** | 全平台 | 新增 `ChessEngine` 协议实现的 extension |
| `Models/ExternalEngineConfig.swift` | **新增** | 全平台 | 引擎配置模型 + `UCIOption` + `EngineConfigStore` |
| `Views/EngineSettingsView.swift` | **新增** | macOS only | 引擎设置面板（`#if os(macOS)`） |
| `Views/SettingsView.swift` | **修改** | 全平台 | 嵌入引擎设置入口（macOS 条件编译） |
| `ViewModels/GameViewModel.swift` | **修改** | 全平台 | `triggerAIMove` / `requestHint` 改用 `ChessEngine` 协议 |

**代码量预估**：

| 模块 | 新增行数 | 修改行数 |
|------|---------|---------|
| EngineProtocol | ~35 | - |
| UCIMoveConverter | ~80 | - |
| EngineRouter | ~80 | - |
| ExternalEngineManager | ~200 | - |
| UCITransceiver | ~200 | - |
| ExternalEngineConfig + UCIOption | ~100 | - |
| EngineSettingsView | ~200 | - |
| AIEngine 适配 | ~30 | - |
| SettingsView | - | ~10 |
| GameViewModel | - | ~50 |
| **合计** | ~925 | ~60 |

---

## 八、分期实施计划

### Phase 2a（Week 1）：基础架构

**目标**：跑通自研引擎 → ChessEngine 协议 → GameViewModel 全链路

| 任务 | 产出 |
|------|------|
| `EngineProtocol.swift` | 协议定义 |
| `UCIMoveConverter.swift` | UCI move 转换 + FEN+moves→Board + 单元测试 |
| `AIEngine` extension | 自研引擎适配 |
| `EngineRouter` | 路由逻辑（仅 native 路径） |
| `GameViewModel` 适配 | 改用 `ChessEngine` 协议 |

**验收**：所有现有测试通过，功能无回归。

### Phase 2b（Week 2）：外部引擎通信

**目标**：跑通 Process + UCI 协议 → bestmove 全链路

| 任务 | 产出 |
|------|------|
| `ExternalEngineManager.swift` | actor 进程管理 + 生命周期 |
| `UCITransceiver.swift` | actor UCI 协议收发 + 队列分发 + 解析 |
| 错误处理 + 超时机制 | 健壮性保障 |
| Mock UCI 引擎测试脚本 | 集成测试基础设施（P2-15） |
| 引擎测试 | 手动用 Pikafish macOS 版验证 |

**验收**：能通过代码启动 Pikafish，发送 position，收到 bestmove。

### Phase 2c（Week 3）：设置界面 + 集成

**目标**：用户可在设置界面配置引擎，游戏中自动路由

| 任务 | 产出 |
|------|------|
| `ExternalEngineConfig.swift` | 配置模型 + 持久化 |
| `EngineConfigStore` | 配置管理单例 |
| `EngineSettingsView.swift` | 设置 UI |
| `SettingsView` 嵌入 | 设置入口 |
| `EngineRouter` 完整路由 | 双引擎切换 |
| `GameViewModel` 完整适配 | 外部引擎走棋 |

**验收**：用户可在设置中选择引擎，游戏中外部引擎正常走棋。

---

## 九、关键技术决策记录

### 9.1 为什么不修改现有 `AIEngineProtocol`

现有 `AIEngineProtocol.bestMove(for:difficulty:isIOS:)` 的签名绑定了 `Board` 类型。外部引擎不认识 `Board`，需要 FEN。修改 `AIEngineProtocol` 会破坏现有所有引用。

**决策**：新建 `ChessEngine` 协议（更高层抽象），`AIEngine` 同时实现两个协议。`AIEngineProtocol` 保留不动。

### 9.2 为什么用 FEN 而不是改 Board

考虑过让外部引擎直接操作 `Board` 对象。但 UCI 协议要求传递 FEN 字符串，转换不可避免。

**决策**：FEN 生成/解析复用现有 `FENParser`，UCI move 转换集中在 `UCIMoveConverter`。

### 9.3 为什么用 Actor + 队列而不是 AsyncStream

> **v1.1 修订（P0-3）**

原方案用 `AsyncStream` 单消费者模型，但存在致命缺陷：`waitForResponse` return 后到下一次调用之间产生的行无人消费，直接丢失。

**决策**：改为 actor + 行缓冲队列 + 等待者列表模型。后台 Task 持续消费管道输出入队，等待方从队列按条件取行。队列持续保留未消费的行。

### 9.4 为什么外部引擎设置不做 iOS 适配

iOS 沙箱不允许创建子进程（`Process` API 不可用），UCI 外部进程方案在 iOS 上完全不可行。

**决策**：所有外部引擎代码用 `#if os(macOS)` 隔离。iOS 的强引擎方案是 Phase 10 的 C 静态库路线。

### 9.5 新手难度的外部引擎降弱策略

Pikafish 等 NNUE 引擎即使 depth 2 也远超人类业余水平。

**决策**：
- **Phase 2 范围**：新手/初级直接限制 depth（`go depth 2/5`），不实现 Multi-PV 随机（P2-11）
- **随机逻辑位置**：如需 30% 概率随机走法，在 `GameViewModel` 层实现（不走引擎命令）
- **Phase 3+ 可选增强**：Multi-PV 选次优走法，或新手/初级强制使用自研引擎

---

## 十、风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| UCI 协议兼容性差异 | 中 | 中 | 严格按 UCI 标准实现，测试 2+ 款引擎 |
| 管道读取丢数据 | 低 | 高 | actor 队列模型 + 单元测试覆盖 |
| 引擎进程僵尸 | 低 | 中 | `terminationHandler` + App 退出时强制清理 |
| macOS Gatekeeper 阻止运行 | 中 | 高 | 文档引导用户 `chmod +x` 和允许"任何来源" |
| UCI move 转换 Bug | 中 | 高 | 往返转换单元测试，含初始局面/复杂局面/残局 |
| ExternalEngineManager actor 上下文跳转开销 | 低 | 低 | 搜索期间只有单次 `await` 调用，开销可忽略 |

---

## 十一、测试策略

### 11.1 单元测试

| 测试项 | 范围 |
|--------|------|
| `UCIMoveConverter.uciString` | Move → UCI string，验证各棋子类型 |
| `UCIMoveConverter.positions` | UCI string → Position pair 往返 |
| `UCIMoveConverter.move(from:on:)` | UCI string → Move（含 piece + captured）（P1-9） |
| `UCIMoveConverter.board(from:moves:)` | FEN + moves → Board，验证走法应用 |
| `FENParser` 回归 | 现有 FEN 转换不受影响 |
| `UCIInfo.parse` | 各种 info 行格式解析 |
| `ExternalEngineConfig` 编解码 | Codable 持久化往返（P0-4 验证） |

### 11.2 集成测试（macOS only）

| 测试项 | 范围 |
|--------|------|
| 引擎启动 + UCI 握手 | mock UCI 引擎脚本（P2-15: Phase 2b 提供骨架） |
| position + go + bestmove | 完整走棋流程 |
| 引擎超时 | 不响应的进程，验证超时 fallback |
| 引擎崩溃 | 进程中途退出，验证 cleanup |
| 双引擎切换 | 运行时切换 native ↔ external |

### 11.3 回归测试

| 测试项 | 范围 |
|--------|------|
| 现有全部单元测试 | `swift test` 全通过 |
| 自研引擎走棋 | 各难度对局正常 |
| 撤销/重做 | 走法历史正确 |
| 棋谱记录 | 中文/ICCS 格式正确 |

---

## 十二、依赖关系

```
Phase 1（v3.1 基础，如有）
  └── Phase 2a（ChessEngine 协议 + UCIMoveConverter）
        └── Phase 2b（外部引擎通信）
              └── Phase 2c（设置界面 + 集成）
                    ├── 输出 → Phase 9（引擎分析，利用 UCI info 回调）
                    └── 输出 → Phase 10（Pikafish iOS 集成，共用 ChessEngine 协议）
```

**与 Phase 10 的关系**：
- Phase 2 产出的 `ChessEngine` 协议和 `UCIMoveConverter` 可被 Phase 10 直接复用
- Phase 10 的 `PikafishBridge`（C 库方案）也实现 `ChessEngine` 协议
- 两个 Phase 独立，但共享协议层

---

## 十三、验收标准

| 验收项 | 标准 | 验证方法 |
|--------|------|---------|
| ChessEngine 协议 | 自研引擎通过协议走棋，功能无回归 | 全部现有测试通过 |
| UCI move 转换正确性 | 初始局面 + 10 个随机局面往返转换一致 | 单元测试 |
| 外部引擎启动 | Pikafish macOS 版可启动并完成 UCI 握手 | 手动 + 集成测试 |
| 外部引擎走棋 | 完整对局走棋正常，走法合法 | 手动对局 |
| 引擎切换 | 切换引擎不影响当前对局（仅对局间切换） | 手动验证 |
| 设置界面 | 添加/删除/选择引擎，路径配置，测试连接 | 手动验证 |
| 引擎崩溃恢复 | 引擎意外退出后 fallback 到自研引擎 | 集成测试 |
| macOS only 隔离 | iOS 编译不受影响 | iOS target 编译通过 |
| 现有测试 | 全部通过 | `swift test` |

---

## 附录 A：Vera 审查修复追踪表（v1.2）

| 编号 | 级别 | 问题 | 修复方案 | 状态 |
|------|------|------|---------|------|
| P0-1 | 🔴 | FenConverter 与现有 FENParser 功能重叠 | 重命名为 `UCIMoveConverter`，只做 UCI move 转换 + FEN+moves→Board，FEN 转换复用 `FENParser` | ✅ |
| P0-2 | 🔴 | `readToEnd()` 阻塞到管道关闭 | 改用 `availableData` 增量读取 | ✅ |
| P0-3 | 🔴 | AsyncStream 单消费者丢数据 | 改为 actor + 行缓冲队列 + 等待者列表模型 | ✅ |
| P0-4 | 🔴 | `[(String, String)]` 不符合 Codable | 改为 `[UCIOption]`（Codable struct） | ✅ |
| P0-5 | 🔴 | 缺少 `id: UUID` + `Identifiable` | 加 `var id: UUID = UUID()`，声明 `Identifiable` | ✅ |
| P1-6 | 🟠 | 非 actor 却多线程访问 | `ExternalEngineManager` 改为 `actor` | ✅ |
| P1-7 | 🟠 | `activeEngine()` 有隐含副作用，新建引擎未 start() | 拆分为 `switchEngineIfNeeded()` (async) + `activeEngine()` (纯 getter) | ✅ |
| P1-8 | 🟠 | `ucinewgame` 缺失 | 新增 `newGame()` 方法，`ChessEngine` 协议 + `EngineRouter` 转发 | ✅ |
| P1-9 | 🟠 | UCI move → Move 缺少 piece/captured 构造 | `UCIMoveConverter.move(from:on:)` 在 board 上查找，构造完整 Move | ✅ |
| P1-10 | 🟠 | `sendCommand` 静默吞错 | 改为 `throws`，写入失败时设 `isReady = false` | ✅ |
| P2-11 | 🟡 | 新手难度 30% 随机未在代码体现 | §9.5 补充：随机逻辑在调用方层处理，引擎命令层只负责 `go` 参数 | ✅ |
| P2-12 | 🟡 | App 退出时引擎清理路径 | `EngineRouter.shutdown()` 文档明确调用时机 | ✅ |
| P2-13 | 🟡 | 设置界面 Picker 绑定逻辑有误 | 修正 setter 逻辑，"external" 时不自动选具体引擎 | ✅ |
| P2-14 | 🟡 | §4.3 FEN 示例格式错误 | 整段重写，移除错误示例，指向 FENParser | ✅ |
| P2-15 | 🟡 | 集成测试 mock 引擎脚本无规格 | Phase 2b 实施时提供 | 📌 待实施 |
| P2-16 | 🟡 | design-checklist.md 不存在 | 非方案问题，记录备查 | 📌 记录 |
| **P1-A** | 🟠 | **v1.1 新增** readabilityHandler EOF 后未清理 | `continuousRead` 正常退出后加 `readabilityHandler = nil` | ✅ v1.2 |
| **P1-B** | 🟠 | **v1.1 新增** 超时后等待者未移除，resume 已取消 continuation 会 crash | 等待者改为 class 带 UUID，竞速结束后 `waiters.removeAll { $0.id == waiterID }` | ✅ v1.2 |
| **P1-C** | 🟠 | **v1.1 新增** actor 的 isReady 不满足协议同步 get，不编译 | 协议改为 `var isReady: Bool { get async }`，AIEngine 同步 return true（编译器自动包装） | ✅ v1.2 |
