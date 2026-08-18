// MoveRecordPanel.swift - macOS 专用走法记录面板（v6.2）
//
// 设计依据：docs/design/macOS-layout-redesign.md v1.2 §三.1「走法记录」
//   - macOS 独立实现，不重构 iOS 版 iosRecordPanel（T10：iOS 路径不动）
//   - 高亮当前走法 + 点击跳转到该局面（Tina P1-2 新增交互，非仅"有面板"）
//
// 索引语义（与 BoardPlayer 对齐）：
//   currentIndex = 已执行步数（0 = 初始局面，1 = 已走第 1 步）
//   高亮行 = currentIndex - 1；点击第 idx 行 → onMoveTap(idx) → 调用方
//   跳转到 index = idx + 1（BoardPlayer.jumpTo(index:)）
//
// 验收锚点：v1.2 §七 P1-2 走法记录交互

#if os(macOS)
import SwiftUI

/// macOS 演示页面右侧面板的走法记录列表
struct MoveRecordPanel: View {

    /// 记谱列表（DemoViewModel.moveNotations，中文纵线格式）
    let notations: [String]

    /// 当前已执行步数（0 = 初始局面）；高亮行 = currentIndex - 1
    let currentIndex: Int

    /// 点击某行走法 → 跳转该局面（传入 0-based 行索引）
    let onMoveTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.shared.t("moveRecord.title"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(notations.enumerated()), id: \.offset) { idx, notation in
                        moveRow(index: idx, notation: notation)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// 单行走法：序号 + 记谱；当前步高亮背景，其余行 hover 反馈 + 可点击
    private func moveRow(index: Int, notation: String) -> some View {
        let isCurrent = (index == currentIndex - 1)

        return Button {
            onMoveTap(index)
        } label: {
            HStack(spacing: 8) {
                Text("\(index / 2 + 1).")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)

                Text(notation)
                    .font(.caption)
                    .foregroundStyle(isCurrent ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isCurrent ? Color.accentColor.opacity(0.22) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
