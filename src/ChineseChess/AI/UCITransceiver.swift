#if os(macOS)

import Foundation

// MARK: - UCI 协议收发器

/// UCI 协议收发器（actor，线程安全）
///
/// 通信模型（v1.2 设计文档 P0-2 + P0-3 修复方案）：
/// 1. `attach()` 启动后台 Task，用 `readabilityHandler` + `availableData` 增量读取管道数据
/// 2. 按行分割后入 `lineQueue`（info 行直接回调，不入队）
/// 3. `waitForToken()` / `waitForBestMove()` 先检查队列已有行，不匹配则挂起为等待者
/// 4. 每次新行入队后调用 `checkWaiters()`，匹配则唤醒对应等待者
/// 5. 队列持续保留未消费的行，多次 `waitForToken` 调用间不会丢数据
actor UCITransceiver {

    // MARK: - 私有状态

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

    /// 绑定输出管道，启动持续读取
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
            waiter.holder.resume(with: nil)
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

        // 在 actor 隔离上下文中创建等待者
        let holder = ContinuationHolder()
        let waiter = LineWaiter(token: token, holder: holder)
        waiters.append(waiter)

        // 竞速：等待匹配 vs 超时（闭包不访问 actor 状态）
        let result: String? = await withTaskGroup(of: String?.self) { group in
            group.addTask {
                return await withCheckedContinuation { continuation in
                    holder.set(continuation)
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
        waiters.removeAll { $0 === waiter }

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

        // 在 actor 隔离上下文中创建等待者
        let holder = ContinuationHolder()
        let waiter = LineWaiter(token: "bestmove", holder: holder)
        waiters.append(waiter)

        let result = await withTaskGroup(of: String?.self) { group in
            group.addTask {
                return await withCheckedContinuation { continuation in
                    holder.set(continuation)
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
        waiters.removeAll { $0 === waiter }

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
                waiter.holder.resume(with: move)
            } else {
                waiter.holder.resume(with: "")
            }
        }
    }

    private func matches(_ line: String, token: String) -> Bool {
        line == token || line.hasPrefix(token + " ") || line.contains(" \(token) ")
    }

    private func parseBestMove(line: String) -> String? {
        let parts = line.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        return String(parts[1])
    }
}

// MARK: - Continuation 持有者

/// Continuation 持有者——解耦 actor 状态操作和 continuation 生命周期
///
/// 线程安全设计：
/// - `set()` 和 `resume(with:)` 都用锁保护
/// - `resume(with:)` 消费 continuation（置 nil），防止重复 resume
/// - 如果超时先到（resume 被调用），后续 checkWaiters 的 resume 是 no-op
private final class ContinuationHolder: @unchecked Sendable {
    private var continuation: CheckedContinuation<String?, Never>?
    private let lock = NSLock()

    func set(_ cont: CheckedContinuation<String?, Never>) {
        lock.lock()
        continuation = cont
        lock.unlock()
    }

    /// 恢复 continuation（仅一次有效）
    func resume(with value: String?) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: value)
    }
}

// MARK: - 等待者

/// 等待者——使用 class 获得引用同一性（用于 === 移除）
private final class LineWaiter {
    let token: String
    let holder: ContinuationHolder
    init(token: String, holder: ContinuationHolder) {
        self.token = token
        self.holder = holder
    }
}

// MARK: - UCI info 行解析

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

// MARK: - UCI 错误

enum UCIError: Error {
    case notAttached
    case engineTimeout
    case engineCrashed
    case invalidResponse(String)
}

#endif
