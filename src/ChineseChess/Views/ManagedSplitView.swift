// ManagedSplitView.swift - macOS 左右分栏容器（v6.2 方案 B：自管分割）
//
// 设计依据：docs/design/macOS-layout-redesign.md v1.2 §三.1
//           docs/spikes/managed-split-minispike.swift（方案 B 定选验证件）
//           Luke 开工令裁定（2026-08-17）：方案 B 定选，禁止回头 HSplitView
//
// 生产要点（spike 结论落地）：
// 1. 拖拽中 @State 中转（SwiftUI 响应式逐帧回 frame = 跟手），onEnded 一次落盘
//    @AppStorage——禁止逐帧写 defaults（spike 已标坏味道）
// 2. 首帧从 @AppStorage 读 = 重启精确恢复（方案 B 相对 HSplitView 的核心收益，
//    HSplitView 公开 API 零分割参数、首帧恒 50/50 无解）
// 3. 双侧最小宽度钳制：左 ≥ leftMin(400)、右 ≥ rightMin(300)，拖到边界不塌陷
// 4. NSCursor.resizeLeftRight hover 光标（spike 加分项转正）
// 5. ⚠️ spike 缺陷修正：DragGesture 默认 coordinateSpace 为 .local（handle 局部
//    坐标），spike 公式 location.x/total 在 handle 偏移后失准——生产版改
//    .named("splitRoot") 命名空间，location 即外层坐标，跟手精确（交互层由
//    Tina M4 半自动用例兜底验证）
//
// 验收锚点：v1.2 §七 Tina P1-1（拖拽持久化：拖拽→关闭→重开→比例保持）

#if os(macOS)
import SwiftUI

/// 命名坐标空间常量（文件作用域：泛型类型内禁止 static 存储属性）
private let managedSplitCoordinateSpace = "managedSplitRoot"

/// macOS 左右分栏容器（方案 B：HStack + 计算宽度 + 自绘 handle + DragGesture）
///
/// 用于演示页面（MasterGameBrowserView / PuzzleDemoView）macOS 左右布局：
/// 左侧棋盘等比区 + 右侧信息面板。分割比例经 `@AppStorage` 持久化，
/// 两页面共用同一 storageKey（v1.2 设计：单一 demoSplitRatio）。
struct ManagedSplitView<LeftContent: View, RightContent: View>: View {

    // MARK: - 常量（spike 同源 + v1.2 §三.1）

    private let handleWidth: CGFloat = 8
    private let leftMin: CGFloat = 400
    private let rightMin: CGFloat = 300
    /// ratio 安全域（spike 同值）
    private let ratioBounds: ClosedRange<Double> = 0.15...0.85

    // MARK: - 状态（双轨：拖拽中 state / 持久化 AppStorage）

    /// 分割比例持久化（左区占比）。默认 0.55（spike 同值）
    @AppStorage private var persistedRatio: Double
    /// 拖拽中的中转比例；nil = 非拖拽态（读持久值）
    @State private var draggingRatio: Double?

    private let left: LeftContent
    private let right: RightContent

    // MARK: - Init

    /// - Parameters:
    ///   - storageKey: 分割比例持久化 key（默认 "demoSplitRatio"，v1.2 设计单 key，
    ///     两演示页面共享比例记忆）
    ///   - left: 左侧内容（棋盘区）
    ///   - right: 右侧内容（信息面板）
    init(
        storageKey: String = "demoSplitRatio",
        @ViewBuilder left: () -> LeftContent,
        @ViewBuilder right: () -> RightContent
    ) {
        self._persistedRatio = AppStorage(wrappedValue: 0.55, storageKey)
        self.left = left()
        self.right = right()
    }

    /// 当前生效比例（拖拽中用中转值，否则持久值）
    private var effectiveRatio: Double {
        draggingRatio ?? persistedRatio
    }

    var body: some View {
        GeometryReader { outer in
            let total = outer.size.width - handleWidth
            if total > 0 {
                let leftWidth = clampedLeftWidth(for: total)
                HStack(spacing: 0) {
                    left
                        .frame(width: leftWidth)

                    dividerHandle(outerWidth: outer.size.width)

                    right
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .coordinateSpace(name: managedSplitCoordinateSpace)
    }

    // MARK: - 分割 handle

    private func dividerHandle(outerWidth: CGFloat) -> some View {
        Rectangle()
            .fill(.gray.opacity(0.55))
            .frame(width: handleWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(
                    minimumDistance: 1,
                    coordinateSpace: .named(managedSplitCoordinateSpace)
                )
                .onChanged { value in
                    // 命名空间内 location.x 即外层坐标 → 直接求 ratio，逐帧写中转 state
                    let raw = Double(value.location.x / outerWidth)
                    draggingRatio = min(ratioBounds.upperBound,
                                        max(ratioBounds.lowerBound, raw))
                }
                .onEnded { _ in
                    // 一次落盘（spike 生产要点 1）：仅拖拽态写，避免非必要 defaults 写
                    if let ratio = draggingRatio {
                        persistedRatio = ratio
                    }
                    draggingRatio = nil
                }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - 宽度钳制

    /// 双侧最小宽度钳制：左 ≥ leftMin 且右 ≥ rightMin（spike 公式）
    private func clampedLeftWidth(for total: CGFloat) -> CGFloat {
        let raw = total * effectiveRatio
        return max(leftMin, min(raw, total - rightMin))
    }
}
#endif
