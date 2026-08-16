// DemoSidePanel.swift - macOS 右侧面板容器（v6.2）
//
// 设计依据：docs/design/macOS-layout-redesign.md v1.2 §三.1 右侧面板结构
//   DemoInfoBar（头部插槽）→ 点评常驻 → 走法记录 → DemoControlBar（底部插槽）
//
// 插槽设计：头部/底部以 ViewBuilder 闭包注入（InfoBar/ControlBar 需要
// DemoViewModel 与 onBackToList，由接入方在批次③④传入，容器不耦合 vm）。
// 宽度约束：minWidth 300（与 ManagedSplitView.rightMin 一致）/
// idealWidth 340（v1.1 修正：DemoControlBar 不溢出）/ maxWidth 500。
//
// 验收锚点：T5 右侧面板容器存在 + DemoControlBar 面板内正常工作（v1.2 §七）

#if os(macOS)
import SwiftUI

/// macOS 演示页面右侧面板容器
struct DemoSidePanel<Header: View, Footer: View>: View {

    @ViewBuilder private let header: () -> Header
    @ViewBuilder private let footer: () -> Footer

    /// 当前步点评（nil = 空态占位），透传 CommentaryPanel（Tina P1-3 同步）
    private let commentary: CommentaryItem?

    /// 走法记谱 + 当前步索引，透传 MoveRecordPanel（Tina P1-2 交互）
    private let notations: [String]
    private let currentIndex: Int

    /// 点击走法行回调（0-based 行索引），透传 MoveRecordPanel
    private let onMoveTap: (Int) -> Void

    init(
        commentary: CommentaryItem?,
        notations: [String],
        currentIndex: Int,
        onMoveTap: @escaping (Int) -> Void,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.commentary = commentary
        self.notations = notations
        self.currentIndex = currentIndex
        self.onMoveTap = onMoveTap
        self.header = header
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            header()

            Divider()

            CommentaryPanel(commentary: commentary)

            Divider()

            MoveRecordPanel(
                notations: notations,
                currentIndex: currentIndex,
                onMoveTap: onMoveTap
            )

            Divider()

            footer()
        }
        // v1.2 §三.1：面板宽度约束（min 300 / ideal 340 / max 500）
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 500)
    }
}
#endif
