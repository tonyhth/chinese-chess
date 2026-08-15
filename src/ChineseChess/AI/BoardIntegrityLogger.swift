import Foundation

// MARK: - 棋盘完整性异常 dump（A3 EXIT:132 根治遥测）

/// 重叠局面 dump：A3 自对弈崩溃的根治数据来源。
///
/// 背景：EXIT:132 (SIGILL) 直接原因是 countPiecesBetween 在 from==to 时构造
/// (c+1)..<c 非法 Range；根因是棋盘出现重叠棋子（攻击者与将同格）。
/// 防御让进程不再 crash，但必须先 dump 再安全返回（顺序铁律：反了=吞异常丢数据）。
///
/// 通道设计说明（Ruby 快审重点）：
/// MoveValidator 是 static 泛型、无实例上下文、热路径（搜索内每秒可达百万次调用），
/// 注入 IO 依赖（闭包/协议参数）会污染所有调用方签名。故采用**全局静态 logger**：
/// - 枚举命名空间 + NSLock 保护，线程安全
/// - 命中异常才格式化/写盘，正常路径零开销（一次字典查询）
/// - 60s 同 reason 去抖，防热路径写爆磁盘
/// - 每条 entry 含 OVERLAP 关键字（供 grep），统一追加到 illegal-position-dump.log
enum BoardIntegrityLogger {

    /// dump 去抖窗口（秒）：同一 reason 窗口内只写一次
    private static let dedupWindow: TimeInterval = 60
    private static var lastDumpAt: [String: Date] = [:]
    private static let lock = NSLock()

    /// 运行上下文（lvl 对局/局号/ply），由 SelfPlayRunner 每步更新，dump 时原样带上。
    /// P1(Ruby 快审)：String 跨线程非原子——读写均过锁（写方=自对弈主循环，读方=搜索线程的 dumpOverlap）
    private static var _currentContext: String = ""
    static var currentContext: String {
        get { lock.lock(); defer { lock.unlock() }; return _currentContext }
        set { lock.lock(); defer { lock.unlock() }; _currentContext = newValue }
    }

    /// 日志目录（相对 cwd；测试注入临时目录）
    static var logDirectory: String = "overlap-dumps"

    /// 统一追加的日志文件名（单文件便于收集，OVERLAP 关键字供 grep）
    static var logFileName: String = "illegal-position-dump.log"

    /// 提取重叠棋子对（同格两组件，按位置分组）
    static func overlapPairs(in pieces: [Piece]) -> [[Piece]] {
        var byPos: [Position: [Piece]] = [:]
        for p in pieces { byPos[p.position, default: []].append(p) }
        return byPos.values.filter { $0.count > 1 }
    }

    /// 生成并追加 OVERLAP dump。先写盘再返回（调用方随后安全返回，不 crash）。
    /// - Parameters:
    ///   - reason: 异常类型标识（如 "countPiecesBetween_from==to" / "playGame_preExecute"）
    ///   - pieces: 当前棋盘全量（kind/side/row/col/id 全输出）
    ///   - recentMoves: 最近走法（含 captured 字段，建议传 suffix(10)）
    ///   - detail: 附加上下文（检查点检出的问题描述等）
    static func dumpOverlap(reason: String, pieces: [Piece], recentMoves: [Move], detail: String = "") {
        let now = Date()
        lock.lock()
        if let last = lastDumpAt[reason], now.timeIntervalSince(last) < dedupWindow {
            lock.unlock()
            return  // 同 reason 60s 内已 dump，跳过（热路径保护）
        }
        lastDumpAt[reason] = now
        lock.unlock()

        let timestamp = ISO8601DateFormatter().string(from: now)
        let thread = Thread.current
        let threadName = thread.name ?? ""
        // P1(Ruby): 经锁保护的计算属性读取，避免搜索线程读时撕裂
        let context = currentContext

        var lines: [String] = []
        lines.append("=== OVERLAP \(reason) ===")
        lines.append("time: \(timestamp)")
        lines.append("context: \(context.isEmpty ? "(未设置)" : context)")
        lines.append("thread: \(threadName.isEmpty ? "main" : threadName) (\(thread.isMainThread ? "main" : "background"))")
        if !detail.isEmpty { lines.append("detail: \(detail)") }

        // 重叠两组件（最关键信息放最前）
        let pairs = overlapPairs(in: pieces)
        lines.append("--- overlap pairs (\(pairs.count)) ---")
        if pairs.isEmpty {
            lines.append("  (无同格重叠——若本 dump 来自防御命中，检查重复 ID/其他非法态)")
        }
        for pair in pairs {
            let desc = pair.map { p in
                let side = p.side == .red ? "红" : "黑"
                return "id=\(p.id) \(p.kind) \(side) (\(p.position.row),\(p.position.col))"
            }.joined(separator: " ⚡ ")
            lines.append("  \(desc)")
        }

        // 双方 pieces 全量
        lines.append("--- board (\(pieces.count) pieces) ---")
        for p in pieces.sorted(by: { ($0.position.row, $0.position.col) < ($1.position.row, $1.position.col) }) {
            let side = p.side == .red ? "红" : "黑"
            lines.append("  id=\(p.id) \(p.kind) \(side) (\(p.position.row),\(p.position.col))")
        }

        // 最近走法（含 captured）
        lines.append("--- recent moves (last \(recentMoves.count), 含 captured) ---")
        for (i, m) in recentMoves.enumerated() {
            let cap = m.captured.map { " captured[id=\($0.id) \($0.kind)(\($0.position.row),\($0.position.col))]" } ?? ""
            let side = m.piece.side == .red ? "红" : "黑"
            lines.append("  #\(i + 1) id=\(m.piece.id) \(m.piece.kind)\(side) (\(m.from.row),\(m.from.col))→(\(m.to.row),\(m.to.col))\(cap)")
        }

        lines.append("--- call stack ---")
        lines.append(contentsOf: Thread.callStackSymbols.prefix(25))
        lines.append("")

        let content = lines.joined(separator: "\n")

        // NSLog 保证统一日志系统可见（Console.app 可查）
        NSLog("[OVERLAP] %@ — appended to %@/%@", reason, logDirectory, logFileName)

        let fm = FileManager.default
        try? fm.createDirectory(atPath: logDirectory, withIntermediateDirectories: true)
        let path = "\(logDirectory)/\(logFileName)"
        // 追加写（单文件聚合所有异常，便于收集；文件不存在则创建）
        if let handle = FileHandle(forWritingAtPath: path) {
            defer { try? handle.close() }
            _ = handle.seekToEndOfFile()
            if let data = content.data(using: .utf8) { try? handle.write(contentsOf: data) }
        } else {
            try? content.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
