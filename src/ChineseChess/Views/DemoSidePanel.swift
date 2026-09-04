// DemoSidePanel.swift - macOS 右侧面板容器（v6.2 → v6.4 C2 三 tab 化）
//
// v6.4 C2 改造（依据 v6.4-pages-all14.html P3/P4 + layout-redesign §3.2）：
//   - 原「点评/走法常驻竖排」→ 三 tab（信息/点评/走法）：信息密度重排，
//     点评区滚动高度自适应（max 220），走法双列改面板内独占可滚
//   - 头部信息卡压缩为一条（原 DemoInfoBar 塞 header 插槽）；进度并入走法 tab 底部
//   - 面板宽度：v6.2 的 400（VTF 死区口径）→ C2 统一 300（all14 原型 P4 定宽 300；
//     独立面板非 ManagedSplitView 侧栏，VTF 死区不适用）
//   - 窄窗口径（narrow 全局）：P3/P4 同 P1，<1000 收右栏（C0 迟滞状态机，由接入方喂）
//
// 插槽设计（v6.2 保留）：header/footer ViewBuilder 注入，容器不耦合 vm。

#if os(macOS)
import SwiftUI

/// macOS 演示/播放页右侧面板容器（三 tab）
struct DemoSidePanel<Header: View, Footer: View>: View {

    @ViewBuilder private let header: () -> Header
    @ViewBuilder private let footer: () -> Footer

    /// 当前步点评（nil = 空态占位）
    private let commentary: CommentaryItem?

    /// 走法记谱 + 当前步索引 + 点击回调
    private let notations: [String]
    private let currentIndex: Int
    private let onMoveTap: (Int) -> Void

    /// 播放进度（0...total），走法 tab 底部条
    private let progress: Double    // 0...1
    private let progressText: String

    @State private var selectedTab: SideTab = .info

    enum SideTab: String, CaseIterable, Identifiable {
        case info, commentary, moves
        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .info: return "p34.tab.info"
            case .commentary: return "p34.tab.commentary"
            case .moves: return "p34.tab.moves"
            }
        }
    }

    init(
        commentary: CommentaryItem?,
        notations: [String],
        currentIndex: Int,
        onMoveTap: @escaping (Int) -> Void,
        progress: Double,
        progressText: String,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.commentary = commentary
        self.notations = notations
        self.currentIndex = currentIndex
        self.onMoveTap = onMoveTap
        self.progress = min(max(progress, 0), 1)
        self.progressText = progressText
        self.header = header
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            header()

            // 三 tab 头（v6.4 C2：all14 原型 .tabs 口径）
            HStack(spacing: 0) {
                ForEach(SideTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Divider().padding(.top, 4)

            // tab 内容（面板高度自持：点评滚动自适应、走法独占滚动）
            ZStack {
                switch selectedTab {
                case .info:
                    InfoTabContent(commentaryHint: commentary != nil)
                case .commentary:
                    CommentaryPanel(commentary: commentary)
                        .frame(maxHeight: 220, alignment: .top)
                case .moves:
                    VStack(spacing: 0) {
                        MoveRecordPanel(
                            notations: notations,
                            currentIndex: currentIndex,
                            onMoveTap: onMoveTap
                        )
                        // 进度条（原控制条内进度移入走法 tab 底部，all14 P4 口径）
                        VStack(spacing: 4) {
                            Divider()
                            HStack(spacing: 8) {
                                ProgressView(value: progress)
                                    .frame(maxWidth: .infinity)
                                Text(progressText)
                                    .font(.system(size: LayoutSpec.fontSizeCaption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            footer()
        }
        // v6.4 C2：定宽 300（all14 P4；独立面板，非 ManagedSplitView 侧栏）
        .frame(width: LayoutSpec.p34RailWidth)
    }

    // MARK: - tab 按钮

    private func tabButton(_ tab: SideTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(L10n.shared.t(tab.titleKey))
                .font(.system(size: LayoutSpec.fontSizeBody,
                              weight: selectedTab == tab ? .semibold : .regular))
                .foregroundColor(selectedTab == tab ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 信息 tab（all14 P3：对局/赛事/开局/当前 四行）

private struct InfoTabContent: View {
    let commentaryHint: Bool
    private let l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 提示：点评有内容时引（信息 tab 不做重复数据；诚实占位）
            if commentaryHint {
                Text(l10n.t("p34.tab.commentaryHint"))
                    .font(.system(size: LayoutSpec.fontSizeCaption))
                    .foregroundStyle(.secondary)
            }
            Text(l10n.t("p34.tab.infoHint"))
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
