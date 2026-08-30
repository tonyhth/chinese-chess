import Foundation

// MARK: - v6.4 C0：辅助信息侧栏自适应状态机（迟滞带防抖）
//
// 依据：v6.4-layout-redesign.md §2 原则二b + Ruby R2 实现约束
// - 输入通道：background GeometryReader + onChange(of: size)（**禁用 onGeometryChange**，部署目标 macOS 14/iOS 17 不达）
// - 迟滞：<1000 收 / >1080 展，带内保持现态（路径依赖）
// - 适用面：仅 P1/P3/P4 辅助信息侧栏（自定义面板）；NavigationSplitView sidebar 不走此机

@Observable
final class AdaptiveRailState {

    /// 侧栏是否展开
    private(set) var isExpanded: Bool

    /// 迟滞阈值（注入可测；默认取 LayoutSpec 单源）
    private let collapseBelow: CGFloat
    private let expandAbove: CGFloat

    /// 最近一次喂入的窗口宽（LAYOUT_DUMP 采样用）
    private(set) var lastWidth: CGFloat = 0

    init(initiallyExpanded: Bool = true,
         collapseBelow: CGFloat = LayoutSpec.railCollapseBelow,
         expandAbove: CGFloat = LayoutSpec.railExpandAbove) {
        self.isExpanded = initiallyExpanded
        self.collapseBelow = collapseBelow
        self.expandAbove = expandAbove
    }

    /// 喂入窗口宽（GeometryReader onChange 调用；幂等）
    func update(width: CGFloat) {
        lastWidth = width
        let next = Self.nextState(isExpanded: isExpanded, width: width,
                                  collapseBelow: collapseBelow, expandAbove: expandAbove)
        if next != isExpanded {
            isExpanded = next
        }
    }

    /// 纯函数核心（可测）：迟滞带内保持现态
    /// - <collapseBelow → 收
    /// - >expandAbove → 展开张开
    /// - 带内 → 不变（路径依赖：单序列断言恒假的根源，双向各锁方向）
    static func nextState(isExpanded: Bool, width: CGFloat,
                          collapseBelow: CGFloat, expandAbove: CGFloat) -> Bool {
        if width < collapseBelow { return false }
        if width > expandAbove { return true }
        return isExpanded
    }
}
