import SwiftUI

// MARK: - Phase B3 Step 3: 教练对弈视图

/// 教练对弈视图
///
/// 基于 GameView 增加教练专属 UI 元素：
/// - 走法评估即时反馈（双阶段：书谱即时 + 引擎补充）
/// - 准确率进度条
/// - 退出确认
struct CoachGameView: View {
    let subcategory: OpeningSubcategory
    let playerSide: Side
    let difficulty: AIDifficulty

    @State private var viewModel = GameViewModel()
    @State private var coachSession: OpeningCoachSession
    @State private var coachStrategy: OpeningCoachStrategy
    @State private var evaluator: OpeningMoveEvaluator?

    /// 当前走法评估（双阶段：先书谱，后引擎补充）
    @State private var currentFeedback: MoveFeedback?
    /// 是否正在等待引擎评估
    @State private var isEvaluating: Bool = false
    /// 是否显示退出确认
    @State private var showExitConfirm: Bool = false
    /// 是否显示结果卡片
    @State private var showResult: Bool = false
    /// 棋子光环效果
    @State private var glowQuality: OpeningMoveQuality?
    @State private var glowTask: Task<Void, Never>?
    /// 上次处理的用户走法数（用于检测新走法）
    @State private var lastProcessedMoveCount: Int = 0
    /// 是否正在处理 AI 走法
    @State private var isProcessingAI: Bool = false
    /// 开局是否已结束
    @State private var isCoachFinished: Bool = false

    var onBack: (() -> Void)?

    private let practiceStore = OpeningPracticeStore.shared
    private let l10n = L10n.shared

    init(subcategory: OpeningSubcategory, playerSide: Side, difficulty: AIDifficulty,
         onBack: (() -> Void)? = nil) {
        self.subcategory = subcategory
        self.playerSide = playerSide
        self.difficulty = difficulty
        self.onBack = onBack

        let session = OpeningCoachSession(
            openingId: subcategory.id,
            playerSide: playerSide
        )
        _coachSession = State(initialValue: session)
        _coachStrategy = State(initialValue: OpeningCoachStrategy(
            targetSubcategory: subcategory,
            playerSide: playerSide
        ))
        _evaluator = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            coachNavigationBar

            // 棋盘区域
            BoardView(viewModel: viewModel)
                .overlay(glowOverlay)

            // 走法评估区域
            feedbackPanel

            // 准确率进度条
            accuracyBar
        }
        .background(Color.controlBackground)
        .onAppear {
            setupGame()
        }
        .onChange(of: viewModel.gameMoves.count) { oldCount, newCount in
            handleMoveChange(oldCount: oldCount, newCount: newCount)
        }
        .alert(l10n.t("coach.exit.confirm"), isPresented: $showExitConfirm) {
            Button(l10n.t("common.cancel"), role: .cancel) {}
            Button(l10n.t("common.confirm"), role: .destructive) {
                coachSession.status = .abandoned
                onBack?()
            }
        } message: {
            Text(l10n.t("coach.exit.confirm.detail"))
        }
        .sheet(isPresented: $showResult) {
            CoachResultView(
                session: coachSession,
                subcategory: subcategory,
                onRepractice: {
                    showResult = false
                    // 重置并重新开始
                    resetAndRestart()
                },
                onContinueGame: {
                    showResult = false
                    // 关闭教练模式，继续正常对弈
                    isCoachFinished = true
                },
                onBack: {
                    showResult = false
                    onBack?()
                }
            )
            .frame(minWidth: 360, minHeight: 400)
        }
    }

    // MARK: - 导航栏

    private var coachNavigationBar: some View {
        HStack {
            Button {
                showExitConfirm = true
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(subcategory.name)
                .font(.headline)

            Spacer()

            Text(l10n.t("coach.game.stepFormat", coachSession.moves.count + 1))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.controlBackground)
    }

    // MARK: - 棋子光环效果

    @ViewBuilder
    private var glowOverlay: some View {
        if let quality = glowQuality {
            let color = quality.color
            Rectangle()
                .fill(color.opacity(0.15))
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: - 走法评估面板

    @ViewBuilder
    private var feedbackPanel: some View {
        if let feedback = currentFeedback {
            moveFeedbackCard(feedback)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if isEvaluating {
            evaluatingIndicator
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func moveFeedbackCard(_ feedback: MoveFeedback) -> some View {
        HStack(spacing: 8) {
            Image(systemName: feedback.icon)
                .foregroundColor(feedback.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(feedback.color)

                if let detail = feedback.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(feedback.color.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var evaluatingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(l10n.t("coach.game.evaluating"))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.controlBackground.opacity(0.8))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - 准确率进度条

    private var accuracyBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text(l10n.t("coach.game.accuracy"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(coachSession.accuracy * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)

            // 多色进度条
            accuracyProgressView
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var accuracyProgressView: some View {
        let total = coachSession.moves.count
        if total > 0 {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(OpeningMoveQuality.allCases, id: \.self) { quality in
                        let count = coachSession.moves.filter { $0.quality == quality }.count
                        if count > 0 {
                            let ratio = CGFloat(count) / CGFloat(total)
                            Rectangle()
                                .fill(quality.color)
                                .frame(width: max(2, geo.size.width * ratio - 1))
                        }
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
        } else {
            Capsule()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 8)
        }
    }

    // MARK: - 游戏设置

    private func setupGame() {
        viewModel.newGame()
        viewModel.setHumanSide(playerSide)
        viewModel.setDifficulty(difficulty)

        // 设置教练模式配置，阻止 GameViewModel 自动触发 AI
        viewModel.coachConfig = CoachConfig(
            targetSubcategory: subcategory,
            aiDifficulty: difficulty,
            playerSide: playerSide
        )

        // 初始化评估器
        if let engine = EngineRouter.shared.activeEngine() as? EmbeddedPikafishEngine {
            evaluator = OpeningMoveEvaluator(engine: engine)
        }

        lastProcessedMoveCount = 0

        // 用户执黑时，AI（红方）先行
        if playerSide == .black {
            // 延迟触发，等 viewModel 初始化完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                triggerCoachAIMove()
            }
        }
    }

    private func resetAndRestart() {
        coachSession = OpeningCoachSession(
            openingId: subcategory.id,
            playerSide: playerSide
        )
        coachStrategy = OpeningCoachStrategy(
            targetSubcategory: subcategory,
            playerSide: playerSide
        )
        isCoachFinished = false
        isProcessingAI = false
        currentFeedback = nil
        isEvaluating = false
        glowQuality = nil
        lastProcessedMoveCount = 0

        viewModel.newGame()
        viewModel.setHumanSide(playerSide)
        viewModel.setDifficulty(difficulty)
        viewModel.coachConfig = CoachConfig(
            targetSubcategory: subcategory,
            aiDifficulty: difficulty,
            playerSide: playerSide
        )

        if playerSide == .black {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                triggerCoachAIMove()
            }
        }
    }

    // MARK: - 走法变更处理

    /// 监听 GameViewModel 的 gameMoves 变化
    private func handleMoveChange(oldCount: Int, newCount: Int) {
        guard !isCoachFinished else { return }
        guard newCount > oldCount else { return }
        guard !isProcessingAI else { return }

        // 判断最新走法是用户还是 AI 的
        let latestMove = viewModel.gameMoves.last
        guard let latest = latestMove else { return }

        if latest.piece.side == playerSide {
            // 用户走法 → 评估
            evaluateUserMove(latest)
        }
        // AI 走法已由 triggerCoachAIMove 处理，不需要额外操作
    }

    // MARK: - 用户走棋评估

    private func evaluateUserMove(_ gameMove: GameMove) {
        let iccsMove = ICCSParser.iccsString(from: gameMove.from, to: gameMove.to)
        // P0-1 修正：FEN 是用户走棋后的当前局面（棋盘已更新）
        // 引擎评估用用户走棋前的 FEN，moveHistory 传 []
        // 因为 fen 已是完整局面，不需要回放 moveHistory
        let fen = FENParser.generate(board: viewModel.board)

        // 双阶段评估
        // 阶段 1：书谱匹配（同步，零延迟）
        let bookMoves = getBookMoves(for: fen)
        if let evaluator, let bookResult = evaluator.evaluateBook(userMove: iccsMove, bookMoves: bookMoves) {
            coachSession.appendMove(bookResult)
            currentFeedback = MoveFeedback(
                quality: bookResult.quality,
                title: bookResult.quality.label,
                detail: bookResult.explanation,
                icon: "checkmark.circle.fill",
                color: bookResult.quality.color
            )
            showGlow(bookResult.quality)

            // 书谱命中，不需要引擎评估
            afterUserMove()
            return
        }

        // 阶段 2：引擎评估（async）
        isEvaluating = true
        currentFeedback = nil

        Task { @MainActor in
            guard let evaluator else { return }
            // P0-1 修正：重建用户走棋前的局面
            // fenBeforeMove 已是完整局面，moveHistory 传 []
            let boardBeforeMove = Board()
            for prevMove in viewModel.gameMoves.dropLast() {
                guard let m = ICCSParser.parse(
                    ICCSParser.iccsString(from: prevMove.from, to: prevMove.to),
                    on: boardBeforeMove
                ) else { break }
                boardBeforeMove.execute(m)
            }
            let fenBeforeMove = FENParser.generate(board: boardBeforeMove)

            let result = await evaluator.evaluateEngine(
                userMove: iccsMove,
                fen: fenBeforeMove,
                moveHistory: []  // P0-1 修正：fen 已是完整局面，不需要回放
            )
            coachSession.appendMove(result)
            isEvaluating = false
            currentFeedback = MoveFeedback(
                quality: result.quality,
                title: result.quality.label,
                detail: result.explanation,
                icon: feedbackIcon(result.quality),
                color: result.quality.color
            )
            showGlow(result.quality)

            // 普通/好棋：3秒后自动消失
            if result.quality == .normal || result.quality == .good {
                try? await Task.sleep(for: .seconds(3))
                if currentFeedback?.quality == result.quality {
                    withAnimation { currentFeedback = nil }
                }
            }

            afterUserMove()
        }
    }

    private func afterUserMove() {
        // AI 走棋
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            triggerCoachAIMove()
        }
    }

    // MARK: - 教练 AI 走法

    private func triggerCoachAIMove() {
        guard !isCoachFinished else { return }

        isProcessingAI = true
        let fen = FENParser.generate(board: viewModel.board)

        if let aiMove = coachStrategy.nextAIMove(currentFEN: fen) {
            // P1-2 修正：通过 GameViewModel 正常走子流程执行 AI 走法
            // coachConfig != nil 已阻止 movePiece 触发 AI
            if let move = ICCSParser.parse(aiMove, on: viewModel.board) {
                viewModel.selectPiece(at: move.from)
                viewModel.movePiece(from: move.from, to: move.to)
                isProcessingAI = false
            } else {
                // 走法解析失败
                isProcessingAI = false
                finishCoachSession(reason: .naturalEnd)
            }
        } else {
            // 开局结束
            isProcessingAI = false
            finishCoachSession(reason: .naturalEnd)
        }
    }

    // MARK: - 开局结束

    private func finishCoachSession(reason: OpeningEndReason) {
        switch reason {
        case .naturalEnd:
            coachSession.status = .completed
        case .maxStepsReached:
            coachSession.status = .completed
        case .userAbandoned:
            coachSession.status = .abandoned
        }

        // 保存练习记录
        practiceStore.update(with: coachSession)

        // 显示结果
        showResult = true
    }

    // MARK: - 辅助方法

    private func getBookMoves(for fen: String) -> [String] {
        guard let board = FENParser.parse(fen: fen) else { return [] }
        let zobrist = ZobristHash.hash(board: board)
        guard let candidates = OpeningBook.shared.lookupAll(zobristHash: zobrist) else { return [] }
        return candidates.map { $0.move }
    }

    private func showGlow(_ quality: OpeningMoveQuality) {
        glowTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            glowQuality = quality
        }
        glowTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeOut(duration: 0.3)) {
                glowQuality = nil
            }
        }
    }

    private func feedbackIcon(_ quality: OpeningMoveQuality) -> String {
        switch quality {
        case .book:      return "checkmark.circle.fill"
        case .brilliant: return "star.fill"
        case .good:      return "hand.thumbsup.fill"
        case .normal:    return "circle"
        case .doubtful:  return "exclamationmark.triangle.fill"
        case .blunder:   return "xmark.circle.fill"
        case .losing:    return "xmark.octagon.fill"
        }
    }
}

// MARK: - 走法反馈模型

private struct MoveFeedback {
    let quality: OpeningMoveQuality
    let title: String
    let detail: String?
    let icon: String
    let color: Color
}
