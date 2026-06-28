import SwiftUI

// MARK: - v3.6.0 Phase 2: 复盘分析视图

struct AnalysisView: View {
    @State private var analysisVM = AnalysisViewModel()
    @State private var replayVM: ReplayViewModel
    @Environment(\.dismiss) private var dismiss

    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile

    // 段位门禁
    private var hasBasicAnalysis: Bool {
        profile.rank >= .scholar
    }
    private var hasExpertAnalysis: Bool {
        profile.rank >= .jinshi
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(red: 50/255, green: 30/255, blue: 20/255))
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
                Text("\(analysisVM.analysisProgress.done)/\(analysisVM.analysisProgress.total)")
                    .font(.caption)
                    .foregroundColor(.gray)
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
                Text(l10n.t("analysis.analyzing"))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(height: height)
            } else {
                GeometryReader { geo in
                    let scores = sequence.map { $0.score }
                    let minScore = min(scores.min() ?? 0, -200)
                    let maxScore = max(scores.max() ?? 0, 200)
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
                            let stepWidth = sequence.count > 1
                                ? geo.size.width / CGFloat(sequence.count - 1)
                                : geo.size.width

                            for (i, item) in sequence.enumerated() {
                                let x = CGFloat(i) * stepWidth
                                let normalized = CGFloat(maxScore - item.score) / CGFloat(range)
                                let y = normalized * height

                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color(red: 200/255, green: 160/255, blue: 100/255), lineWidth: 1.5)

                        // 当前位置标记
                        if replayVM.currentIndex > 0 && replayVM.currentIndex <= sequence.count {
                            let idx = replayVM.currentIndex - 1
                            let stepWidth = sequence.count > 1
                                ? geo.size.width / CGFloat(sequence.count - 1)
                                : 0
                            let x = CGFloat(idx) * stepWidth
                            let normalized = CGFloat(maxScore - sequence[idx].score) / CGFloat(range)
                            let y = normalized * height

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
        let fileChars = Array("abcdefghi")
        let moves = replayVM.record.moves.map { move -> String in
            let fromFile = String(fileChars[move.from.col])
            let fromRank = String(10 - move.from.row)
            let toFile = String(fileChars[move.to.col])
            let toRank = String(10 - move.to.row)
            return fromFile + fromRank + toFile + toRank
        }

        let fen = replayVM.record.initialFEN ?? FENParser.standardInitial
        analysisVM.load(moves: moves, initialFEN: fen)
        await analysisVM.analyzeAll()
    }
}
