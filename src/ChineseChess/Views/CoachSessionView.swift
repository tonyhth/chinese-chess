import SwiftUI

// MARK: - v3.7.2 Phase 4: AI 教练会话视图

/// AI 教练会话容器
///
/// 接收 GameRecord，执行全局分析，逐步展示教练讲解。
/// 段位门禁：国手（master）以上可用。
struct CoachSessionView: View {
    let record: GameRecord

    @State private var replayVM: ReplayViewModel
    @State private var analysisVM = AnalysisViewModel()
    @State private var reviewCard: GameReviewCard?
    @State private var currentExplanation: CoachExplanation?
    @State private var isAnalyzing = false
    @State private var analyzedSteps = 0
    @State private var totalSteps = 0
    @Environment(\.dismiss) private var dismiss

    private let coach = CoachExplainer.shared
    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile

    private var hasCoachAccess: Bool {
        profile.isFeatureUnlocked(.aiCoach)
    }

    init(record: GameRecord) {
        self.record = record
        self._replayVM = State(initialValue: ReplayViewModel(record: record))
    }

    var body: some View {
        if !hasCoachAccess {
            lockedView
        } else {
            coachContent
        }
    }

    // MARK: - 门禁视图

    private var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(String(format: l10n.t("coach.unlock.rank"), l10n.t("rank.master")))
                .font(.headline)
                .foregroundColor(.secondary)

            Button(l10n.t("common.close")) { dismiss() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 教练内容

    private var coachContent: some View {
        VStack(spacing: 0) {
            // 复盘统计卡片
            if let card = reviewCard {
                reviewCardSummary(card)
            } else if isAnalyzing {
                analysisProgressBar
            }

            // 棋盘回放
            ReplayBoardView(viewModel: replayVM)
                .layoutPriority(1)

            // 导航控制
            replayControls

            // 教练提示卡片（当前步）
            if let explanation = currentExplanation {
                CoachModeOverlay(
                    explanation: explanation,
                    onDismiss: { nextStep() },
                    onShowDetail: { /* Step 6 可扩展：跳转详细分析 */ }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .task { await analyzeGame() }
    }

    // MARK: - 复盘统计

    private func reviewCardSummary(_ card: GameReviewCard) -> some View {
        HStack(spacing: 16) {
            // 星级
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < card.rating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }

            Divider()
                .frame(height: 24)

            // 质量分布
            HStack(spacing: 8) {
                qualityBadge(.brilliant, count: card.qualityDistribution[.brilliant] ?? 0)
                qualityBadge(.good, count: card.qualityDistribution[.good] ?? 0)
                qualityBadge(.doubtful, count: card.qualityDistribution[.doubtful] ?? 0)
                qualityBadge(.blunder, count: card.qualityDistribution[.blunder] ?? 0)
            }

            Spacer()

            Text(card.suggestion)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.controlBackground)
    }

    private func qualityBadge(_ quality: MoveQuality, count: Int) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(qualityColor(quality))
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func qualityColor(_ quality: MoveQuality) -> Color {
        switch quality {
        case .brilliant: return .green
        case .good: return .blue
        case .normal: return .gray
        case .doubtful: return .yellow
        case .blunder: return .orange
        case .losing: return .red
        }
    }

    // MARK: - 分析进度

    private var analysisProgressBar: some View {
        VStack(spacing: 4) {
            Text(l10n.t("coach.analyzing"))
                .font(.caption)
                .foregroundColor(.secondary)
            ProgressView(value: Double(analyzedSteps), total: Double(max(totalSteps, 1)))
                .tint(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 回放控制

    private var replayControls: some View {
        HStack(spacing: 16) {
            Button { replayVM.goToStart() } label: {
                Image(systemName: "backward.end.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!replayVM.canGoBack)

            Button { replayVM.goBack() } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(!replayVM.canGoBack)

            Text("\(replayVM.currentIndex)/\(record.moves.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 50)

            Button { replayVM.goForward() } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .disabled(!replayVM.canGoForward)

            Button { replayVM.goToEnd() } label: {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!replayVM.canGoForward)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 分析逻辑

    private func analyzeGame() async {
        guard !record.moves.isEmpty else { return }

        isAnalyzing = true
        totalSteps = record.moves.count

        let gameMoves = record.moves
        let uciMoves = gameMoves.uciMoves

        let fen = record.initialFEN ?? FENParser.standardInitial
        analysisVM.load(moves: uciMoves, initialFEN: fen, gameMoves: gameMoves)

        // 逐步分析（Bug 3 fix: force: true 强制分析包括 AI 走法的所有步骤）
        for i in 0..<uciMoves.count {
            await analysisVM.analyzeStep(i, force: true)
            analyzedSteps = i + 1
        }

        // 生成复盘统计
        reviewCard = await coach.generateReviewCard(analyses: analysisVM.analyses)
        isAnalyzing = false

        // 显示第一步讲解
        await showExplanation(for: 0)
    }

    private func showExplanation(for index: Int) async {
        guard index < analysisVM.analyses.count else { return }
        guard let analysis = analysisVM.analyses[index] else { return }

        let fenBefore = analysisVM.fenList.isEmpty
            ? (record.initialFEN ?? FENParser.standardInitial)
            : (index < analysisVM.fenList.count ? analysisVM.fenList[index] : (record.initialFEN ?? FENParser.standardInitial))

        let explanation = await coach.explain(
            analysis: analysis,
            fenBefore: fenBefore,
            playerMove: analysis.playerMove,
            bestMove: analysis.bestMove
        )

        currentExplanation = explanation
        replayVM.jumpTo(index: index + 1)
    }

    private func nextStep() {
        let next = replayVM.currentIndex
        guard next < record.moves.count else {
            currentExplanation = nil
            return
        }
        Task { await showExplanation(for: next) }
    }
}
