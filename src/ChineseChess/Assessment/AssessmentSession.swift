import Foundation

// MARK: - v6.0 Phase 4: 棋力评估流程状态机

/// 评估状态
enum AssessmentState: Equatable {
    case idle
    case selectingMode
    case gamePreparation
    case playingGame
    case selectingHistory
    case analyzing(progress: AssessmentProgress)
    case completed(StrengthReport)
    case failed(String)

    static func == (lhs: AssessmentState, rhs: AssessmentState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.selectingMode, .selectingMode),
             (.gamePreparation, .gamePreparation),
             (.playingGame, .playingGame),
             (.selectingHistory, .selectingHistory):
            return true
        case (.analyzing(let l), .analyzing(let r)):
            return l.currentMove == r.currentMove && l.totalMoves == r.totalMoves
        case (.completed, .completed), (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

/// 分析进度
struct AssessmentProgress: Equatable {
    let currentGame: Int
    let totalGames: Int
    let currentMove: Int
    let totalMoves: Int

    var description: String {
        "分析第 \(currentGame)/\(totalGames) 局，第 \(currentMove)/\(totalMoves) 步"
    }
}

/// 评估方式
enum AssessmentMode {
    case newGame           // 方式 A：新对弈评估
    case historyAnalysis   // 方式 B：历史对局分析
}

/// 评估编排器
@MainActor
@Observable
final class AssessmentSession {
    var state: AssessmentState = .idle
    var assessedMoves: [AssessedMove] = []
    var assessedGameIds: [UUID] = []

    private let analyzer = PositionAnalyzer.shared

    // MARK: - 分析单局

    /// 分析单局，返回逐手评估结果
    func analyzeGame(_ record: GameRecord) async {
        let moves = record.moves
        guard !moves.isEmpty else { return }

        // 确定 UCI 走法序列
        let uciMoves = moves.map { $0.uciNotation }
        let initialFEN = record.initialFEN ?? FENParser.standardInitial

        // 确定玩家方
        let playerColor: Side = record.redPlayer.isAI ? .black : .red

        // 逐步分析
        var currentBoard = Board(fen: initialFEN)
        var moveHistory: [String] = []

        for (index, move) in moves.enumerated() {
            // 只分析玩家走法
            let isPlayerMove = (index % 2 == 0 && playerColor == .red) ||
                               (index % 2 == 1 && playerColor == .black)
            guard isPlayerMove else {
                // 更新棋盘状态用于下一步
                let uci = move.uciNotation
                moveHistory.append(uci)
                if let parsed = UCIMoveConverter.move(from: uci, on: currentBoard) {
                    currentBoard.execute(parsed)
                }
                continue
            }

            let fenBefore = FENParser.generate(board: currentBoard)
            let uci = move.uciNotation

            // 引擎分析（使用轻量模式，depth=12, timeMs=300）
            // v6.3.1 同修（双写历史根因，见 AnalysisViewModel.analyzeAll 注）：
            // fenBefore 由 currentBoard 逐步 execute 精确生成，再传 moveHistory 会双应用 → C 拒收静默 nil
            let analysis = await analyzer.analyzeMoveLite(
                fenBefore: fenBefore,
                playerMove: uci,
                moveHistory: [],
                depth: 12,
                timeMs: 300,
                multiPVCount: 3
            )

            // 阶段判断
            let phase = PhaseDetector.detect(moveNumber: index / 2, board: currentBoard)

            // 开局库匹配
            let zobrist = ZobristHash.hash(board: currentBoard)
            let isBookMove: Bool
            if phase == .opening {
                isBookMove = OpeningBook.shared.lookup(zobristHash: zobrist) != nil
            } else {
                isBookMove = false
            }

            // 将杀机会检测（简化：基于 evalDelta 判断）
            let hasMate = analysis?.bestEval != nil && abs(analysis!.bestEval) > 5000
            let missedMate = hasMate && analysis?.playerMove != analysis?.bestMove

            if let analysis = analysis {
                assessedMoves.append(AssessedMove(
                    index: index,
                    fenBefore: fenBefore,
                    playerMove: uci,
                    analysis: analysis,
                    phase: phase,
                    isBookMove: isBookMove,
                    hasCheckmateOpportunity: hasMate,
                    missedCheckmate: missedMate
                ))
            }

            // 更新进度
            state = .analyzing(progress: AssessmentProgress(
                currentGame: assessedGameIds.count + 1,
                totalGames: max(1, assessedGameIds.count + 1),
                currentMove: index + 1,
                totalMoves: moves.count
            ))

            // 更新棋盘
            moveHistory.append(uci)
            if let parsed = UCIMoveConverter.move(from: uci, on: currentBoard) {
                currentBoard.execute(parsed)
            }
        }

        assessedGameIds.append(record.id)
    }

    // MARK: - 批量分析

    /// 分析多局历史对局
    func analyzeHistory(records: [GameRecord]) async {
        guard !records.isEmpty else {
            state = .failed("没有可选的对局")
            return
        }

        state = .analyzing(progress: AssessmentProgress(
            currentGame: 0, totalGames: records.count,
            currentMove: 0, totalMoves: 0
        ))

        for (i, record) in records.enumerated() {
            await analyzeGame(record)
            state = .analyzing(progress: AssessmentProgress(
                currentGame: i + 1, totalGames: records.count,
                currentMove: 0, totalMoves: record.moves.count
            ))
        }
    }

    // MARK: - 生成报告

    /// 从已分析的走法生成评估报告
    func generateReport() -> StrengthReport {
        let deltas = assessedMoves.map { $0.analysis.evalDelta }
        let elo = EloEstimator.estimate(deltas: deltas)
        let recommended = EloEstimator.recommendedLevel(from: elo)
        let dims = SixDimensionScorer.evaluateAll(moves: assessedMoves)

        // 走法统计
        let qualityDist = assessedMoves.reduce(into: [MoveQuality: Int]()) { dict, m in
            dict[m.analysis.quality, default: 0] += 1
        }
        let avgDelta = deltas.isEmpty ? 0.0 :
            Double(deltas.reduce(0, +)) / Double(deltas.count)

        let moveStats = MoveStatistics(
            totalMoves: assessedMoves.count,
            qualityDistribution: qualityDist,
            avgDelta: avgDelta
        )

        let strengths = SixDimensionScorer.generateStrengths(dims)
        let weaknesses = SixDimensionScorer.generateWeaknesses(dims)
        let suggestions = SixDimensionScorer.generateSuggestions(dims, elo: elo)

        let report = StrengthReport(
            sourceGames: assessedGameIds,
            eloEstimate: elo,
            recommendedLevel: recommended,
            dimensions: dims,
            moveStats: moveStats,
            strengths: strengths,
            weaknesses: weaknesses,
            trainingSuggestions: suggestions
        )

        state = .completed(report)
        return report
    }

    // MARK: - 重置

    func reset() {
        state = .idle
        assessedMoves = []
        assessedGameIds = []
    }
}
