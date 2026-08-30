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

    /// 采样输出（一行一采样 JSON；仅 Debug + LAYOUT_DUMP=1 生效）
    /// 参数名稳定契约：page / width / 参数键值（后续期只增不改名）
    static func sample(page: String, width: CGFloat, params: [String: String]) {
        #if DEBUG
        guard isEnabled else { return }
        var fields: [String: String] = [
            "page": page,
            "width": String(Int(width)),
        ]
        fields.merge(params) { _, new in new }
        let pairs = fields.sorted(by: { $0.key < $1.key })
            .map { "\"\($0.key)\":\"\($0.value)\"" }
            .joined(separator: ",")
        print("LAYOUT_DUMP {\(pairs)}")
        #endif
    }
}
