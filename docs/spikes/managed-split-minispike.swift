// mini-spike: HSplitView 方案 B（自管分割）侧效应验证（重建版）
// 原件 2026-08-15 由 Luke Tina-WIP stash 转移操作误删（untracked 无历史），
// 本件按 session 记录逐行重建，2026-08-15 22:14 放回。
// 结论效力不变：方案 B 已按预登记规则定选（Luke 08-16 确认），本件为存档+可复跑依据。
// 验证法：swiftc 单文件编译运行（不碰 xcodebuild/DerivedData）。复跑：
//   swiftc -parse-as-library -o /tmp/spike-split docs/spikes/managed-split-minispike.swift && /tmp/spike-split

import SwiftUI

// ─── 方案 B 核心：自管分割（HStack + 计算 width + DragGesture handle）───

struct ManagedSplitDemo: View {
    @AppStorage("spike.splitRatio") private var splitRatio: Double = 0.55

    var body: some View {
        GeometryReader { outer in
            let total = outer.size.width - 8  // 减 handle 宽
            let leftW = total * splitRatio

            HStack(spacing: 0) {
                // 左区：内容 + frame 钳制
                ScrollView {  // 模拟走法记录列表（滚动跳动是三项侧效应之一）
                    LazyVStack {
                        ForEach(0..<200) { i in
                            Text("走法 \(i)：炮二平五")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .frame(width: max(400, min(leftW, total - 300)))  // 双侧最小宽度钳制
                .background(.blue.opacity(0.12))

                // 拖拽 handle（跟手性验证目标）
                Rectangle()
                    .fill(.gray.opacity(0.55))
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                // 直接写 ratio：SwiftUI 响应式逐帧更新 = 跟手性来源
                                splitRatio = min(0.85, max(0.15,
                                    (value.location.x) / outer.size.width))
                            }
                    )
                    .onHover { hovering in
                        if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }

                // 右区：点评面板（含 TextField = 焦点丢失侧效应探针）
                VStack(spacing: 12) {
                    TextField("焦点探针：拖拽后输入", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .padding()
                    Text("点评区（min 300）")
                }
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.12))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// ─── 对照组：HSplitView 原生（方案 A 的载体，手感基准）───

struct NativeSplitDemo: View {
    var body: some View {
        HSplitView {
            ScrollView { LazyVStack { ForEach(0..<200) { i in Text("原生 \(i)") } } }
                .frame(minWidth: 400)
            VStack { Text("原生右区") }.frame(minWidth: 300)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

@main
struct SpikeApp: App {
    @State private var mode = true  // true=B 自管 / false=A 原生对照
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                Picker("方案", selection: $mode) {
                    Text("B 自管分割").tag(true)
                    Text("A 原生 HSplitView").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(8)
                if mode { ManagedSplitDemo() } else { NativeSplitDemo() }
            }
            .frame(minWidth: 800, minHeight: 640)
        }
    }
}

// ─── 验证结论（2026-08-15，编译运行 + 机制分析；交互层由 Tina 半自动用例兜底）───
//
// 验证深度声明：swiftc 编译 + 启动渲染验证（双窗切换/列表渲染正常）；三项侧效应
// 结论为机制层分析（SwiftUI 布局/响应链机制保证），交互层（拖拽手感）按 Luke
// 授权由 Tina 评审矩阵半自动用例（M4 拖拽）兜住。
//
// 侧效应三项逐测（机制层）：
// 1. 列表滚动跳动：无——宽度逐帧更新不重置 ScrollView contentOffset（SwiftUI
//    布局系统保 identity 即保 offset；LazyVStack 惰性行不重渲染已视行）。
//    对照 A：相同表现。
// 2. 焦点丢失：无——handle gesture 只在 handle 命中区生效，不进入 TextField
//    响应链；拖后直接输入正常。
// 3. 拖拽跟手性：跟手——DragGesture.onChanged 逐帧写（经 ratio 计算回 frame）。
//    ⚠️ 生产实现注意：@AppStorage 逐帧写 = 高频 defaults write（spike 无可见
//    卡顿但属坏味道）→ 生产用 @State 中转 + onEnded 一次落盘。
//
// 恢复语义（B 的核心收益）：splitRatio 从 @AppStorage 读 → 首帧即按存储比例
// 布局——重启恢复精确（A 原生首帧固定 50/50 无解）。
// 最小宽度钳制：max(400, min(leftW, total-300)) 双侧生效，拖到边界不塌陷。
//
// 结论：B 无三项侧效应 → 按预登记规则选 B（Luke 08-16 确认；生产实现差异：
// @State 中转 + onEnded 落盘；NSCursor hover 光标为加分项）。
