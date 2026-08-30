import SwiftUI

// MARK: - v3.6.0 Phase 2: 复盘分析视图

struct AnalysisView: View {
    @State private var analysisVM = AnalysisViewModel()
    @State private var replayVM: ReplayViewModel
    @Environment(\.dismiss) private var dismiss

    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile

    // 段位门禁（FINAL-001: 改用 analysisEntry，语义匹配复盘分析）
    // v5.5.9: 改为走 isFeatureUnlocked，使 DeveloperMode 绕过生效
    private var hasBasicAnalysis: Bool {
        profile.isFeatureUnlocked(.analysisEntry)
    }
    private var hasExpertAnalysis: Bool {
        profile.isFeatureUnlocked(.engineAnalysis)
    }
    // v3.7.0 Phase 2: 导出门禁
    private var canExport: Bool {
        profile.isFeatureUnlocked(.gameRecordExport)
    }

    init(record: GameRecord) {
        self._replayVM = State(initialValue: ReplayViewModel(record: record))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if !hasBasicAnalysis {
                lockedView
            } else {
                ReplayBoardView(viewModel: replayVM)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)

                analysisControls

                moveQualityList

                if hasExpertAnalysis {
                    evalChart
                }
            }
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
        .task {
            if hasBasicAnalysis {
                await startAnalysis()
            }
        }
    }

    // MARK: - 标题栏

    private var headerBar: some View {
        ZStack {
            Text(l10n.t("analysis.title"))
                .font(.callout.weight(.bold))
                .foregroundColor(.white)

            HStack {
                Button(l10n.t("common.close")) { dismiss() }
                    .foregroundColor(.white)
                Spacer()

                // v3.7.0 Phase 2: 分享按钮
                shareMenu
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(red: 50/255, green: 30/255, blue: 20/255))
    }

    // MARK: - 分享菜单

    private var shareMenu: some View {
        Menu {
            if canExport {
                Button {
                    copyPGNToClipboard()
                } label: {
                    Label(l10n.t("export.copyPGN"), systemImage: "doc.on.doc")
                }

                ShareLink(
                    item: PGNExporter.export(replayVM.record),
                    preview: SharePreview(
                        "\(replayVM.record.title).pgn",
                        image: Image(systemName: "doc.text")
                    )
                ) {
                    Label(l10n.t("export.share"), systemImage: "square.and.arrow.up")
                }
            } else {
                Label(String(format: l10n.t("export.locked"), l10n.t("rank.hanlin")), systemImage: "lock")
            }
        } label: {
            Image(systemName: canExport ? "square.and.arrow.up" : "lock")
                .foregroundColor(.white)
        }
    }

    // MARK: - 锁定视图

    private var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(String(format: l10n.t("analysis.unlock.rank"), l10n.t("rank.scholar")))
                .foregroundColor(.gray)
                .font(.body)

            Button(l10n.t("common.close")) { dismiss() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 分析控制

    private var analysisControls: some View {
        HStack(spacing: 12) {
            if analysisVM.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(analysisVM.analysisProgress.done)/\(analysisVM.analysisProgress.total)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(l10n.t("analysis.analyzingPlayerMoves"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if let msg = analysisVM.analysisUnavailableMessage {
                // v5.5.1 fix 问题5: 更醒目的提示 + 重试按钮
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.callout)
                        .foregroundColor(.orange)
                    Button(l10n.t("common.retry")) {
                        Task { await startAnalysis() }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text(l10n.t("analysis.completed"))
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()

            Button { replayVM.goToStart() } label: {
                Image(systemName: "backward.end.fill")
            }
            Button { replayVM.goBack() } label: {
                Image(systemName: "chevron.left")
            }
            Button { replayVM.goForward() } label: {
                Image(systemName: "chevron.right")
            }
            Button { replayVM.goToEnd() } label: {
                Image(systemName: "forward.end.fill")
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - 走法质量列表

    private var moveQualityList: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 4) {
                    ForEach(Array(analysisVM.analyses.enumerated()), id: \.offset) { index, analysis in
                        moveQualityBadge(index: index, analysis: analysis)
                            .id(index)
                            .onTapGesture {
                                replayVM.jumpTo(index: index + 1)
                                proxy.scrollTo(index, anchor: .center)
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .frame(height: 56)
            .background(Color(red: 38/255, green: 20/255, blue: 14/255))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func moveQualityBadge(index: Int, analysis: MoveAnalysis?) -> some View {
        VStack(spacing: 2) {
            Text("\(index + 1)")
                .font(.system(size: 9))
                .foregroundColor(.gray)

            if let a = analysis {
                Image(systemName: a.quality.symbolName)
                    .font(.system(size: 14))
                    .foregroundColor(qualityColor(a.quality))
            } else if !analysisVM.isPlayerMove(at: index) {
                // v4.0 Phase 3 #8: AI 走法步显示灰色 AI 标签
                Text(l10n.t("analysis.aiMove"))
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.6))
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 14, height: 14)
            }
        }
        .frame(width: 32, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    replayVM.currentIndex == index + 1
                    ? Color.white.opacity(0.15)
                    : Color.clear
                )
        )
    }

    private func qualityColor(_ quality: MoveQuality) -> Color {
        switch quality {
        case .brilliant: return .green
        case .good:      return .blue
        case .normal:    return .gray
        case .doubtful:  return .yellow
        case .blunder:   return .orange
        case .losing:    return .red
        }
    }

    // MARK: - 评估曲线

    private var evalChart: some View {
        let sequence = analysisVM.evalSequence
        let height: CGFloat = 80

        return VStack(alignment: .leading, spacing: 4) {
            Text(l10n.t("analysis.evalChart"))
                .font(.caption)
                .foregroundColor(.gray)

            if sequence.isEmpty {
                if let msg = analysisVM.analysisUnavailableMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(height: height)
                } else if !analysisVM.isAnalyzing {
                    // FINAL-001: 分析完成但无数据，不显示"分析中"
                    Text(l10n.t("analysis.noData"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: height)
                } else {
                    Text(l10n.t("analysis.analyzing"))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(height: height)
                }
            } else {
                GeometryReader { geo in
                    // v6.3.2 热修：mate 分数（|s|≥90000）不参与 y 量程，绘制时钉到量程边界（数据点保留原值）。
                    // 根因：真局将死终局 playerEval=-99999 直接进量程 → range≈10 万，正常分压成贴顶直线（视觉"归零"）。
                    let domain = EvalChartScale.yDomain(sequence.map { $0.score })
                    let minScore = domain.min
                    let maxScore = domain.max
                    let range = max(maxScore - minScore, 1)

                    ZStack {
                        // 零线
                        let zeroY = height * CGFloat(maxScore) / CGFloat(range)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: zeroY))
                            path.addLine(to: CGPoint(x: geo.size.width, y: zeroY))
                        }
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)

                        // 评估曲线
                        Path { path in
                            let totalSteps = sequence.last?.index ?? sequence.count
                            let stepWidth = totalSteps > 0
                                ? geo.size.width / CGFloat(totalSteps)
                                : geo.size.width

                            for (i, item) in sequence.enumerated() {
                                let x = CGFloat(item.index) * stepWidth
                                let drawScore = EvalChartScale.isMateScore(item.score)
                                    ? EvalChartScale.pinnedScore(item.score, domain: domain)
                                    : item.score
                                let normalized = CGFloat(maxScore - drawScore) / CGFloat(range)
                                let y = normalized * height

                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color(red: 200/255, green: 160/255, blue: 100/255), lineWidth: 1.5)

                        // v6.3.2 热修：mate 点视觉标记（钉边的红色小三角，不引入新依赖）
                        ForEach(sequence.filter { EvalChartScale.isMateScore($0.score) }, id: \.index) { item in
                            let totalSteps = sequence.last?.index ?? sequence.count
                            let stepWidth = totalSteps > 0
                                ? geo.size.width / CGFloat(totalSteps)
                                : 0
                            let x = CGFloat(item.index) * stepWidth
                            let pinned = EvalChartScale.pinnedScore(item.score, domain: domain)
                            let y = height * CGFloat(maxScore - pinned) / CGFloat(range)
                            MateFlagMarker()
                                .position(x: x, y: y)
                                .allowsHitTesting(false)
                        }

                        // 当前位置标记
                        if let matched = sequence.first(where: { $0.index == replayVM.currentIndex - 1 }) {
                            let totalSteps = sequence.last?.index ?? sequence.count
                            let stepWidth = totalSteps > 0
                                ? geo.size.width / CGFloat(totalSteps)
                                : 0
                            let x = CGFloat(matched.index) * stepWidth
                            let drawScore = EvalChartScale.isMateScore(matched.score)
                                ? EvalChartScale.pinnedScore(matched.score, domain: domain)
                                : matched.score
                            let y = height * CGFloat(maxScore - drawScore) / CGFloat(range)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: height)
                .background(Color(red: 30/255, green: 16/255, blue: 10/255))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - 分析启动

    private func startAnalysis() async {
        let gameMoves = replayVM.record.moves
        let moves = gameMoves.uciMoves

        let fen = replayVM.record.initialFEN ?? FENParser.standardInitial
        // v3.7.0 Phase 2: 传入 gameMoves 用于 FEN 精确推算
        analysisVM.load(moves: moves, initialFEN: fen, gameMoves: gameMoves)
        await analysisVM.analyzeAll()
    }

    // MARK: - 导出操作

    private func copyPGNToClipboard() {
        let pgn = PGNExporter.export(replayVM.record)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pgn, forType: .string)
        #else
        UIPasteboard.general.string = pgn
        #endif
    }
}

// MARK: - v6.3.2 评估曲线量程（mate 分数特判）

/// 评估曲线 y 轴量程计算——mate 分数不参与量程，绘制时钉到边界。
/// 根因（2026-08-30 真局复现，evidence/probe-truegame-0830/）：
/// 将死终局 playerEval=-99999 直接进 min/max → range≈10 万，
/// 正常分（23~736cp）被压成贴顶 0~0.6px 直线（视觉"归零"+右侧残迹）。
/// mate 值本身是语义数据（losing 定级等消费方需真值），故只在绘制层处理。
enum EvalChartScale {
    /// Pikafish mate 分数特征阈值（|s| ≥ 90000 视为 mate）
    static let mateThreshold = 90_000
    /// 非 mate 分参与量程的 clamp 边界（±2000cp，超出按边界计）
    static let clampBound = 2_000

    static func isMateScore(_ score: Int) -> Bool {
        abs(score) >= mateThreshold
    }

    /// y 量程：mate 点剔除、非 mate 分 clamp 后与 ±200 保底合并（与旧口径兼容）
    static func yDomain(_ scores: [Int]) -> (min: Int, max: Int) {
        let bounded = scores
            .filter { !isMateScore($0) }
            .map { min(max($0, -clampBound), clampBound) }
        let lo = bounded.min() ?? 0
        let hi = bounded.max() ?? 0
        return (min(lo, -200), max(hi, 200))
    }

    /// mate 点绘制值：钉到量程边界（正 mate=图顶，负 mate=图底）
    static func pinnedScore(_ score: Int, domain: (min: Int, max: Int)) -> Int {
        score > 0 ? domain.max : domain.min
    }
}

/// mate 点视觉标记：钉边位置的红色小三角（指向盘外=对局终结），最简实现
private struct MateFlagMarker: View {
    var body: some View {
        Triangle()
            .fill(Color.red.opacity(0.85))
            .frame(width: 7, height: 7)
    }
}

/// 等腰小三角（朝下：负 mate 钉底时指向曲线终点；朝上翻转由调用方 rotation 处理，此处固定朝下）
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
