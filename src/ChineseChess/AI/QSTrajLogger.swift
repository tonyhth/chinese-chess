import Foundation

// MARK: - P4-③ A 项：QS 轨迹采样（测试注入，非行为变更——Luke 08-18 批，冻结令牌不重算）

/// QS 轨迹采样器。env `QS_TRAJ_LOG=1` 启用；缺省 **零开销零输出**（单 bool 判断短路）。
///
/// 口径（p34 v1.1 §2 A + Tina 开发单）：
/// - 采样率 **1/100**（Luke 裁定：轨迹分析要形态不要全集，I/O 不得拖慢搜索
///   毁掉 lvl5 对局时间锚）
/// - 落盘：逐样本一行 jsonl → `calibration-results/qs-traj-<hash8>.jsonl`
///   每行 = `{"fen":..., "cheap":..., "full":...}`（cheap/full 均为当前走方视角）
/// - `<hash8>`：env `QS_TRAJ_TAG` 优先（Tina harness 传 binary commit 短 hash）；
///   缺省 = run 级 id（pid^uptime → 8 hex，同 run 稳定、跨 run 几乎不撞）
/// - 采样点 = quiescenceSearch standPat cheap 分支（cheap 主路径上 cheap 已算出，
///   仅采样节点额外复算一次全量——差值即相关系数/flip 率样本）
/// - 仅 supportsCheapEval==true 路径采样（Legacy 后端零触碰）
///
/// 线程安全：NSLock（与 SeededRandom 同形态）。I/O 失败静默——校准注入不得影响搜索。
enum QSTrajLogger {

    static let enabled = ProcessInfo.processInfo.environment["QS_TRAJ_LOG"] == "1"

    /// Luke 裁定采样率：每 100 个 cheap-path QS 节点采 1 个
    static let sampleRate = 100

    private static let lock = NSLock()
    private static var counter = 0
    private static var handle: FileHandle?

    /// 计数轮转；仅 env 开启时计数（关闭 = 纯 bool false，零开销）
    static func shouldSample() -> Bool {
        guard enabled else { return false }
        lock.lock(); defer { lock.unlock() }
        counter &+= 1
        if counter == 1 { print("[QS_TRAJ] 启用：采样率 1/\(sampleRate)") }
        return counter % sampleRate == 0
    }

    /// 追加一行 jsonl（低频：sampleRate 分之一节点，同步写可接受且无缓冲丢失）
    static func log(fen: String, cheap: Int, full: Int) {
        // P2：FEN 字符集（棋子/数字/空格/斜杠/w b KQkq-）不含引号与反斜杠，免转义安全；
        // 若未来 FEN 来源变化（含引号/反斜杠），必须先加 JSON escaping 再写此行
        let line = "{\"fen\":\"\(fen)\",\"cheap\":\(cheap),\"full\":\(full)}\n"
        lock.lock(); defer { lock.unlock() }
        do {
            if handle == nil { try openFile() }
            try handle?.write(contentsOf: Data(line.utf8))
        } catch {
            if handle != nil { print("[QS_TRAJ] 写入失败：\(error)") }
            handle = nil  // 下次样本重试开文件；本条丢弃（采样容忍）
        }
    }

    private static func openFile() throws {
        let dir = URL(fileURLWithPath: "calibration-results", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tag = ProcessInfo.processInfo.environment["QS_TRAJ_TAG"] ?? defaultRunTag()
        let url = dir.appendingPathComponent("qs-traj-\(tag).jsonl")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()  // 追加模式：同 binary 复跑同 tag 续写
    }

    /// 缺省 run 标识（8 hex）
    private static func defaultRunTag() -> String {
        let pid = UInt64(getpid())
        let ms = UInt64(ProcessInfo.processInfo.systemUptime * 1000)
        return String(format: "%08x", UInt32(truncatingIfNeeded: pid ^ ms))
    }
}
