import SwiftUI

// MARK: - v6.4 C1：对局页右通栏（走法记录 + 可折叠面板体系）
//
// 依据：v6.4-layout-redesign.md §3.1-3（大屏三栏）+ prototypes/v6.4-p1-final.html .rail/.panel
// 定宽 264（LayoutSpec.p1RailWidth），细滚动条，面板头行可点击折叠（chevron 旋转）。
// 打样边界声明：
// - 走法记录为实时只读 + 自动跟焦（live 对局回跳属复盘域，复盘页已有；防 P1 打样越界）
// - 引擎状态面板：按难度路由展示（E5 语义：业余→自研 / 专业→Pikafish，无用户开关）；
//   形势条/曲线骨架位随 v6.4 ①持久化上线（届时 P9 独立窗口 Phase 4 一并接）

struct GameRailView: View {
    let viewModel: GameViewModel
    var onReplayRequest: (() -> Void)? = nil

    private let l10n = L10n.shared

    // 面板折叠态（默认全展，走法记录占主）
    @State private var infoCollapsed = false
    @State private var movesCollapsed = false
    @State private var analysisCollapsed = false
    @State private var engineCollapsed = false

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

            // 分析（复盘入口；形势条随①持久化上线）
            RailPanel(title: l10n.t("p1.rail.analysis"), collapsed: $analysisCollapsed) {
                VStack(spacing: LayoutSpec.space2) {
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

            // 引擎状态（第四面板：真实状态行，Ruby P1/P2 清偿——去伪状态）
            RailPanel(title: l10n.t("p1.rail.engine"), collapsed: $engineCollapsed) {
                VStack(spacing: 2) {
                    #if os(macOS)
                    // 引擎路由行：按难度实时真值，业余=自研恒可用，专业=Pikafish 可用性
                    // 跟随难度变化重校验（Ruby P1 补：会话内可变输入需 .task(id:) 反应，
                    // 与 NNUE 资产静态校验不同；mount 时一次性 .task 会令 amateur↔pro 切换时
                    // 灯与文案滞留在旧态，红点语义失真）。
                    statusRow(ok: engineCheck.ok, label: l10n.t("p1.rail.engine"),
                              value: engineCheck.text(pro: viewModel.difficulty.isProfessional))
                    // NNUE：接真实校验（EmbeddedPikafishEngine.verifyNNUEAsset，sha256 快路径缓存）
                    // 异步查（首次全量哈希 ~0.3-1s 不卡 UI），结果落地前中性"校验中…"灰点，不假绿
                    statusRow(ok: nnueCheck.ok, label: "NNUE",
                              value: nnueCheck.text)
                    #endif
                }
            }
        }
        .padding(.vertical, LayoutSpec.space2)
        .frame(width: LayoutSpec.p1RailWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        // Ruby P1：难度是会话内可变输入（newGame 段位推荐 / setDifficulty / DailyChallengeView 直改），
        // 用 .task(id:) 在 mount 与难度变化时都重校验；非 .task 单次挂载。
        // EngineCheckState 永不回退到 pending（refreshEngineCheck 不重置），保持已有 ok/degraded 终态显示。
        .task(id: viewModel.difficulty) {
            await refreshEngineCheck()
            await refreshNNUECheck()
        }
    }

    // MARK: - 引擎路由真实状态（Ruby P1 补：随难度刷新）

    private enum EngineCheckState {
        case pending
        case ok        // 路由目标就绪（业余=自研 / 专业=Pikafish）
        case degraded  // 专业级 Pikafish 未就绪，降级自研

        var ok: Bool? {
            switch self { case .pending: nil; case .ok: true; case .degraded: false }
        }

        func text(pro: Bool) -> String {
            switch self {
            case .pending: L10n.shared.t("p1.rail.nnueChecking")  // 复用"校验中…"中性文案
            case .ok: pro ? L10n.shared.t("p1.rail.enginePikafish")
                          : L10n.shared.t("engine.builtIn")
            case .degraded: L10n.shared.t("engine.builtIn")
            }
        }
    }

    @State private var engineCheck: EngineCheckState = .pending

    private func refreshEngineCheck() async {
        // 三态不回退：不重置 pending（已有 ok/degraded 终态保持显示，
        // 仅在新一次校验完成时覆写），因此 onAppear 与难度切换都不会闪灰。
        switch await EngineRouter.shared.validateEngineAvailability(for: viewModel.difficulty) {
        case .available: engineCheck = .ok
        case .unavailable: engineCheck = .degraded
        }
    }

    // MARK: - NNUE 真实校验状态（Ruby P1：伪状态面板清偿）

    private enum NNUECheckState {
        case pending
        case ok
        case failed

        var ok: Bool? {
            switch self { case .pending: nil; case .ok: true; case .failed: false }
        }

        var text: String {
            switch self {
            case .pending: L10n.shared.t("p1.rail.nnueChecking")
            case .ok: L10n.shared.t("p1.rail.nnueLoaded")
            case .failed: L10n.shared.t("p1.rail.nnueMissing")
            }
        }
    }

    @State private var nnueCheck: NNUECheckState = .pending

    private func refreshNNUECheck() async {
        let r = await Task.detached(priority: .utility) {
            EmbeddedPikafishEngine.verifyNNUEAsset()
        }.value
        if case .ok = r { nnueCheck = .ok } else { nnueCheck = .failed }
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

    // MARK: - 状态行（绿点语义色，refine#6）

    private func statusRow(ok: Bool?, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            // ok 消费真实状态：nil=待定灰 / true=绿 / false=红（Ruby P1：死参数清偿）
            Circle()
                .fill(ok == true ? Color.green : ok == false ? Color.red : Color.gray)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: LayoutSpec.fontSizeCaption))
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
