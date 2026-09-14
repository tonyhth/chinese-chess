import Foundation

// MARK: - v6.4 C0：LAYOUT_DUMP 参数通道（骨架）
//
// 依据：v6.4-layout-redesign.md §2 原则六可执行规格 #2（Ruby P0-1）
// - Debug 构建 env LAYOUT_DUMP=1 时，窗口 resize 采样点输出布局参数 JSON（一行一采样）
// - 本期只建骨架：P1 页接入（width + rail 展开 + 棋盘 cell 尺寸）；后续期逐页扩展参数
// - 定位：像素锚 harness 的对偶件——Tina harness 消费该流做单调断言，像素 diff 只对锚点档位有效

enum LayoutDump {

    /// 通道开关（env 单源，默认关）
    static var isEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["LAYOUT_DUMP"] == "1"
        #else
        return false
        #endif
    }

    // v6.4 C3-3：文件桥 harness（open -a 通道 env 丢失的工程绕道，DEBUG only）
    //
    // 背景：direct exec env 可靠但本机 LaunchServices 激活链时好时坏（2026-09-14
    // 实测会话内 60%→0% 渐进退化）；open -a 起窗可靠但 env 经 LaunchServices
    // 隔离丢失（--env 旗标本机实测同样不达）。两通道各缺一半。
    // 方案：harness 参数从固定路径 JSON 文件读（采集脚本写入），双通道兼容——
    // env 优先，文件兜底；dump 输出也落同名 .dump 文件，不依赖 stdout 继承。
    // 产品路径零影响（文件不存在即短路）。
    //
    /// harness 桥文件路径（约定：采集脚本写、app 读）
    static let harnessBridgePath = URL(fileURLWithPath: "/tmp/v64c2-layout-harness.json")

    /// dump 落盘路径（桥文件路径 + .dump 后缀）
    static var harnessDumpPath: URL {
        harnessBridgePath.appendingPathExtension("dump")
    }

    /// 文件桥参数：play / width / dump 三键
    static var bridgeParams: [String: String]? {
        #if DEBUG
        guard FileManager.default.fileExists(atPath: harnessBridgePath.path) else { return nil }
        guard let data = try? Data(contentsOf: harnessBridgePath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return obj
        #else
        return nil
        #endif
    }

    /// 采样输出（一行一采样 JSON；仅 Debug + (env LAYOUT_DUMP=1 或桥文件 dump=1) 生效）
    /// 参数名稳定契约：page / width / 参数键值（后续期只增不改名）
    static func sample(page: String, width: CGFloat, params: [String: String]) {
        #if DEBUG
        let bridgeOn = bridgeParams?["dump"] == "1"
        guard isEnabled || bridgeOn else { return }
        var fields: [String: String] = [
            "page": page,
            "width": String(Int(width)),
        ]
        fields.merge(params) { _, new in new }
        let pairs = fields.sorted(by: { $0.key < $1.key })
            .map { "\"\($0.key)\":\"\($0.value)\"" }
            .joined(separator: ",")
        let line = "LAYOUT_DUMP {\(pairs)}"
        print(line)
        // C3 健壮化：stdout 走管道时为全缓冲，进程被 kill 会丢整段缓冲
        // （C2 采集多次 0 行的根因）——每行采样即刷，kill-safe
        fflush(stdout)
        // C3-3 文件桥：dump 同时落盘（open -a 通道 stdout 不可捕获时仍可取证）
        if bridgeOn {
            if let handle = try? FileHandle(forWritingTo: harnessDumpPath) {
                _ = try? handle.seekToEnd()
                if let d = "\(line)\n".data(using: .utf8) {
                    try? handle.write(contentsOf: d)
                }
                try? handle.close()
            } else {
                try? "\(line)\n".write(to: harnessDumpPath, atomically: true, encoding: .utf8)
            }
        }
        #endif
    }
}
