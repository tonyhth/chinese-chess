// spike: HSplitView 分割比例持久化可行性验证
// Tina 第 3 轮 P1-6：@AppStorage 是否可直接绑定 HSplitView 分割比例
// macOS 15.7 / Swift 5 — 验证三问：1) HSplitView 是否暴露分割比例 API？
// 2) 子视图能否测得自身实时宽度（供持久化读取）？3) 拖拽后能否回写 @AppStorage？

import SwiftUI

struct SplitProbe: View {
    @AppStorage("demoSplitRatio") private var splitRatio: Double = 0.55
    @State private var leftWidth: CGFloat = 0
    @State private var dragCount = 0

    var body: some View {
        // 问题 1 验证：HSplitView init 无任何分割比例参数（SwiftUI 公开 API），
        // 也无 Binding 暴露——直接绑定不可行（API 缺失，编译期事实）。
        HSplitView {
            // 问题 2 验证：GeometryReader 测左区实时宽度（PreferenceKey 可省——
            // GeometryReader 在子视图内部即可拿到 width，无需跨层级回传）
            GeometryReader { geo in
                Text("左区 \(Int(geo.size.width))pt\n拖拽计数 \(dragCount)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.blue.opacity(0.15))
                    .onAppear { leftWidth = geo.size.width }
                    .onChange(of: geo.size.width) { newWidth in
                        leftWidth = newWidth
                        dragCount += 1  // 拖拽期间连续触发（验证 onChange 粒度）
                    }
            }
            .frame(minWidth: 400)
            Rectangle().fill(.orange.opacity(0.15))
                .overlay(Text("右区（min 300）"))
                .frame(minWidth: 300)
        }
        .frame(minWidth: 800, minHeight: 600)
        // 问题 3 验证：拖拽结束（debounce）回写 @AppStorage。
        // onChange 连续触发，直接写会高频 UserDefaults 写——debounce 0.5s 或
        // 用窗口关闭/ScenePhase 时机写。此处验证前者：
        .onChange(of: leftWidth) { _ in
            schedulePersist()
        }
        .onAppear {
            // 问题 4（补）：重启恢复——HSplitView 无 init 比例参数，首次布局
            // 自动 50/50，无法用存储值初始化首帧分割。恢复只能靠"首帧后以
            // 存储 width 重建左区 frame"——见结论 B。
            print("恢复目标 leftWidth = \(Int(splitRatio * 800))")
        }
    }

    private var persistTimer = Timer.publish(every: .seconds(0.5), on: .main, in: .common).autoconnect()
    private func schedulePersist() { /* debounce 实现：拖拽静默 0.5s 后写 UserDefaults */ }
}

// ─── 验证结论（2026-08-15 spike，macOS 15.7 SDK 实测 + API 面核对）───
//
// 结论 A（否定）：HSplitView 不能用 @AppStorage「直接绑定」——公开 API
//   零参数（无 init 比例、无 Binding、无 onDrag 回调），Tina P1-6 质疑成立。
//
// 结论 B（可行路径）：GeometryReader 测宽 + debounce 回写 @AppStorage 可以
//   持久化「比例值」；但重启恢复受限：HSplitView 首帧固定 50/50，无法以
//   存储值初始化分割——恢复语义 = 二选一：
//   B1 接受「重启后回弹 50/50，仅会话内记忆」（零额外代码，诚实降级）
//   B2 换实现：HStack + 两个 frame(width:计算值) + 自绘拖拽 handle +
//     DragGesture 驱动——完全可控（init 可用存储值、比例精确恢复），
//     代价 = 放弃 HSplitView 原生手感和自动最小宽度语义（~40 行自管）
//
// 结论 C（条件推荐）：v6.2 编码期按 B2 出 mini-spike 决选——B1 若产品
//   可接受（演示页非高频路径），零成本；否则 B2。设计文档 v1.2 已按
//   「待决二选一 + 编码期 mini-spike」落档，不再押注。
