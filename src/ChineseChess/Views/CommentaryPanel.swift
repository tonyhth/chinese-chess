// CommentaryPanel.swift - macOS 右侧面板点评常驻视图（v6.2）
//
// 设计依据：docs/design/macOS-layout-redesign.md v1.2 §三.1「点评区改造」
// 派生自 CommentaryOverlay（iOS 保持 overlay 不变，I4 回归项）——macOS 从底部
// 弹出气泡改为右侧面板常驻区域，切换走法内容同步更新（Tina P1-3）。
// 空点评占位「暂无点评」（Tina P2-1 顺手补）。
//
// 验收锚点：v1.2 §七 点评常驻 + P1-3 内容同步 + P2-1 空态占位

#if os(macOS)
import SwiftUI

/// macOS 演示页面右侧面板的点评常驻区域
struct CommentaryPanel: View {

    /// 当前步点评；nil = 空态占位（无点评数据 / 演示未开始）
    let commentary: CommentaryItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.shared.t("commentary.title"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let commentary {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: commentary.icon)
                        .font(.callout)
                        .foregroundStyle(.white)

                    Text(commentary.text)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bubbleColor.opacity(0.9))
                )
                .animation(.spring(response: 0.3), value: commentary.id)
            } else {
                Text(L10n.shared.t("commentary.empty"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 类型底色——与 CommentaryOverlay 保持一致的双平台一致性基准
    private var bubbleColor: Color {
        switch commentary?.type {
        case .check: return .orange
        case .checkmate: return .red
        case .sacrifice: return .purple
        case .keyMove: return .blue
        case .mistake: return .red.opacity(0.8)
        case .capture: return .brown
        case .threat: return .indigo
        case .crossing: return .teal
        case nil: return .clear
        }
    }
}
#endif
