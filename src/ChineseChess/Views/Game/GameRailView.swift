import SwiftUI

// MARK: - v6.4 C1：对局页右通栏（走法记录 + 可折叠面板体系）
//
// 依据：v6.4-layout-redesign.md §3.1-3（大屏三栏）+ prototypes/v6.4-p1-final.html .rail/.panel
// 定宽 264（LayoutSpec.p1RailWidth），细滚动条，面板头行可点击折叠（chevron 旋转）。
// 打样边界声明：
// - 走法记录为实时只读 + 自动跟焦（live 对局回跳属复盘域，复盘页已有；防 P1 打样越界）
// - 分析面板：引擎状态走既有展示位（EngineConfigStore，不绕 EngineRouter 直取引擎）；
//   形势条/曲线骨架位随 v6.4 ①持久化上线（届时 P9 独立窗口 Phase 4 一并接）

struct GameRailView: View {
    let viewModel: GameViewModel
    var onReplayRequest: (() -> Void)? = nil

    private let l10n = L10n.shared

    // 面板折叠态（默认全展，走法记录占主）
    @State private var infoCollapsed = false
    @State private var movesCollapsed = false
    @State private var analysisCollapsed = false

    var body: some View {
        VStack(spacing: LayoutSpec.space2) {
            // 对局信息
            RailPanel(title: l10n.t("p1.rail.info"), collapsed: $infoCollapsed) {
                VStack(spacing: 2) {
                    railStat(l10n.t("p1.rail.round"),
                             "\(max(1, viewModel.moveHistory.count / 2 + 1))")
                    railStat(l10n.t("clock.red"),
                             formatTime(viewModel.redClockSeconds + runningExtra(.red)))
                    railStat(l10n.t("clock.black"),
                             formatTime(viewModel.blackClockSeconds + runningExtra(.black)))
                    railStat(l10n.t("p1.rail.timeBehind"),
                             timeBehindText,
                             valueColor: timeBehindColor)

                    // 被吃子摘要（原 StatusBarView 两列收为两行）
                    capturedRow(label: l10n.t("status.redLostFull"), pieces: viewModel.capturedPieces.red, color: .red)
                    capturedRow(label: l10n.t("status.blackLostFull"), pieces: viewModel.capturedPieces.black, color: .white)
                }
            }

            // 走法记录（主面板，flex）
            RailPanel(title: l10n.t("p1.rail.moves"), collapsed: $movesCollapsed, grow: true) {
                MoveRecordList(viewModel: viewModel)
            }

            // 分析（引擎状态 + 复盘入口；形势条随①持久化上线）
            RailPanel(title: l10n.t("p1.rail.analysis"), collapsed: $analysisCollapsed) {
                VStack(spacing: LayoutSpec.space2) {
                    #if os(macOS)
                    railStat(l10n.t("p1.rail.engine"),
                             EngineConfigStore.shared.useEmbeddedEngine ? "Pikafish" : l10n.t("engine.builtIn"))
                    #endif

                    Button {
                        onReplayRequest?()
                    } label: {
                        Label(l10n.t("toolbar.replay"), systemImage: "arrow.uturn.forward.circle")
                            .font(.system(size: LayoutSpec.fontSizeBody))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.brown)
                    .disabled(viewModel.gameMoves.isEmpty)

                    Text(l10n.t("p1.rail.analysisPlaceholder"))
                        .font(.system(size: LayoutSpec.fontSizeCaption))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, LayoutSpec.space2)
        .frame(width: LayoutSpec.p1RailWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 行组件

    private func railStat(_ label: String, _ value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundColor(valueColor ?? .primary)
        }
    }

    private func capturedRow(label: String, pieces: [Piece], color: Color) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundColor(.secondary)
            Spacer()
            Text(pieces.isEmpty ? l10n.t("common.none")
                 : pieces.map(\.displayName).joined(separator: " "))
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundColor(pieces.isEmpty ? .secondary : color)
                .lineLimit(1)
                .truncationMode(.tail)   // LJ-1 截断规范
                .help(pieces.map(\.displayName).joined(separator: " "))
        }
    }

    // MARK: - 时钟辅助

    private func runningExtra(_ side: Side) -> Int {
        guard viewModel.gameState == .playing, viewModel.clockRunningSide == side,
              let start = viewModel.clockStartTime else { return 0 }
        return Int(Date().timeIntervalSince(start))
    }

    private var timeBehindText: String {
        let red = viewModel.redClockSeconds + runningExtra(.red)
        let black = viewModel.blackClockSeconds + runningExtra(.black)
        let diff = red - black   // 正 = 红方领先
        let sign = diff >= 0 ? "+" : "−"
        let absDiff = abs(diff)
        return "\(sign)\(absDiff / 60):\(String(format: "%02d", absDiff % 60))"
    }

    private var timeBehindColor: Color {
        (viewModel.redClockSeconds - viewModel.blackClockSeconds) >= 0 ? .green : .red
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - 面板容器（头行可折叠）

private struct RailPanel<Content: View>: View {
    let title: String
    @Binding var collapsed: Bool
    var grow: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            // 头行：竖条 tab + 标题 + chevron
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { collapsed.toggle() }
            } label: {
                HStack(spacing: LayoutSpec.space2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.brown)
                        .frame(width: 3, height: 14)
                    Text(title)
                        .font(.system(size: LayoutSpec.fontSizeBody, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(collapsed ? -90 : 0))
                }
                .padding(.horizontal, LayoutSpec.space3)
                .frame(height: LayoutSpec.panelHeaderHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !collapsed {
                Divider().opacity(0.5)
                content
                    .padding(.horizontal, LayoutSpec.space3)
                    .padding(.vertical, LayoutSpec.space2)
            }
        }
        .background(Color(red: 50/255, green: 30/255, blue: 20/255).opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius))
        .frame(maxHeight: grow ? .infinity : nil, alignment: .top)
    }
}

// MARK: - 走法记录列表（双列行式 + 当前局末行 + 自动跟焦）

private struct MoveRecordList: View {
    let viewModel: GameViewModel
    private let l10n = L10n.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 1) {
                    let rounds = Dictionary(grouping: viewModel.gameMoves, by: \.turnNumber)
                    let sortedRounds = rounds.keys.sorted()

                    ForEach(sortedRounds, id: \.self) { roundNo in
                        let moves = rounds[roundNo] ?? []
                        let redNotation = moves.first(where: { $0.piece.side == .red })?.notation ?? ""
                        let blackNotation = moves.first(where: { $0.piece.side == .black })?.notation ?? ""
                        HStack(spacing: 4) {
                            Text("\(roundNo).")
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                            Text(redNotation)
                                .font(.system(size: 12.5, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(blackNotation)
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .id(roundNo)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(roundNo == (viewModel.gameMoves.last?.turnNumber ?? 0)
                                      ? Color.gold.opacity(0.35) : Color.clear)
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .onChange(of: viewModel.gameMoves.count) { _, _ in
                if let last = viewModel.gameMoves.last {
                    withAnimation { proxy.scrollTo(last.turnNumber, anchor: .bottom) }
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.gameMoves.count > 12 {
                    Button {
                        if let last = viewModel.gameMoves.last {
                            withAnimation { proxy.scrollTo(last.turnNumber, anchor: .bottom) }
                        }
                    } label: {
                        Label(l10n.t("p1.rail.backToLatest"), systemImage: "arrow.uturn.backward")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                    .controlSize(.small)
                    .clipShape(Capsule())
                    .padding(.bottom, LayoutSpec.space1)
                }
            }
        }
    }
}

// Color.gold 若无定义则回落（防编译错）
private extension Color {
    static var gold: Color { Color(red: 201/255, green: 162/255, blue: 39/255) }
}
